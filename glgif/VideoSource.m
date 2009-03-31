/*
 
 glgif
 
 VideoSource - data source for progressive video playback.
 
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

#import "VideoSource.h"

VideoSource* VideoSource_init(void *in_ptr, VideoSourceType type)
{
    VideoSource *build = malloc(sizeof(VideoSource));
    
    if (type == VIDEOSOURCE_NSDATA)
        [(NSData*)in_ptr retain];
    
    build->ptr = in_ptr;
    build->type = type;
    build->pos = 0;
    build->last_pos = 0;
    build->dirty = true;
    build->writeable = false;
    build->retain = 1;
    build->didEOF = false;
    
    build->trackBytes = false;
    build->expectedBytes = 0;
    
    return build;
}

void VideoSource_release(VideoSource *src)
{
    if (--src->retain < 1) {
        // straight forward release
        if (src->type == VIDEOSOURCE_NSDATA)
            [(NSData*)src->ptr release];
        else if (src->type == VIDEOSOURCE_FILE)
            fclose(src->ptr);
        free(src);
    }
}

void VideoSource_seek(VideoSource *src, int pos)
{
    if (src->type == VIDEOSOURCE_NSDATA) {
        src->pos = pos;
    } else {
        fseek(src->ptr, pos, SEEK_SET);
        src->pos = ftell(src->ptr);
        src->dirty = false;
        src->didEOF = false;
    }
}

int VideoSource_read(VideoSource *src, char *destBytes, int bytes)
{
    if (src->type == VIDEOSOURCE_NSDATA) {
        NSData *data = (NSData*)src->ptr;
        
        if (src->trackBytes)
            src->expectedBytes += bytes;
        
        int avail_pos = [data length] - src->pos;
        if (avail_pos < 0)
            return 0;
        avail_pos = avail_pos > bytes ? bytes : avail_pos;
        [data getBytes:destBytes range:NSMakeRange(src->pos, avail_pos)];
        src->pos += avail_pos;
        return avail_pos;
    } else {
        if (src->dirty) {
            fseek(src->ptr, src->pos, SEEK_SET);
            src->dirty = false;
        }
        
        if (src->trackBytes)
            src->expectedBytes += bytes;
        
        int read = fread(destBytes, 1, bytes, src->ptr);
        
        if (read < bytes)
            src->didEOF = true;
        src->pos += read;
        return read;
    }
}

int VideoSource_appendData(VideoSource *src, NSData *data)
{
    NSInteger bytes = [data length];
    if (src->type == VIDEOSOURCE_NSDATA) {
        NSMutableData *cur_data = (NSMutableData*)src->ptr;
        
        [cur_data appendData:data];
        if (src->expectedBytes > 0)
            src->expectedBytes -= bytes;
        
        return bytes;
    } else {
        src->dirty = true;
        fseek(src->ptr, src->pos, SEEK_END);
        if (src->expectedBytes > 0)
            src->expectedBytes -= bytes;
        
        char *buffer = (char*)malloc(bytes);
        [data getBytes:buffer];
        int res = fwrite(buffer, 1, bytes, src->ptr);
        free(buffer);
        
        return res;
    }
}

int VideoSource_append(VideoSource *src, char *srcBytes, int bytes)
{
    if (src->type == VIDEOSOURCE_NSDATA) {
        NSMutableData *data = (NSMutableData*)src->ptr;
        
        [data appendBytes:srcBytes length:bytes];
        if (src->expectedBytes > 0)
            src->expectedBytes -= bytes;
        
        return bytes;
    } else {
        src->dirty = true;
        fseek(src->ptr, src->pos, SEEK_END);
        if (src->expectedBytes > 0)
            src->expectedBytes -= bytes;
        return fwrite(srcBytes, 1, bytes, src->ptr);
    }
}

void VideoSource_startBytes(VideoSource *src)
{
    if (!src->trackBytes) {
        src->trackBytes = true;
        src->expectedBytes = 0;
        src->last_pos = src->pos;
    }
}

// explicit stop tracking, reset
void VideoSource_endBytes(VideoSource *src)
{
    src->trackBytes = false;
    src->last_pos = 0;
    src->expectedBytes = 0;
}

void VideoSource_rewind(VideoSource *src)
{
    //L0Log(@"Rewound to %i (from %i)", src->last_pos, src->pos);
    VideoSource_seek(src, src->last_pos);
    src->last_pos = src->pos;
}

int VideoSource_lastread(VideoSource *src)
{
    return src->pos - src->last_pos;
}

bool VideoSource_waitforbytes(VideoSource *src)
{
    if (!src->writeable)
        return false;
    
    //L0Log(@"Waiting for %i bytes", src->expectedBytes);
    
    src->trackBytes = false;
    
    VideoSource_rewind(src);
    return true;
}

bool VideoSource_bytesready(VideoSource *src)
{
    //L0Log(@"  Bytes ready ? !%i || %i <= 0", src->writeable, src->expectedBytes);
    return !src->writeable || src->expectedBytes <= 0;
}


bool VideoSource_eof(VideoSource *src)
{
    if (src->type == VIDEOSOURCE_NSDATA) {
        NSData *data = (NSData*)src->ptr;
        return src->pos >= [data length];
    } else {
        if (src->dirty) {
            fseek(src->ptr, src->pos, SEEK_SET);
            src->dirty = false;
        }
        else
            return src->didEOF;
        return feof(src->ptr);
    }
}
