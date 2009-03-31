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

typedef enum
{
    VIDEOSOURCE_NSDATA = 0,  // reads from NSData
    VIDEOSOURCE_FILE = 1     // reads from FP
} VideoSourceType;

typedef struct VideoSource {
    VideoSourceType type;
    void *ptr;
    int pos;
    int last_pos;
    bool dirty;
    int retain;
    bool writeable;
    bool didEOF;
    
    bool trackBytes;
    int expectedBytes;
} VideoSource;

// Initializes a VideoSource. Use in_ptr to provide a source object 
// (VIDEOSOURCE_NSDATA == NSData, VIDEOSOURCE_FILE == fp)
VideoSource* VideoSource_init(void *in_ptr, VideoSourceType type);

// Releases a VideoSource. Will free if retain count is 0
void VideoSource_release(VideoSource *src);

// Seek to pos in VideoSource
void VideoSource_seek(VideoSource *src, int pos);

// Read bytes from VideoSource into destBytes
int VideoSource_read(VideoSource *src, char *destBytes, int bytes);

// Append bytes from srcBytes into VideoSource
int VideoSource_append(VideoSource *src, char *srcBytes, int bytes);

// Append NSData into VideoSource
int VideoSource_appendData(VideoSource *src, NSData *data);

// Rewind to position recorded by startBytes
void VideoSource_rewind(VideoSource *src);

// Bytes read since startBytes
int VideoSource_lastread(VideoSource *src);

// Starts recording how many bytes are read from VideoSource
void VideoSource_startBytes(VideoSource *src);

// Ends recording how many bytes are read from VideoSource
void VideoSource_endBytes(VideoSource *src);

// Rewinds and stops recording bytes read, indicating write status
bool VideoSource_waitforbytes(VideoSource *src);

// Indicates whether or not the required bytes are available
bool VideoSource_bytesready(VideoSource *src);

// Indicates EOF status for source
bool VideoSource_eof(VideoSource *src);
