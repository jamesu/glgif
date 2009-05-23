/*
 
 glgif
 
 GifVideo - implementation of Video which plays animated gifs.
 
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

#import "GifVideo.h"
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@implementation GifVideo

@synthesize tex;
@synthesize playing;

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
    
    return  val;
}

- (id)initWithSource:(VideoSource*)source inContext:(EAGLContext*)ctx
{
    if (self = [super initWithSource:source inContext:ctx]) {
        // hmm....
        disposal = 0;
        trans = false;
        [self resetState];
        
        if (gifinfo == 0x0)
        {
            [self release];
            return nil;
        }
        
        // determine master width, height
        
        width  = goodSize(gifinfo->SWidth);
        height = goodSize(gifinfo->SHeight);
        
        if (width > 1024 || height > 1024)
        {
            [self release];
            return nil;
        }
        
        prevFrame = NULL;
        
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
        
        bpp = 8;//gifinfo->SColorMap->ColorCount > 16 ? 8 : 4;
        bestQuality = true;
    }
    
    return self;
}

- (void)allocTex {
    if (tex)
        VideoTexture_release(tex);
    
    GLint fmt;
    if (bpp == 4)
        fmt = bestQuality ? GL_PALETTE4_RGB8_OES : GL_PALETTE4_R5_G6_B5_OES;
    else
        fmt = bestQuality ? GL_PALETTE8_RGB8_OES : GL_PALETTE8_R5_G6_B5_OES;
    
    
    tex = VideoTexture_init(width, height, fmt);    
    upload_size = [self calcTexSize];
}

- (void)dealloc {
    // free gif...
    if (prevFrame)
        free(prevFrame);
    if (disposeFrame)
        free(disposeFrame);
    
    [super dealloc];
}

void map_palette(char *curPal, int *cpo, ColorMapObject *global, ColorMapObject *lmap, int* offset)
{
    char *cp = curPal;
    GifColorType *color;
    int count = 0;
    
    if (!lmap) {
        count = global->ColorCount;
        color = global->Colors;
        *cpo = 0;
    } else {
        count = lmap->ColorCount;
        color = lmap->Colors;
        
        // diff < 0, start at beginning
        // diff > 0, 
        int diff = (256-(*cpo+count));
        if (diff < 0) {
            diff = 0;
            *cpo = 0;
        } else {
            *cpo += count;
        }
        cp += diff*3;
        *offset = diff;
    }
    
    if (count < 0)
        return;
    
    while (count-- != 0) {
        *cp++ = color->Red;
        *cp++ = color->Green;
        *cp++ = color->Blue;
        color++;
    }
}

- (char*)dataForNextFrame:(float*)ft shouldStop:(bool*)sstop recurseCount:(int)recurse
{
    // Are we reading headers?
    if (!VideoSource_bytesready(src))
        return NULL;
    
    //L0Log(@"frame == %d, sync == %f, fps == %f", frame, sync_time, fps_time);
    
    // First stage: read all of the blocks
    if (!readingFrame)
    {
        GifRecordType recordType;
        bool inError = false;
        
        // Currently reading headers?
        if (!VideoSource_bytesready(src))
            return NULL;
        
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
                        }
                        else
                            trans = false;
                        
                        
                        int frametime = *(ptr+1) | (*(ptr+2) << 8);
                        disposal= ((*ptr)>>2) & 0x7;
                        
                        // 0 == no action  (reset)
                        {
                            // 1 == no dispose (start with previous state)
                            // 2 == restore to background (prev == background)
                        }
                        // 3 == restore to previous (next prev == current)
                        
                        if(frametime<10) frametime=10;
                        if(disposal==4) disposal=3;
                        
                        *ft = (1.0/100.0)*frametime;
                        
                        if (prevFrame == NULL)
                            prevFrame = (char*)malloc(width*height);
                        if (disposeFrame == NULL)
                            disposeFrame = (char*)malloc(width*height);
                        
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
                    *sstop = true;
                    return NULL;
                } else {
                    // Start again!
                    [self resetState];
                    return recurse > 2 ? NULL : [self dataForNextFrame:ft shouldStop:sstop recurseCount:recurse+1];
                }
            }
        }
    }
    
    // Second stage: read frame
    if (readingFrame) {
        // starting at IMAGE_DESC_RECORD_TYPE
        int gwidth  = gifinfo->Image.Width;
        int gheight = gifinfo->Image.Height;
        
        unsigned char *gif_data = ( unsigned char * ) malloc( gwidth * gheight );
        
        if (DGifGetLine(gifinfo, gif_data, gwidth * gheight) != GIF_ERROR) {
            readingFrame = NO;
            char *dat = ( char* ) malloc( upload_size );
            char *sdat = dat+((bpp == 8 ? 256 : 16)*3);
            
            // Restore previous frame (> 0)... or the background (no frame)
            if (disposal != 0 && prevFrame)
                memcpy(sdat, prevFrame, width*height);
            else if (prevFrame == NULL)
                memset(sdat, gifinfo->SBackGroundColor, width*height);
            
            // For disposal #3, we need to keep a copy of this frame
            if (disposal == 3 && disposeFrame)
                memcpy(disposeFrame, sdat, width*height);
            
            unsigned char *buff = (unsigned char*)dat;
            int custom = 0;
            
            // Map image palette colors info color map
            map_palette(curPal, &curPalOffs, gifinfo->SColorMap, gifinfo->Image.ColorMap, &custom);
            memcpy(buff, curPal, sizeof(curPal)); buff += sizeof(curPal);
            
            // src is data
            unsigned char *gifsrc = (unsigned char *)gif_data;
            buff += (width * gifinfo->Image.Top) + gifinfo->Image.Left;
            int right = gwidth;
            int bottom = gheight;
            int next = ((width-gwidth) * (8/bpp));
            
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
                        unsigned char *sptr = gifsrc + (sourceRow * gwidth);
                        for (int j=0; j<gwidth; j++) {
                            unsigned char c = *sptr++;
                            if (trans && c == transindex) {
                                dptr++;
                                continue;
                            }
                            *dptr++ = c + custom;
                        }
                        
                        sourceRow++;
                    }
                }
            }
            else while (bottom-- != 0) // non-interlaced
            {
                right = gwidth;
                while (right-- != 0) {
                    unsigned char c = *gifsrc++;
                    if (trans && c == transindex) {
                        buff++;
                        continue;
                    }
                    *buff++ = c + custom;
                }
                buff += next;
            }
            
            // Keep a copy of this frame for reference
            if (prevFrame)
                memcpy(prevFrame, sdat, width*height);
            
            free(gif_data);
            
            // Now dipose bits in lastFrame
            if (prevFrame && disposal > 1) {
                char *dptr = prevFrame + (width * gifinfo->Image.Top) + gifinfo->Image.Left;
                int right = gwidth;
                int bottom = gheight;
                int next = ((width-gwidth) * (8/bpp));
                
                if (disposal == 2) { // set background color
                    while (bottom-- != 0)
                    {
                        right = gwidth;
                        while (right-- != 0)
                            *dptr++ = gifinfo->SBackGroundColor;
                        dptr += next;
                    }
                } else if (disposal == 3) { // set previous background
                    char *sptr = disposeFrame + (width * gifinfo->Image.Top) + gifinfo->Image.Left;
                    
                    while (bottom-- != 0) {
                        right = gwidth;
                        while (right-- != 0) {
                            *dptr++ = *sptr++;
                        }
                        dptr += next;
                        sptr += next;
                    }
                }
            }
            
            VideoSource_endBytes(src);
            return dat;
        } else {
            free(gif_data);
            
            // Need more bytes, try and wait...
            if (!src->writeable)
            {
                VideoSource_endBytes(src);
                
                // Error, loop frame in case of EOF
                if (!loop) {
                    *sstop = true;
                    return NULL;
                } else {
                    [self resetState];
                    return recurse > 2 ? NULL : [self dataForNextFrame:ft shouldStop:sstop recurseCount:recurse+1];
                }
            }
            else
            {
                // Keep reading the image description (last saved place) until we get more data
                //L0Log(@"NOT ENOUGH DATA TO DECODE...");
                VideoSource_rewind(src);
                readingFrame = false;
                return NULL;
            }
        }
        
    }
    
    return NULL;
}

static int gifReadDataFn(GifFileType *gifinfo, GifByteType *data, int length)
{
    VideoSource *src = (VideoSource*)gifinfo->UserData;
    return VideoSource_read(src, (char*)data, length);
}

- (void)resetState
{
    VideoSource_seek(src, 0);
    if (gifinfo)
        DGifCloseFile(gifinfo);
    if (!beingDestroyed)
        gifinfo = DGifOpen( src, gifReadDataFn);
    if (prevFrame)
        free(prevFrame);
    if (disposeFrame)
        free(disposeFrame);
    
    readingFrame = false;
    curPalOffs = 0;
    if (!beingDestroyed)
        memset(curPal, 0, sizeof(curPal));
    prevFrame = disposeFrame = NULL;
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
