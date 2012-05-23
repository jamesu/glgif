/*
 
 glgif
 
 PlayerView - example view to play the GifVideo.
 
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


#import "GifVideo.h"
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#import "PlayerView.h"

extern GLint sMaxTextureSize;

@implementation GifVideo

int goodSize(int val)
{
    if (val < 128)
        val = 128;
    else if (val < 256)
        val = 256;
    else if (val < 512)
        val = 512;
    else if (val < 1024)
        val = 1024;
    else if (val < 2048)
        val = 2048;
   else if (val < 4096)
        val = 4906;
    
    return  val;
}


- (int)videoType
{
   return VIDEO_GIF;
}

- (id)initWithSource:(VideoSource*)source inContext:(EAGLContext*)ctx
{
    if (self = [super initWithSource:source inContext:ctx]) {
        // hmm....
        disposal = 0;
        trans = false;
        thumbDelegate = nil;
        /*
         16 colours of format:
         #define GL_PALETTE4_RGB8_OES              0x8B90 (16*3) + ((width*height)/2)  // best
         #define GL_PALETTE4_RGBA8_OES             0x8B91 (16*4) + ((width*height)/2)
         #define GL_PALETTE4_R5_G6_B5_OES          0x8B92 (16*2) + ((width*height)/2)  // second best
         #define GL_PALETTE4_RGBA4_OES             0x8B93 (16*2) + ((width*height)/2)
         #define GL_PALETTE4_RGB5_A1_OES           0x8B94 (16*2) + ((width*height)/2)
         
         256 colours of format:
         #define GL_PALETTE8_RGB8_OES              0x8B95 (256*3) + (width*height) // best
         #define GL_PALETTE8_RGBA8_OES             0x8B96 (256*4) + (width*height)
         #define GL_PALETTE8_R5_G6_B5_OES          0x8B97 (256*2) + (width*height) // second best
         #define GL_PALETTE8_RGBA4_OES             0x8B98 (256*2) + (width*height)
         #define GL_PALETTE8_RGB5_A1_OES           0x8B99 (256*2) + (width*height)
         */
        
        bpp = 8;
        bestQuality = true;
       
        framebuffer = 0;
        texture = 0;
       
        painter = NULL;
        
        [self resetState:YES];
        
        if (upload_size == 0 || gifinfo == 0x0)
        {
            [self release];
            return nil;
        }
    }
    
    return self;
}

- (void)dealloc {
    // free gif...
    if (gifinfo)
        DGifCloseFile(gifinfo);
    
    [super dealloc];
}

void map_palette(unsigned char *curPal, int bestFormat, int transIdx, ColorMapObject *global, ColorMapObject *lmap)
{
    unsigned char *cp = curPal;
    GifColorType *color;
    int count = 0;
    
    if (!lmap) {
        count = global->ColorCount;
        color = global->Colors;
    } else {
        count = lmap->ColorCount;
        color = lmap->Colors;
        cp = curPal;
    }
    
    if (count < 0)
        return;
    
    if (bestFormat) {
       int idx = 0;
       while (count-- != 0) {
           *cp++ = color->Red;
           *cp++ = color->Green;
           *cp++ = color->Blue;
           if (idx == transIdx)
              *cp++ = 0;
           else
              *cp++ = 255;
          color++;
          idx++;
       }
    } else {
       // TODO
    }
}

void setPointDrawRect(GLfloat *texCoords, GIFRect src_rect)
{
   float left = src_rect.x;
   float top = src_rect.y;
   float right = left + src_rect.width;
   float bottom = top + src_rect.height;
   
   texCoords[0] = left;
   texCoords[1] = bottom;
   texCoords[2] = right;
   texCoords[3] = bottom;
   texCoords[4] = left;
   texCoords[5] = top;
   texCoords[6] = right;
   texCoords[7] = top;
}

