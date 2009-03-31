/*
 
 glgif
 
 Video - base class for video playback.
 
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

#import <Foundation/Foundation.h>

#import "VideoTexture.h"
#import "VideoSource.h"

#define MAX_CACHE 2

@class EAGLContext;

@interface Video : NSObject {
    VideoTexture *tex;
    VideoSource *src;
    
    EAGLContext *context;
    
    int width;
    int height;
    int bpp;
    
    int req_pos;
    int upload_size;
    
    double fps_time;
    double sync_time;
    double last_sync;
    
    char *data[MAX_CACHE];
    float data_delay[MAX_CACHE];
    int cacheCount;
    
    bool frame;
    bool ready;
    bool flags;
    
    // state
    bool playing;
    bool loop;
    int v_frame; // read frame
    int d_frame; // display frame
    
    
    bool threadDone;
    bool beingDestroyed;
    NSLock *cacheLock;
    //NSThread *thread;
}

@property(nonatomic, assign) VideoTexture *tex;
@property(nonatomic, readonly, assign) bool playing;
@property(nonatomic, assign) VideoSource *src;

// Gets next frame from Video
- (int)getFrame;

// Size of backend texture
- (int)calcTexSize;

// Pretty self-explanatory
- (void)play:(bool)doesLoop;
- (void)stop;

// Uploads next frame from video to texture
- (bool)nextFrame;

// Overrides...

// Init the video
- (id)initWithSource:(VideoSource*)source inContext:(EAGLContext*)ctx;

// Allocate the VideoTexture
- (void)allocTex;

// Data for the next frame (should be in VideoTexture's format)
- (char*)dataForNextFrame:(float*)ft shouldStop:(bool*)sstop recurseCount:(int)recurse;

// Reset to default state
- (void)resetState;

// Scaling factor to remove texture border
- (void)frameClipScale:(float*)scale;

// Size of frame in pixels
- (CGSize)frameSize;

@end
