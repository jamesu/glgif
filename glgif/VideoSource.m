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

#import "VideoSource.h"
//#define MIN_CACHE (1024*64)
#define MIN_CACHE (1024*1024*4)

DynamicCache *DynamicCache_initWithData(NSData *data, const char *filename)
{
    // Basically we make a cache with the MINIMUM of MIN_CACHE bytes. However
    // if we exceed this value we simply make a file (in appendData)
    //int size = [data length];
    
    DynamicCache *ret = DynamicCache_init(MIN_CACHE, filename);
    if (ret) {
        VideoSource dummy;
        dummy.type = VIDEOSOURCE_DYNAMICCACHE;
        dummy.ptr = ret;
        dummy.pos = 0;
        dummy.writeable = true;
        dummy.expectedBytes = 0;
        VideoSource_appendData(&dummy, data);
    }
    return ret;
}

DynamicCache* DynamicCache_init(int cacheSize, const char *filename)
{
    DynamicCache *cache = (DynamicCache*)malloc(sizeof(DynamicCache));
    cache->cacheRead = NULL;
    cache->cacheWrite = NULL;
    cache->dataSize = cacheSize;
    cache->cacheSize = 0;
    cache->cachePos = 0;
    cache->data = malloc(cacheSize);
    cache->retainCount = 1;
    
    if (!cache->data) {
        // Whoops
        free(cache->data);
        return NULL;
    }
    
    cache->filename = strdup(filename);
    return cache;
}

void DynamicCache_retain(DynamicCache *cache)
{
    cache->retainCount++;
}

void DynamicCache_release(DynamicCache *cache)
{
    cache->retainCount--;
    if (cache->retainCount > 0)
        return;
    
    if (cache->filename)
        free(cache->filename);
    if (cache->data)
        free(cache->data);
    if (cache->cacheRead)
        fclose(cache->cacheRead);
    if (cache->cacheWrite)
        fclose(cache->cacheWrite);
    free(cache);
}

bool DynamicCache_dumpToFile(DynamicCache *cache, const char *filename)
{
    bool ret = false;
    FILE *fp = fopen(filename, "w");
    if (cache->cacheWrite)
        fflush(cache->cacheWrite);
    if (fp) {
        if (cache->data) {
            fwrite(cache->data, 1, cache->cacheSize, fp);
            ret = true;
        } else {
            char buffer[2048];
            int bytesLeft = 0;
            
            FILE *readFp = fopen(cache->filename, "r");
            if (readFp) {
                fseek(readFp, 0, SEEK_END);
                bytesLeft = ftell(readFp);
                fseek(readFp, 0, SEEK_SET);
                
                while (bytesLeft != 0) {
                    int bytesRead = bytesLeft > 2048 ? 2048 : bytesLeft;
                    if (fread(buffer, 1, bytesRead, readFp) != bytesRead)
                        break;
                    if (fwrite(buffer, 1, bytesRead, fp) != bytesRead)
                        break;
                    bytesLeft -= bytesRead;
                }
                ret = bytesLeft == 0;
                fclose(readFp);
            } else {
                ret = false;
            }
        }
        fclose(fp);
    }
    return ret;
}

VideoSource* VideoSource_init(void *in_ptr, VideoSourceType type)
{
    VideoSource *build = malloc(sizeof(VideoSource));
    
    build->ptr = in_ptr;
    if (type == VIDEOSOURCE_DYNAMICCACHE)
        DynamicCache_retain((DynamicCache*)in_ptr);
    
    build->type = type;
    build->pos = 0;
    build->last_pos = 0;
    build->dirty = true;
    build->writeable = true;
    build->retain = 1;
    build->didEOF = false;
    
    build->trackBytes = false;
    build->expectedBytes = 0;
    
    return build;
}

void VideoSource_release(VideoSource *src)
{
    if (--src->retain < 1) {
        
        if (src->type == VIDEOSOURCE_DYNAMICCACHE)
            DynamicCache_release((DynamicCache*)src->ptr);
        else if (src->type == VIDEOSOURCE_FILE)
            fclose(src->ptr);
        
        src->ptr = NULL;
        free(src);
    }
}

void VideoSource_finishedBytes(VideoSource *src)
{
    src->writeable = false;
    if (src->type == VIDEOSOURCE_DYNAMICCACHE) {
        DynamicCache *cache = (DynamicCache*)src->ptr;
        
        if (cache->cacheWrite)
            fclose(cache->cacheWrite);
        cache->cacheWrite = NULL;
    }
}