void setTexDrawRect(GLfloat *texCoords, int tex_width, int tex_height, GIFRect src_rect)
{
   float left = (float)src_rect.x / tex_width;
   float top = (float)src_rect.y / tex_height;
   float right = (float)(src_rect.x + src_rect.width) / tex_width;
   float bottom = (float)(src_rect.y + src_rect.height) / tex_height;
   
   // Scale by the texture size
   //left = tex_width / left;
   //top = tex_height / top;
   //right = tex_width / right;
   //bottom = tex_height / bottom;
   
   texCoords[0] = left;
   texCoords[1] = bottom;
   texCoords[2] = right;
   texCoords[3] = bottom;
   texCoords[4] = left;
   texCoords[5] = top;
   texCoords[6] = right;
   texCoords[7] = top;
}

// Copies raw bytes
void copyImageBits8(unsigned char *dest, unsigned char *src, int width, int height, int stride)
{//if (stride != 512) return;
   unsigned char *ptr = dest;
   //memcpy(dest, src, stride);
   for (int y=0; y<height; y++) {
      ptr = dest + (y*stride);
      for (int x=0; x<width; x++) {
         *ptr++ = *src++;
      }
   }
}

// Copies 256 color palette + data
void copyImageBitsPal8(unsigned char *dest, unsigned char *src, int width, int height, int stride)
{//if (stride != 512) return;
   unsigned char *ptr;
   memcpy(dest, src, 256*4);
   src += 256*4;
   //memcpy(dest + 256*3, src, stride);
   
   for (int y=0; y<height; y++) {
      ptr = dest + (256*4) + (y*stride);
      for (int x=0; x<width; x++) {
         *ptr++ = *src++;
      }
   }
}

VideoWorkerFrame_t *errFrame= NULL;

int sFrameCount = 0;

void debugPrintRenderBuffer();

- (bool)drawFrame:(VideoWorkerFrame_t*)frame andDisposal:(bool)updateDisposal
{
   //if (frame)
   //   printf("drawFrame: drawing frame %i\n", frame->frameID);
   
   // Don't draw if we haven't recieved frames yet
   if (frame == NULL && last_frame.data == NULL)
      return false;
   
   glEnable(GL_BLEND);
   glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
   
   glEnableClientState(GL_VERTEX_ARRAY);
   glEnableClientState(GL_TEXTURE_COORD_ARRAY);
   glVertexPointer(2, GL_FLOAT, 0, sVidSquareVertices);
   glTexCoordPointer(2, GL_FLOAT, 0, sVidSquareTexcoords);
   
   // Draw disposal frame
   if (updateDisposal) {
      // Now drawing to texture
      TargetRenderInfoSet(disposalRenderInfo);
      glMatrixMode(GL_MODELVIEW);
      glPushMatrix();
      glLoadIdentity();
      
      /*glPushMatrix();
      glTranslatef(last_frame.rect.x, last_frame.rect.y, last_frame.rect.width);
      glPopMatrix();*/
      
      if (frame && frame->reset) {
         glClearColor(1,0,0,0);
         glClear(GL_COLOR_BUFFER_BIT);
      }
      else {
         [self setPaintHead:painter];
         
         // draw new previous frame
         switch (last_frame.disposal_type) {
            case DISPOSE_RESET:
               // Clear all pixels
               glEnable(GL_SCISSOR_TEST);
               glScissor(last_frame.rect.x, last_frame.rect.y, last_frame.rect.width, last_frame.rect.height);
               glClearColor(0,0,0,0);
               glClear(GL_COLOR_BUFFER_BIT);
               glDisable(GL_SCISSOR_TEST);
               break;
            case DISPOSE_CLEARBG:
               // Clear BG color
               glEnable(GL_SCISSOR_TEST);
               glScissor(last_frame.rect.x, last_frame.rect.y, last_frame.rect.width, last_frame.rect.height);
               glClearColor(last_frame.clear_r / 255.0f, last_frame.clear_g  / 255.0f, last_frame.clear_b  / 255.0f, last_frame.clear_a  / 255.0f);
               glClear(GL_COLOR_BUFFER_BIT);
               glDisable(GL_SCISSOR_TEST);
               break;
            case DISPOSE_PREVIOUSBG:
               // Do nothing
               break;
            case DISPOSE_NONE:
            default:
               // Copy current frame to previous
               //setPointDrawRect(sVidSquareVertices, last_frame.rect);
               //setTexDrawRect(sVidSquareTexcoords, painter->width, painter->height, tex_rect);
               
               glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
               /*glEnable(GL_SCISSOR_TEST);
                glScissor(last_frame.rect.x, last_frame.rect.y, last_frame.rect.width, last_frame.rect.height);
                glClearColor(0,1,0,1);
                glClear(GL_COLOR_BUFFER_BIT);
                glDisable(GL_SCISSOR_TEST);*/
               break;
         }
      }
      
      // Reset state
      glMatrixMode(GL_MODELVIEW);
      glPopMatrix();
      glFinish();
   }
   
   // Set player view rendering
   TargetRenderInfoSet(viewRenderInfo);
      
   // Update paint head
   if (frame)
   {
      if (!VideoTexture_lock(painter)) {
         return false;
      }
      memset(painter->data, '\0', upload_size);
      copyImageBitsPal8(painter->data, frame->data, frame->rect.width, frame->rect.height, painter->width);
      VideoTexture_unlock(painter);
   }
   
   // First, render last frame (ALL of it)
   if ((frame && !frame->reset) || !(!frame && last_frame.reset)) {
      GIFRect rect;
      rect.x = 0;
      rect.y = 0;
      rect.width = gifinfo->SWidth;
      rect.height = gifinfo->SHeight;
      [self drawPreviousFrame:rect];
   }
   
   glEnable(GL_BLEND);
   glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
   
   //debugPrintRenderBuffer();
   
   if (frame) last_frame = *frame;
   GIFRect tex_rect = last_frame.rect;
   tex_rect.x = tex_rect.y = 0;
   
   // draw new frame
   [self setPaintHead:painter];
   setPointDrawRect(sVidSquareVertices, last_frame.rect);
   setTexDrawRect(sVidSquareTexcoords, painter->width, painter->height, tex_rect);
   glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
   
   // if (sFrameCount++ >= 2) {
   //    return true;
   // }
   //return false;
   
   return true;
}

