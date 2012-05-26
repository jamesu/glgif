/*
 
 glgif
 
 Video - base class for video playback.
 
 Copyright (C) 2009-2012 James S Urquhart
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 */

#import "Video.h"
#import "VideoTexture.h"
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <OpenGLES/EAGL.h>

#import "GifVideo.h"

GLfloat sVidSquareVertices[8];
GLfloat sVidSquareTexcoords[8];

void TargetRenderInfoSet(TargetRenderInfo info)
{
   glBindFramebufferOES(GL_FRAMEBUFFER_OES, info.frameBuffer);
   glViewport(info.viewport.x, info.viewport.y, info.viewport.width, info.viewport.height);
   
   glMatrixMode(GL_PROJECTION);
   glLoadMatrixf(info.projection);
}

@implementation Video

@synthesize playing;
@synthesize src;
@synthesize thumbDelegate;
@synthesize thumbObject;
@synthesize fps_time;
@synthesize upload_size;
@synthesize fmt;
@synthesize viewRenderInfo;
@dynamic videoType;

- (int)videoType
{
   return VIDEO_NONE;
}

- (id)initWithSource:(VideoSource*)source inContext:(EAGLContext*)ctx
{
    if (self = [super init]) {
        src = source;
        src->retain++;
        context = ctx;
        
        thumbDelegate = nil;
        thumbObject = nil;
        fmt = GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG;
       
        waitDT = 0;
        
        if (src) {
            width = 256;
            height = 256;
            bpp = 2;
            
            upload_size = VideoTexture_sizeOfTexture(fmt, width, height, 0);
            fps_time = 1.0/25.0;
            
            v_frame = 0;
            
            req_pos = 0;
        } else {
        }
    }
    
    return self;
}

- (void)dealloc {
    // Context needs to be set to clear resources!
    if ([EAGLContext currentContext] != context)
        [EAGLContext setCurrentContext:context];
    
    [self stop];
    
    if (src)
        VideoSource_release(src);
    
    if (thumbDelegate)
        [thumbDelegate release];
    if (thumbObject)
        [thumbObject release];
   
    if (painter)
       VideoTexture_release(painter);
    painter = NULL;
    
    [self clearRenderTexture];
   
    [super dealloc];
}

