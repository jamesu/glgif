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

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@class Video;
#define PLAYER_DEG_TO_RAD				0.017453f

@interface PlayerView : UIControl {
    
@private
    /* The pixel dimensions of the backbuffer */
    GLint backingWidth;
    GLint backingHeight;
    
    EAGLContext *context;
    
    /* OpenGL names for the renderbuffer and framebuffers used to render to this view */
    GLuint viewRenderbuffer, viewFramebuffer;
    
    UIInterfaceOrientation targetOrient;
    
    NSTimer *animationTimer;
    NSTimeInterval animationInterval;
    
    float rot;
    
    float d_rot;
    float d_sx;
    float d_sy;
    float sx; // current scale x
    float sy; // current scale y
    float t_sx; // target scale x
    float t_sy; // target scale y
    float t_rot;
    
    float tex_sx;
    float tex_sy;
    
    bool zoomAspect;
    
    Video *vid;
}

@property NSTimeInterval animationInterval;
@property(nonatomic, assign) UIInterfaceOrientation targetOrient;
@property(nonatomic, retain) Video *vid;
@property(nonatomic, assign) bool zoomAspect;

@property (nonatomic, retain) EAGLContext *context;

- (void)startAnimation:(Video*)video;
- (void)stopAnimation;
- (void)drawView;

- (void)setAspectScale:(bool)force;
- (void)clearAspectScale;


@end