void VideoSource_seek(VideoSource *src, int pos)
{
    if (src->type == VIDEOSOURCE_DYNAMICCACHE) {
        DynamicCache *cache = (DynamicCache*)src->ptr;
        
        if (cache->cacheRead) {
            // Directly seek in file
            //L0Log(@"Seek file to %i from %i", pos, src->pos);
            fseek(cache->cacheRead, pos, SEEK_SET);
            src->pos = ftell(cache->cacheRead);
            //assert(src->pos == pos);
            src->dirty = false;
            src->didEOF = false;
        } else {
            // In memory
            src->pos = pos;
            if (src->pos > cache->cacheSize) {
                //assert(true);
                src->pos = cache->cacheSize;
                src->dirty = false;
                src->didEOF = false;
            }
        }        
    } else {
        fseek(src->ptr, pos, SEEK_SET);
        src->pos = ftell(src->ptr);
        src->dirty = false;
        src->didEOF = false;
    }
}

int VideoSource_seekread(VideoSource *src, int bytes)
{
   int startPos = src->pos;
   if (src->trackBytes)
      src->expectedBytes += bytes;
   VideoSource_seek(src, src->pos + bytes);
   if ((src->pos - startPos) < bytes)
      src->didEOF = !src->writeable;
   return src->pos - startPos;
}

int VideoSource_read(VideoSource *src, unsigned char *destBytes, int bytes)
{
    if (src->type == VIDEOSOURCE_DYNAMICCACHE) {
        DynamicCache *cache = (DynamicCache*)src->ptr;
                
        if (cache->cacheRead) {
            if (src->dirty) {
                fseek(cache->cacheRead, src->pos, SEEK_SET);
                //assert(ret == 0);
                src->dirty = false;
            }
            
            if (src->trackBytes)
                src->expectedBytes += bytes;
            
            int read = fread(destBytes, 1, bytes, cache->cacheRead);
            if (read < bytes)
                src->didEOF = !src->writeable;
            
            src->pos += read;
            return read;
        } else {
            if (src->trackBytes)
                src->expectedBytes += bytes;
            
            int avail_len = cache->cacheSize;
            int avail_pos = avail_len - src->pos;
            if (avail_pos <= 0)
                return 0;
            avail_pos = avail_pos > bytes ? bytes : avail_pos;
            
            memcpy(destBytes, cache->data + src->pos, avail_pos);
            if (avail_pos < bytes)
                src->didEOF = !src->writeable;
            
            src->pos += avail_pos;
            return avail_pos;
        }
    } else {
        if (src->dirty) {
            fseek(src->ptr, src->pos, SEEK_SET);
            src->dirty = false;
        }
        
        if (src->trackBytes)
            src->expectedBytes += bytes;
        
        int read = fread(destBytes, 1, bytes, src->ptr);
        
        if (read < bytes)
            src->didEOF = !src->writeable;
        src->pos += read;
        return read;
    }
}

int VideoSource_appendData(VideoSource *src, NSData *data)
{
    if (!src->writeable)
        return 0;
    
    int bytes = [data length];
    
    if (src->type == VIDEOSOURCE_DYNAMICCACHE) {
        DynamicCache *cache = (DynamicCache*)src->ptr;
        
        // Need to write to the memory cache?
        if (!cache->cacheWrite) {
            //cache->cacheSize += bytes;
            
            if (cache->cacheSize + bytes > cache->dataSize)
            {
                // Time to open a cache file. Bail on error.
                cache->cacheWrite = fopen(cache->filename, "wb+");
                if (!cache->cacheWrite) {
                    src->writeable = false;
                    return 0;
                }
                
                // Try and write the cache. If not, bail
                if (cache->cacheSize > 0) {
                    int wroteBytes = fwrite(cache->data, 1, cache->cacheSize, cache->cacheWrite); 
                    if (wroteBytes != cache->cacheSize) {
                        fclose(cache->cacheWrite);
                        cache->cacheWrite = NULL;
                        src->writeable = false;
                        return 0;
                    }
                }
                
                // Open the cache
                cache->cacheRead = fopen(cache->filename, "r");
                if (!cache->cacheRead) {
                    fclose(cache->cacheWrite);
                    cache->cacheWrite = NULL;
                    src->writeable = false;
                    return 0;
                }
                
                free(cache->data);
                cache->data = NULL;
            }
            else
            {
                [data getBytes:cache->data + cache->cacheSize length:bytes];
                if (src->expectedBytes > 0)
                    src->expectedBytes -= bytes;
                cache->cacheSize += bytes;
                return bytes;
            }
        }
        
        // Need to write to the cache file?
        if (cache->cacheWrite) {
            // Need a temp buffer
            char *buffer = (char*)malloc(bytes);
            if (!buffer) {
                src->writeable = false;
                return 0;
            }
            
            if (src->expectedBytes > 0)
                src->expectedBytes -= bytes;
            
            src->dirty = true;
            
            [data getBytes:buffer length:bytes];
            int res = fwrite(buffer, 1, bytes, cache->cacheWrite);
            //assert(res == bytes);
            free(buffer);
            
            return res;
        }
    } else {
        // Need a temp buffer
        char *buffer = (char*)malloc(bytes);
        if (!buffer) {
            src->writeable = false;
            return 0;
        }
        fflush(src->ptr);
        
        src->dirty = true;
        fseek(src->ptr, 0, SEEK_END);
        if (src->expectedBytes > 0)
            src->expectedBytes -= bytes;
        
        [data getBytes:buffer];
        int read = fwrite(buffer, 1, bytes, src->ptr);
        //assert(read == bytes);
        free(buffer);
        
        return read;
    }
    
    return 0;
}

