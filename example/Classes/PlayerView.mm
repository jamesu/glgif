/*
 
 glgif
 
 PlayerView - example view to play the GifVideo.
 
 Copyright (C) 2009 James S Urquhart
 
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

#import "PlayerView.h"

#import "Video.h"
#import "GifVideo.h"
#import "GLGifExampleAppDelegate.h"

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

// A class extension to declare private methods
@interface PlayerView ()

@property (nonatomic, assign) NSTimer *animationTimer;

@end

@implementation PlayerView

@synthesize context;
@synthesize animationTimer;
@synthesize animationInterval;
@synthesize vid;
@dynamic targetOrient;
@dynamic zoomAspect;

// You must implement this method
+ (Class)layerClass {
    return [CAEAGLLayer class];
}


- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // Initialization code
        vid = NULL;
        targetOrient = UIInterfaceOrientationPortrait;
        
        d_rot = 0.0;
        d_sx = 0.0;
        d_sy = 0.0;
        rot = 0.0;
        sx = 1.0;
        sy = 1.0;
        
        zoomAspect = false;
    }
    return self;
}

- (id)initWithCoder:(NSCoder*)coder {
    
    if ((self = [super initWithCoder:coder])) {
        // Get the layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        
        if (!context || ![EAGLContext setCurrentContext:context]) {
            [self release];
            return nil;
        }
        
        sx = 2.0;
        sy = 3.0;
        
        d_rot = 0.0;
        d_sx = 0.0;
        d_sy = 0.0;
        rot = 0.0;
        
        tex_sx = 1.0;
        tex_sy = 1.0;
        
        animationInterval = 1.0 / 60.0;
        vid = NULL;
        
        [self layoutSubviews];
    }
    return self;
}

- (UIInterfaceOrientation)targetOrient
{
    return targetOrient;
}

- (void)setTargetOrient:(UIInterfaceOrientation)target
{
    float scale[2];
    [vid frameClipScale:scale];
    tex_sx = scale[0];
    tex_sy = scale[1];
    
    targetOrient = target;
    [self setAspectScale:NO];
}

- (void)drawView {
    
    static const GLfloat squareVertices[] = {
		-0.5f, -0.5f,
		0.5f,  -0.5f,
		-0.5f,  0.5f,
		0.5f,   0.5f,
	};
    
    GLfloat squareTexcoords[] = {
        0.0, 1.0,
        1.0, 1.0,
        0.0, 0.0,
        1.0, 0.0
    };
    
    // Replace the implementation of this method to do your own custom drawing
    
    [EAGLContext setCurrentContext:context];
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    
    glViewport(0, 0, backingWidth, backingHeight);
        
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrthof(-1.0f, 1.0f, -1.5f, 1.5f, -1.0f, 1.0f);
	glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    
    // Magic target scaling code
    
    if (sx != t_sx)
    {
        if (d_sx > 0.0) {
            if (sx > t_sx)
                sx = t_sx;
            else
                sx += d_sx;
        } else {
            if (sx < t_sx)
                sx = t_sx;
            else
                sx += d_sx;
        }
    }
    
    if (sy != t_sy)
    {
        if (d_sy > 0.0) {
            if (sy > t_sy)
                sy = t_sy;
            else
                sy += d_sy;
        } else {
            if (sy < t_sy)
                sy = t_sy;
            else
                sy += d_sy;
        }
    }
    
    if (rot != t_rot)
    {
        if (d_rot > 0.0) {
            if (rot > t_rot)
                rot = t_rot;
            else
                rot += d_rot;
        } else {
            if (rot < t_rot)
                rot = t_rot;
            else
                rot += d_rot;
        }
    }
    
	glRotatef(rot, 0.0f, 0.0f, 1.0);
    glScalef(sx, sy, 0.0);
    
    // scale down texcoords to eliminate border
    int i;
    for (i=0; i<4; i++) {
        squareTexcoords[i*2] *= tex_sx;
        squareTexcoords[(i*2)+1] *= tex_sy;
    }
    
    glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
	glVertexPointer(2, GL_FLOAT, 0, squareVertices);
	glEnableClientState(GL_VERTEX_ARRAY);
	glTexCoordPointer(2, GL_FLOAT, 0, squareTexcoords);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    
    [vid getFrame];
    
    if ([EAGLContext currentContext] != context)
        [EAGLContext setCurrentContext:context];
    
    if (vid.tex) {
        glEnable(GL_TEXTURE_2D);
        glBindTexture(GL_TEXTURE_2D, vid.tex->tex);
	} else {
        glDisable(GL_TEXTURE_2D);
    }
    
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (BOOL)createFramebuffer {
    
    glGenFramebuffersOES(1, &viewFramebuffer);
    glGenRenderbuffersOES(1, &viewRenderbuffer);
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
    
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    
    if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
        return NO;
    }
    
    return YES;
}

- (void)destroyFramebuffer {
    
    glDeleteFramebuffersOES(1, &viewFramebuffer);
    viewFramebuffer = 0;
    glDeleteRenderbuffersOES(1, &viewRenderbuffer);
    viewRenderbuffer = 0;
}

- (void)layoutSubviews {
    [EAGLContext setCurrentContext:context];
    [self destroyFramebuffer];
    [self createFramebuffer];
    [self drawView];
}

- (void)startAnimation:(Video*)video {
    if (animationTimer)
        [self stopAnimation];
    if (vid)
        [vid release];
    vid = [video retain];
    
    float scale[2];
    [vid frameClipScale:scale];
    
    // set width and height scale
    sx = 2.0;
    sy = 3.0;
    t_rot = rot;
    rot = 0.0;
    t_sx = sx;
    t_sy = sy;
    tex_sx = scale[0];
    tex_sy = scale[1];
    
    [self setAspectScale:YES];
    
    [vid play:YES];
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:animationInterval target:self selector:@selector(drawView) userInfo:nil repeats:YES];
}


- (void)stopAnimation {
    self.animationTimer = nil;
    [vid stop];
    self.vid = nil;
}


- (void)setAnimationTimer:(NSTimer *)newTimer {
    [animationTimer invalidate];
    animationTimer = newTimer;
}


- (void)setAnimationInterval:(NSTimeInterval)interval {
    
    animationInterval = interval;
    if (animationTimer) {
        self.animationTimer = nil;
        self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:animationInterval target:self selector:@selector(drawView) userInfo:nil repeats:YES];
    }
}



- (void)drawRect:(CGRect)rect {
    // Drawing code
}


- (void)dealloc {
    [self stopAnimation];
    
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    [context release];  
    [super dealloc];
}

- (bool)zoomAspect
{
    return zoomAspect;
}

- (void)setZoomAspect:(bool)aValue
{
    zoomAspect = aValue;
    [self setAspectScale:NO];
}

- (void)setAspectScale:(bool)force
{
    [self clearAspectScale];
    GLGifExampleAppDelegate *del = [[UIApplication sharedApplication] delegate];
    CGSize aspect = del.orientFrame;
    CGSize fSize = [vid frameSize];
    
    float frame_size[2];
    {
        frame_size[0] = fSize.width;
        frame_size[1] = fSize.height;
    }
    
    float src_ratio = frame_size[1] / frame_size[0]; // height / width == widths to height
    float dest_ratio = t_sy / t_sx; // height / width == widths to height
    
    if (src_ratio > dest_ratio) {
        // src is longer than dest, so shrink x and y accordingly
        
        float dest_height = t_sx * src_ratio;
        if (dest_height > t_sy && !zoomAspect) {
            // shrink t_sx by diff
            t_sx -= (dest_height - t_sy) / src_ratio;
        }
        
        t_sy = t_sx * src_ratio;
    } else {
        // src is shorter than dest, so grow x and y accordingly
        
        float dest_width = t_sy / src_ratio;
        if (dest_width > t_sx && !zoomAspect) {
            // shrink t_sy by diff
            t_sy -= (dest_width - t_sx) * src_ratio;
        }
        
        t_sx = t_sy / src_ratio;
    }
    
    if (force) {
        sx = t_sx;
        sy = t_sy;
        rot = t_rot;
        d_rot = 0.0;
        d_sx = 0.0;
        d_sy = 0.0;
    } else {
        d_rot = (t_rot - rot) / 25.0;
        d_sx = (t_sx - sx) / 25.0;
        d_sy = (t_sy - sy) / 25.0;
    }
}

- (void)clearAspectScale
{
    switch (targetOrient)
    {
        case UIInterfaceOrientationPortrait:
            t_rot = 0.0;
            t_sx = 2.0;
            t_sy = 3.0;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            t_rot = -180.0;
            t_sx = 2.0;
            t_sy = 3.0;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            t_rot = 90.0;
            t_sx = 3.0;
            t_sy = 2.0;
            break;
        case UIInterfaceOrientationLandscapeRight:
            t_rot = -90.0;
            t_sx = 3.0;
            t_sy = 2.0;
            break;
    }
    
    d_rot = (t_rot - rot) / 25.0;
    d_sx = (t_sx - sx) / 25.0;
    d_sy = (t_sy - sy) / 25.0;
}


@end