- (bool)nextFrame:(VideoWorkerFrame_t*)frame
{
    unsigned char *data = frame->data;
    // Are we reading headers?
    if (!VideoSource_bytesready(src))
        return false;
    
    //L0Log(@"frame == %d, sync == %f, fps == %f", frame, sync_time, fps_time);
    
    // First stage: read all of the blocks
    if (!readingFrame)
    {
        GifRecordType recordType;
        bool inError = false;
        
        // Currently reading headers?
        if (!VideoSource_bytesready(src))
            return false;
        
        VideoSource_startBytes(src); // start pos (if not set)
        
        do {
            int oldpos = src->pos;
            if (DGifGetRecordType(gifinfo, &recordType) == GIF_ERROR) {
                inError = true;
                break;
            }
            
            // Check record types
            if (recordType == IMAGE_DESC_RECORD_TYPE) {
                if (DGifGetImageDesc(gifinfo) == GIF_ERROR) {
                    inError = true;
                    break;
                }
                //L0Log(@"IMAGE DESC @ %i...", oldpos);
                readingFrame = YES;
                src->last_pos = oldpos;
                break;
            }
            else if (recordType == EXTENSION_RECORD_TYPE)
            {
                GifByteType *ext;
                int extCode;
                
                // Skip any extension blocks in file
                if (DGifGetExtension(gifinfo, &extCode, &ext) != GIF_ERROR) {
                    if (extCode == 0xF9) {
                        GifByteType *ptr = ext+1;
                        if (*ptr & 0x1) {
                            transindex = *(ptr+3);
                            trans = true;
                        } else {
                            trans = false;
                            transindex = -1;
                        }
                        int frametime = *(ptr+1) | (*(ptr+2) << 8);
                        disposal= ((*ptr)>>2) & 0x7;
                        if (disposal == 0) disposal = 1; // Fix for broken gifs
                        
                        // 0 == no action  (reset)
                        {
                            // 1 == no dispose (start with previous state)
                            // 2 == restore to background (prev == background)
                        }
                        // 3 == restore to previous (next prev == current)
                        
                        if(frametime<10) frametime=10;
                        if(disposal==4) disposal=3;
                       
                        switch (disposal) {
                           case 0:
                              frame->disposal_type = DISPOSE_RESET;
                              break;
                           case 1:
                              frame->disposal_type = DISPOSE_NONE;
                              break;
                           case 2:
                              frame->disposal_type = DISPOSE_CLEARBG;
                              break;
                           case 3:
                              frame->disposal_type = DISPOSE_PREVIOUSBG;
                              break;
                           default:
                              frame->disposal_type = DISPOSE_NONE;
                              break;
                        }
                        
                        
                        frame->dt = (1.0/100.0)*frametime;
                        frame->blend_type = BLEND_SOURCE;
                        
                        //if(disposal==2&&transindex==gifinfo->SBackGroundColor)
                        //    trans=true;
                    }
                    while (ext != NULL)  // read the rest of the extension blocks
                    {
                        if (DGifGetExtensionNext(gifinfo, &ext) == GIF_ERROR) {
                            inError = true;
                            break;
                        }
                    }
                } else {
                    inError = true;
                    break;
                }
            }
        } while (recordType != TERMINATE_RECORD_TYPE);
        
        if (inError) {
            if (!VideoSource_waitforbytes(src)) // no more data?
            {
                VideoSource_endBytes(src);
                
                // loop or stop completely
                if (!loop) {
                    [self stop];
                    return false;
                } else {
                    // Start again!
                   [self resetState:NO];
                    return false;
                }
            }
            else
            {
                // Waiting for data, flush the damn state
               [self flushState];
            }
        }
    }
    
    // Second stage: read frame
    if (readingFrame) {
        // starting at IMAGE_DESC_RECORD_TYPE
        int gwidth  = gifinfo->Image.Width;
        int gheight = gifinfo->Image.Height;
       
        int palSize = bestQuality ? 4 : 2;
       
        unsigned char curPal[256*4];
       
        // Map image palette colors info color map
        map_palette(curPal, bestQuality, transindex, gifinfo->SColorMap, gifinfo->Image.ColorMap);
       
        frame->rect.x = gifinfo->Image.Left;
        frame->rect.y = gifinfo->Image.Top;
        frame->rect.width = gwidth;
        frame->rect.height = gheight;
       
        unsigned char *cp = curPal + (gifinfo->SBackGroundColor*palSize);
        if (trans && transindex == gifinfo->SBackGroundColor) {
           frame->clear_a = 0;
        } else {
           frame->clear_a = 255;
        }
       
        frame->clear_r = cp[0];
        frame->clear_g = cp[1];
        frame->clear_b = cp[2];
        frame->reset = current_frame == 0;
        frame->frameID = current_frame++;
        //printf("GifInfo: added frame %i\n", frame->frameID);
        
       
        // Now we decode the frame
        
        unsigned char *gif_data = ( unsigned char * ) malloc( gwidth * gheight );
        
        if (DGifGetLine(gifinfo, gif_data, gwidth * gheight) != GIF_ERROR) {
            readingFrame = NO;
            unsigned char *buff = (unsigned char*)data + (256*palSize);
            memcpy(data, curPal, 256*palSize);
            memset(buff, '\0', width*height);
           
            //memset(buff, gifinfo->SBackGroundColor, width*height);
            
            // src is data
            unsigned char *gifsrc = (unsigned char *)gif_data;
            int bottom = gheight;
            int next = 0;//(width-gwidth);
            
            if (gifinfo->Image.Interlace)
            {
                int sourceRow = 0;
                
                for (int i=0; i<4; i++) {
                    int startRow;
                    int interval;
                    switch (i) {
                        case 0:
                            startRow = 0;
                            interval = 8;
                            break;
                        case 1:
                            startRow = 4;
                            interval = 8;
                            break;
                        case 2:
                            startRow = 2;
                            interval = 4;
                            break;
                        case 3:
                            startRow = 1;
                            interval = 2;
                            break;
                    }
                    
                    // Spit out into buff using indexes
                    for (int destRow = startRow; destRow < bottom; destRow += interval)
                    {
                        unsigned char *dptr = buff + (destRow * (gwidth+next));
                        unsigned char *sptr = gifsrc + (sourceRow * gwidth);                        for (int j=0; j<gwidth; j++) {
                             *dptr++ = *sptr++;
                        }
                        
                        sourceRow++;
                    }
                }
            }
            else while (bottom--) // non-interlaced
            {
                int right = gwidth;
                while (right-- != 0) {
                    *buff++ = *gifsrc++;
                }
                buff += next;
            }
            
            VideoSource_endBytes(src);
           
            free(gif_data);
            return true;
        } else {
            free(gif_data);
            
            // Need more bytes, try and wait...
            if (!src->writeable)
            {
                VideoSource_endBytes(src);
                
                // Error, loop frame in case of EOF
                if (!loop) {
                    [self stop];
                    return false;
                } else {
                   [self resetState:NO];
                    return false;
                }
            }
            else
            {
                [self flushState];
                
                // Keep reading the image description (last saved place) until we get more data
                //L0Log(@"NOT ENOUGH DATA TO DECODE...");
                VideoSource_rewind(src);
                readingFrame = false;
                return false;
            }
        }
    }
    
    return false;
}