int VideoSource_append(VideoSource *src, unsigned char *srcBytes, int bytes)
{
    if (!src->writeable)
        return 0;
    
    
    if (src->type == VIDEOSOURCE_DYNAMICCACHE) {
        DynamicCache *cache = (DynamicCache*)src->ptr;
        
        if (!cache->cacheWrite) {
            //cache->cacheSize += bytes;
            
            if (cache->cacheSize + bytes > cache->dataSize)
            {
                // Time to open a cache file. Bail on error.
                cache->cacheWrite = fopen(cache->filename, "wb+");
                if (!cache->cacheWrite) {
                    src->writeable = false;
                    return 0;
                }
                
                // Try and write the cache. If not, bail
                int wroteBytes = fwrite(cache->data, 1, cache->cacheSize, cache->cacheWrite); 
                if (wroteBytes != cache->cacheSize) {
                    fclose(cache->cacheWrite);
                    cache->cacheWrite = NULL;
                    src->writeable = false;
                    return 0;
                }
                
                // Open the cache
                cache->cacheRead = fopen(cache->filename, "r");
                if (!cache->cacheRead) {
                    fclose(cache->cacheWrite);
                    cache->cacheWrite = NULL;
                    src->writeable = false;
                    return 0;
                }
                
                free(cache->data);
                cache->data = NULL;
            }
            else
            {
                memcpy(cache->data + src->pos, srcBytes, bytes);
                if (src->expectedBytes > 0)
                    src->expectedBytes -= bytes;
                cache->cacheSize += bytes;
                return bytes;
            }
        }
        
        // Need to write to the cache file?
        if (cache->cacheWrite) {
            // Need a temp buffer
            char *buffer = (char*)malloc(bytes);
            if (!buffer) {
                src->writeable = false;
                return 0;
            }
            
            if (src->expectedBytes > 0)
                src->expectedBytes -= bytes;
            
            src->dirty = true;
            int res = fwrite(srcBytes, 1, bytes, cache->cacheWrite);
            //assert(res == bytes);
            free(buffer);
            
            return res;
        }
    } else {
        src->dirty = true;
        fflush(src->ptr);
        fseek(src->ptr, 0, SEEK_END);
        if (src->expectedBytes > 0)
            src->expectedBytes -= bytes;
        return fwrite(srcBytes, 1, bytes, src->ptr);
    }
    
    return 0;
}

void VideoSource_startBytes(VideoSource *src)
{
    if (!src->trackBytes) {
        //L0Log(@"Started tracking at pos=%i", src->pos);
        src->trackBytes = true;
        src->expectedBytes = 0;
        src->last_pos = src->pos;
    }
}

// explicit stop tracking, reset
void VideoSource_endBytes(VideoSource *src)
{
    //L0Log(@"Stopped tracking at pos=%i", src->pos);
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
    if (src->type == VIDEOSOURCE_DYNAMICCACHE) {
        DynamicCache *cache = (DynamicCache*)src->ptr;
        
        if (cache->cacheRead) {
            if (src->dirty) {
                if (!src->writeable) {
                    fflush(cache->cacheRead); // ensure data is written
                    fseek(cache->cacheRead, src->pos, SEEK_SET);
                }
                src->dirty = false;
            }
            else
                return src->didEOF;
            return src->writeable ? false : feof(cache->cacheRead);
        } else {
            return src->pos >= cache->cacheSize;
        }
    } else {
        if (src->dirty) {
            fflush(src->ptr); // ensure data is written
            fseek(src->ptr, src->pos, SEEK_SET);
            src->dirty = false;
        }
        else
            return src->didEOF;
        return feof(src->ptr);
    }
}