- (void)drawPreviousFrame:(GIFRect)frameRect
{
   glActiveTexture(GL_TEXTURE0);
   glEnable(GL_TEXTURE_2D);
   glBindTexture(GL_TEXTURE_2D, texture);
   
   setPointDrawRect(sVidSquareVertices, frameRect);
   setTexDrawRect(sVidSquareTexcoords, width, height, frameRect);
   
   glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (bool)drawNextFrame:(float)dt
{
   GLfloat squareVertices[8];
   GLfloat squareTexcoords[8];
   bool frameReady = false;
   
   glEnable(GL_BLEND);
   glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
   
   glEnableClientState(GL_VERTEX_ARRAY);
   glEnableClientState(GL_TEXTURE_COORD_ARRAY);
   glVertexPointer(2, GL_FLOAT, 0, squareVertices);
   glTexCoordPointer(2, GL_FLOAT, 0, squareTexcoords);
   
   if (!work_frame.data)
      return false;
   
   // Grab a new frame
   if (wait_frame == NULL) {
      if ([self nextFrame:&work_frame]);
         wait_frame = &work_frame;
   }
   
   waitDT += dt;
   if (waitDT >= wait_frame->dt) {
       waitDT = 0;
       frameReady = true;
   }
   
   // Draw it
   bool ret = wait_frame && frameReady && [self drawFrame:wait_frame andDisposal:YES];
   
   if (!ret) {
      return [self drawFrame:nil andDisposal:NO];
      
   } else if (wait_frame) {
      wait_frame = NULL;
      
      // Handle thumbnail
      if (thumbDelegate) {
         UIImage *img = [self dumpFrame:nil];
         if (img) {
            [thumbDelegate performSelector:@selector(videoDumpedFrame:withObject:) withObject:img withObject:thumbObject];
            [thumbDelegate release];
            if (thumbObject)
               [thumbObject release];
            thumbDelegate = nil;
            thumbObject = nil;
         }
      }
   }
   
   return true;  
}
       
       
- (bool)nextFrame:(VideoWorkerFrame_t*)frame
{
   return NO;
}

- (void)stop
{
    v_frame = 0;
    playing = false;
}

- (void)resetState
{
    VideoSource_seek(src, 0);
}

- (void)play:(bool)doesLoop
{
    loop = doesLoop;
    playing = true;
    waitDT = 0;
}


- (void)frameClipScale:(float*)scale
{
    scale[0] = 1.0;
    scale[1] = 1.0;
}

- (CGSize)frameSize
{
    return CGSizeMake(width, height);
}

- (CGSize)backingSize
{
    return CGSizeMake(width, height);
}



- (UIImage*)dumpFrame:(VideoWorkerFrame_t*)frame
{
   UIImage *ret = NULL;
   
   GLuint thumbTexture=0;
   GLuint thumbFramebuffer=0;
   
   int thumbWidth = 64;
   int thumbHeight = 64;
   
   glGenTextures(1, &thumbTexture);
   glBindTexture(GL_TEXTURE_2D, thumbTexture);
   
   // Create framebuffer object
   glGenFramebuffersOES(1, &thumbFramebuffer);
   glBindFramebufferOES(GL_FRAMEBUFFER_OES, thumbFramebuffer);
   
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
   
   //char *temp = (char*)malloc(width*height*4);
   glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, thumbWidth, thumbHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
   //free(temp);
   
   glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, thumbTexture, 0);
   
   if (glCheckFramebufferStatus(GL_FRAMEBUFFER_OES) == GL_FRAMEBUFFER_COMPLETE_OES)
   {
      glGetError();
      
      //glBindFramebufferOES(GL_FRAMEBUFFER_OES, thumbFramebuffer);
      glViewport(0, 0, thumbWidth, thumbHeight);
      glClearColor(0,0,0,0);
      glClear(GL_COLOR_BUFFER_BIT);
      
      // Now drawing to texture
      glMatrixMode(GL_PROJECTION);
      glLoadIdentity();
      glOrthof(0, thumbWidth, 0, thumbHeight, -1, 1);
      glMatrixMode(GL_MODELVIEW);
      glPushMatrix();
      glLoadIdentity();
      
      glClearColor(0, 0, 0, 0);
      glClear(GL_COLOR_BUFFER_BIT);
      
      CGSize frameSize = [self frameSize];
      
      float frame_size[2];
      {
         frame_size[0] = frameSize.width;
         frame_size[1] = frameSize.height;
      }
      
      float sx = thumbWidth;
      float sy = thumbHeight;
      
      float src_ratio = frame_size[1] / frame_size[0]; // height / width == widths to height
      //float base_scale = 1.0;
      float dest_ratio = thumbHeight / thumbWidth; // height / width == widths to height
      
      if (src_ratio > dest_ratio) {
         // src is longer than dest, so shrink x and y accordingly
         
         float dest_height = sx * src_ratio;
         if (dest_height > sy) {
            // shrink t_sx by diff
            sx -= (dest_height - sy) / src_ratio;
         }
         
         sy = sx * src_ratio;
      } else {
         // src is shorter than dest, so grow x and y accordingly
         
         float dest_width = sy / src_ratio;
         if (dest_width > sx) {
            // shrink t_sy by diff
            sy -= (dest_width - sx) * src_ratio;
         }
         
         sx = sy / src_ratio;
      }
      
      // See if we have a frame ready
      
      
      glTranslatef((thumbWidth*0.5) - (frameSize.width*0.5), (thumbHeight*0.5) - (frameSize.height*0.5), 0);
      
      glTranslatef((frameSize.width*0.5), (frameSize.height*0.5), 0);
      
      float width_ratio = thumbWidth / frameSize.width;
      float height_ratio = thumbHeight / frameSize.height;
      
      glScalef(width_ratio * (sx / thumbWidth), height_ratio  * (sy / thumbHeight), 1.0f);
      
      glTranslatef(-(frameSize.width*0.5), -(frameSize.height*0.5), 0);

            
      // Draw frame
      
      if ([self drawFrame:frame andDisposal:NO]) {
         // Now we can make the bitmap
         CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
         unsigned char *mem = (unsigned char*)malloc(thumbWidth * thumbHeight * 4);
         CGContextRef ctx = CGBitmapContextCreate(mem,
                                                  thumbWidth,
                                                  thumbHeight,
                                                  8,
                                                  thumbWidth * 4,
                                                  colorspace,
                                                   kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
         CGColorSpaceRelease(colorspace);
         
         if (ctx) {          
            // Copy pixels...
            memset(mem, '\0', thumbWidth*thumbHeight*4);
            glReadPixels(0, 0, thumbWidth, thumbHeight, GL_RGBA, GL_UNSIGNED_BYTE, mem);
            
            CGImageRef img = CGBitmapContextCreateImage(ctx);
            ret = [UIImage imageWithCGImage:img];
            
            CGContextRelease(ctx);
            CGImageRelease(img);
         }
         
         free(mem);
         CGColorSpaceRelease(colorspace);
      }
      
      glMatrixMode(GL_MODELVIEW);
      glPopMatrix();
   }
   
   // Cleanup
   glDeleteFramebuffers(1, &thumbFramebuffer);
   glDeleteTextures(1, &thumbTexture);
   return ret;
}


- (bool)setupRenderTexture
{
   if (framebuffer != 0) {
      [self clearRenderTexture];
   }
   
   glGenTextures(1, &texture);
   glBindTexture(GL_TEXTURE_2D, texture);
   
   // Create framebuffer object
   glGenFramebuffersOES(1, &framebuffer);
   glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebuffer);
   
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
   
   //char *temp = (char*)malloc(width*height*4);
   glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
   //free(temp);
   
   glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
   
   if (glCheckFramebufferStatus(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
   {
      // error
      [self clearRenderTexture];
      return false;
   }
   
   
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
   glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
   
   glGetError();
   
   glViewport(0, 0, width, height);
   glClearColor(0,0,0,0);
   glClear(GL_COLOR_BUFFER_BIT);
   
   glMatrixMode(GL_PROJECTION);
   glLoadIdentity();
   glOrthof(0, width, 0, height, -1, 1);
   disposalRenderInfo.frameBuffer = framebuffer;
   disposalRenderInfo.viewport = GIFRectMake(0, 0, width, height);
   glGetFloatv(GL_PROJECTION_MATRIX, disposalRenderInfo.projection);
   
   
   work_frame.data = malloc(upload_size);
   wait_frame = NULL;
   
   return true;
}

- (void)clearRenderTexture
{
   if (framebuffer == 0)
      return;
   glDeleteFramebuffers(1, &framebuffer);
   glDeleteTextures(1, &texture);
   
   glGetError();
   
   framebuffer = 0;
   texture = 0;
   
   free(work_frame.data);
}

- (void)setPaintHead:(VideoTexture*)aPainter
{
   glActiveTexture(GL_TEXTURE0);
   glEnable(GL_TEXTURE_2D);
   glBindTexture(GL_TEXTURE_2D, aPainter->tex);
   glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE); 
}

- (void)resetState:(bool)gl
{
    
}

- (bool)drawFrame:(VideoWorkerFrame_t*)frame andDisposal:(bool)updateDisposal
{
    return false;
}

+ (Video*)videoByType:(int)type withSource:(VideoSource*)source inContext:(EAGLContext*)context
{
   switch (type) {
      case VIDEO_GIF:
         return [[[GifVideo alloc] initWithSource:source inContext:context] autorelease];
         break;
      default:
         return NULL;
         break;
   }
}


@end