static int gifReadDataFn(GifFileType *gifinfo, GifByteType *data, int length)
{
    VideoSource *src = (VideoSource*)gifinfo->UserData;
    return VideoSource_read(src, (unsigned char*)data, length);
}

- (void)resetState:(bool)gl
{
    sFrameCount = 0;
    current_frame = 0;
    errFrame = NULL;
    last_frame.data = NULL;
    waitDT = 0;
   
    VideoSource_seek(src, 0);
    if (gifinfo)
        DGifCloseFile(gifinfo);
    gifinfo = DGifOpen( src, gifReadDataFn);
    if (gifinfo)
        gifinfo->generateSavedImages = false;
    
    readingFrame = false;
    
    // determine master width, height
    
    width  = gifinfo ? goodSize(gifinfo->SWidth) : 0;
    height = gifinfo ? goodSize(gifinfo->SHeight) : 0;
    
    if (gifinfo == NULL || width > sMaxTextureSize || height > sMaxTextureSize)
    {
        upload_size = 0;
        if (gifinfo)
            DGifCloseFile(gifinfo);
        gifinfo = nil;
        return;
    }
    
 // texture format
    fmt = bestQuality ? GL_PALETTE8_RGBA8_OES : GL_PALETTE8_RGBA4_OES;
        
    upload_size = VideoTexture_sizeOfTexture(fmt, width, height, 0);
   
   if (gl) {
   
    if (painter)
      VideoTexture_release(painter);
   
    painter = VideoTexture_init(width, height, fmt);
   }
}

- (void)flushState
{
    int oldPos = src->pos;
    VideoSource_seek(src, 0);
    if (gifinfo)
        DGifCloseFile(gifinfo);
    gifinfo = DGifOpen(src, gifReadDataFn);
    VideoSource_seek(src, oldPos);
}

- (void)frameClipScale:(float*)scale
{
    if (gifinfo) {
        scale[0] = (float)gifinfo->SWidth / (float)width;
        scale[1] = (float)gifinfo->SHeight / (float)height;
    } else {
        scale[0] = 1.0;
        scale[1] = 1.0;
    }
}

- (CGSize)frameSize
{
    if (gifinfo)
        return CGSizeMake(gifinfo->SWidth, gifinfo->SHeight);
    else
        return CGSizeMake(width, height);
}

@end
