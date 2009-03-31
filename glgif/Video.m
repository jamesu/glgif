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

#import "Video.h"
#import "VideoTexture.h"
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <OpenGLES/EAGL.h>

@implementation Video

@synthesize tex;
@synthesize playing;
@synthesize src;

- (id)initWithSource:(VideoSource*)source inContext:(EAGLContext*)ctx
{
    if (self = [super init]) {
        src = source;
        src->retain++;
        context = ctx;
        
        beingDestroyed = NO;
        
        if (src) {
            width = 256;
            height = 256;
            bpp = 2;
            
            upload_size = 0;
            fps_time = 1.0/25.0;
            
            frame = NULL;
            ready = false;
            frame = false;
            flags = true;
            v_frame = 0;
            
            last_sync = 0.0;
            sync_time = 0.0;
            
            cacheCount = 0;
            req_pos = 0;
            
            threadDone = true;
            tex = NULL;
            
            cacheLock = [NSLock new];
        } else {
            tex = NULL;
        }
    }
    
    return self;
}

- (int)calcTexSize {
    if (tex == NULL)
        return 0;
    
    return VideoTexture_sizeOfTexture(tex->format, tex->width, tex->height, 0);
}

- (void)allocTex {
    if (tex)
        VideoTexture_release(tex);
    
    tex = VideoTexture_init(width, height, GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG);    
    upload_size = [self calcTexSize];
}

- (void)dealloc {
    beingDestroyed = YES;
    
    // Context needs to be set to clear resources!
    if ([EAGLContext currentContext] != context)
        [EAGLContext setCurrentContext:context];
    
    [self stop];
    
    [cacheLock release];
    
    if (src)
        VideoSource_release(src);
    if (tex)
        VideoTexture_release(tex);
    
    [super dealloc];
}

- (int)getFrame
{
	unsigned char status = 0;
    
	if( frame && tex )
	{
        //L0Log(@"getFrame LOCK");
        [cacheLock lock];
        VideoTexture_lock(tex);
        fps_time = data_delay[0];
        memcpy(tex->data, data[0], upload_size);
        VideoTexture_unlock(tex);
        
        // cache must at least be 1 image
        if (cacheCount > 1) {
            cacheCount--;
        
            free(data[0]);
            int i;
            for (i=1; i<MAX_CACHE; i++) {
                data_delay[i-1] = data_delay[i];
                data[i-1] = data[i];
            }
            data[MAX_CACHE-1] = NULL;
            d_frame++;
        }
        
        [cacheLock unlock];
        //L0Log(@"getFrame UNLOCK");
        
		frame = false;
		
		status = 1;
	}
    
	if( ready )
        ready = false;
	
	return status;
}

- (char*)dataForNextFrame:(float*)ft shouldStop:(bool*)sstop recurseCount:(int)recurse
{
    {
        if (!VideoSource_eof(src)) {
            // next frame start
            v_frame++;
        } else if (VideoSource_eof(src)) {
            if (!loop) {
                [self stop];
                return NULL;
            } else {
                VideoSource_seek(src, 0);
                v_frame = 0;
                d_frame = 0;
            }
        }
        
        {
            char *dat = (char*)malloc(upload_size);
            if (VideoSource_bytesready(src)) {
                VideoSource_startBytes(src);
                if (VideoSource_read(src, dat, upload_size) == upload_size) {
                    VideoSource_endBytes(src);
                    return dat;
                } else if (!VideoSource_waitforbytes(src)) {
                    // No more bytes, stop / loop at next frame
                    free(dat);
                    return recurse > 2 ? NULL : [self dataForNextFrame:ft shouldStop:sstop recurseCount:recurse+1];
                }
            }
            
            free(dat);
            return NULL;
        }
    }
    
    return NULL;
}

- (bool)nextFrame
{
    bool errorFrame = false;
    //L0Log(@"frame == %d, sync == %f, fps == %f", frame, sync_time, fps_time);
    if (!frame && (sync_time >= fps_time))
    {
        bool shouldRet = false;
        
        //L0Log(@"nextFrame LOCK");
        [cacheLock lock];
        if (threadDone) {
            [cacheLock unlock];
            //L0Log(@"nextFrame UNLOCK");
            return false;
        }
        
        bool sstop = false;
        
        for (int i=cacheCount; i < MAX_CACHE; i++) {
            float ft = fps_time;
            //L0Log(@"dataForNextFrame:...");
            char *frame_data = [self dataForNextFrame:&ft shouldStop:&sstop recurseCount:0];
            //L0Log(@"dataForNextFrame:done");
            if (frame_data) {
                if (data[i])
                    free(data[i]);
                data[i] = frame_data;
                data_delay[i] = ft;
                cacheCount++;
            } else if (i > 0) {
                // Image should be blank
                if (data[i])
                    free(data[i]);
                data[i] = NULL;
                
                //sync_time = 0.0f;
                last_sync = 0.0f;
                shouldRet = true;
                break; // no other images in the cache
            }
        }
        [cacheLock unlock];
        //L0Log(@"nextFrame UNLOCK");
        
        if (sstop)
            [self stop];
        
        if (shouldRet)
            return true;
        
        if (data[0])
        {
            sync_time = 0.0f;
            frame = true;
        }
    }
    
	double curr_time = [NSDate timeIntervalSinceReferenceDate];
    
    if (last_sync)
        sync_time += (curr_time - last_sync);
    
    last_sync = curr_time;
    
    return errorFrame;
}

- (void)stop
{
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    v_frame = 0;
    d_frame = 0;
    playing = false;
    
    threadDone = YES;
    
    //L0Log(@"stop LOCK");
    [cacheLock lock];
    [self resetState];
    int i;
    for (i=0; i<MAX_CACHE; i++) {
        if (data[i])
            free(data[i]);
        data[i] = NULL;
    }
    cacheCount = 0;
    [cacheLock unlock];
    //L0Log(@"stop UNLOCK");
    
    //thread = nil;
}

- (void)resetState
{
    VideoSource_seek(src, 0);
}

static void tSleep(uint32_t ms)
{
    struct timeval tv;
	uint32_t microsecs = ms * 1000;
    
	tv.tv_sec  = microsecs / 1000000;
	tv.tv_usec = microsecs % 1000000;
    
	select( 0, NULL, NULL, NULL, &tv );	
}

- (void)advanceThread:(id)object
{
	NSAutoreleasePool	*pool;
    
    while (!threadDone)
    {
		pool = [[NSAutoreleasePool alloc] init];
		tSleep([self nextFrame] ? 10 : 1);
		[pool release];
    }
}

- (void)play:(bool)doesLoop
{
    loop = doesLoop;
    
    if (tex == NULL)
        [self allocTex];
    
    if (threadDone) {
        threadDone = false;
        [NSThread detachNewThreadSelector:@selector(advanceThread:) toTarget:self withObject:nil];
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    playing = true;
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

@end
