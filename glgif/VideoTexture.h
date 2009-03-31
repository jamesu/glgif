/*
 
 glgif
 
 VideoTexture - wrapper for uploading OpenGLES textures.
 
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
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

typedef struct VideoTexture {
    GLuint tex;
    GLint format;
    int width;
    int height;
    
    int size;
    char *data;
} VideoTexture;

// Initializes VideoTexture.
extern VideoTexture* VideoTexture_init(int width, int height, GLint fmt);

// Releases VideoTexture. Will free if retain count is 0
extern void VideoTexture_release(VideoTexture *tex);

// Locks texture for updating
extern bool VideoTexture_lock(VideoTexture *tex);

// Unlocks texture, uploading updated texture
extern bool VideoTexture_unlock(VideoTexture *tex);

// Uploads initial texture
extern bool VideoTexture_load(VideoTexture *tex);

// Is the texture compressed? (e.g. PVR)
extern bool VideoTexture_compressed(GLint fmt);

// Determine size of texture in bytes
extern int VideoTexture_sizeOfTexture(GLint format, int width, int height, int mipmaplevels);

