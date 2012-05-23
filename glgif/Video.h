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

#import <Foundation/Foundation.h>

#import "VideoTexture.h"
#import "VideoSource.h"

#define MAX_CACHE 2

#define VIDEO_NONE 0 // data
#define VIDEO_GIF  1


#define DISPOSE_RESET 0
#define DISPOSE_CLEARBG 1
#define DISPOSE_PREVIOUSBG 2
#define DISPOSE_NONE 3

#define BLEND_SOURCE 0
#define BLEND_OVER 1

@class Video;

typedef struct GIFRect
{
   int x, y, width, height;
} GIFRect;

static inline GIFRect GIFRectMake(int x, int y, int w, int h) { GIFRect rect; rect.x = x; rect.y = y; rect.width=w; rect.height=h; return rect; }

typedef struct VideoWorkerFrame_s {
   char disposal_type, blend_type;
   unsigned char *data;
   
   float dt;
   bool ready;
   bool reset;
   
   int frameID;
   
   GIFRect rect;
   char clear_r, clear_g, clear_b, clear_a;
} VideoWorkerFrame_t;

typedef struct TargetRenderInfo
{
   GLuint frameBuffer;
   GIFRect viewport;
   GLfloat projection[16];
} TargetRenderInfo;


static inline TargetRenderInfo TargetRenderInfoMake(GLuint frameBuffer, GIFRect viewport, GLfloat* newProjection) { TargetRenderInfo info; info.frameBuffer = frameBuffer; info.viewport = viewport; memcpy(info.projection, newProjection, sizeof(GLfloat)*16); return info; }

void TargetRenderInfoSet(TargetRenderInfo info);

@class EAGLContext;
@class PlayerView;

@interface Video : NSObject {
    VideoSource *src;
    
    EAGLContext *context;
    
    int width;
    int height;
    int bpp;
    
    GLint fmt;
    float waitDT;
    
    int req_pos;
    int upload_size;
    
    double fps_time;
    
    // state
    bool playing;
    bool loop;
    int v_frame; // read frame
    
    id thumbDelegate;
    id thumbObject;
   
    TargetRenderInfo viewRenderInfo;
    TargetRenderInfo disposalRenderInfo;
   
   
    VideoTexture *painter;
    GLuint framebuffer, texture;
    VideoWorkerFrame_t last_frame;
   
    VideoWorkerFrame_t work_frame;
    VideoWorkerFrame_t *wait_frame;
}


@property(nonatomic, assign) TargetRenderInfo viewRenderInfo;
@property(nonatomic, readonly) int upload_size;
@property(nonatomic, readonly) double fps_time;
@property(nonatomic, readonly) GLint fmt;
@property(nonatomic, retain) id thumbDelegate;
@property(nonatomic, retain) id thumbObject;
@property(nonatomic, readonly, assign) bool playing;
@property(nonatomic, assign) VideoSource *src;
@property(nonatomic, readonly) int videoType;

- (void)play:(bool)doesLoop;
- (void)stop;

- (bool)setupRenderTexture;
- (void)clearRenderTexture;
- (void)setPaintHead:(VideoTexture*)painter;

// Overrides
- (id)initWithSource:(VideoSource*)source inContext:(EAGLContext*)ctx;
- (void)resetState:(bool)gl;
- (void)frameClipScale:(float*)scale;
- (CGSize)frameSize;
- (CGSize)backingSize;
- (bool)drawNextFrame:(float)dt toView:(PlayerView*)view withBackingSize:(CGSize)size;

- (bool)drawFrame:(VideoWorkerFrame_t*)frame andDisposal:(bool)updateDisposal;
- (void)drawPreviousFrame:(GIFRect)frameRect;

- (UIImage*)dumpFrame:(VideoWorkerFrame_t*)frame;

+ (Video*)videoByType:(int)type withSource:(VideoSource*)source inContext:(EAGLContext*)context;

@end



extern GLfloat sVidSquareVertices[8];
extern GLfloat sVidSquareTexcoords[8];
