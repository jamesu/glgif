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

#import "VideoTexture.h"

// GL_LINEAR == interpolates, GL_NEAREST == blocky
static GLint sMinFilter = GL_NEAREST;
static GLint sMagFilter = GL_NEAREST;

void VideoTexture_filter(GLint filter)
{
    sMinFilter = sMagFilter = filter;
}

VideoTexture *VideoTexture_init(int width, int height, GLint fmt) {
    VideoTexture *build = malloc(sizeof(VideoTexture));
    build->width = width;
    build->height = height;
    build->format = fmt;
    build->size = VideoTexture_sizeOfTexture(fmt, width, height, 0);
    
    build->data = (char*)malloc(build->size);
    
    // Clear base
    int i;
    int mipmaplevels = 0;
    char *ptr = build->data;
    int sw = width;
    int sh = height;
    int sz = VideoTexture_sizeOfTexture(fmt, sw, sh, 0);
    
    memset(ptr, 0, sz);
    ptr += sz;
    
    // Clear mips
    for (i=0; i<mipmaplevels; i++) {
        sw >>= 1;
        sh >>= 1;
        
        sz = VideoTexture_sizeOfTexture(fmt, sw, sh, 0);
        memset(ptr, 0, sz);
        ptr += sz;
    }
    
    VideoTexture_load(build);
    
    return build;
}

void VideoTexture_release(VideoTexture *tex)
{
    if (tex->tex)
    {
        glDeleteTextures(1, &tex->tex);
        tex->tex = 0;
    }
    if (tex->data) {
        free(tex->data);
        tex->data = NULL;
    }
    
    free(tex);
}

bool VideoTexture_lock(VideoTexture *tex) {
    if (tex->data)
        return false;
    
    tex->size = VideoTexture_sizeOfTexture(tex->format, tex->width, tex->height, 0);
    tex->data = malloc(tex->size);
    
    return true;
}

bool VideoTexture_unlock(VideoTexture *tex) {
    glBindTexture( GL_TEXTURE_2D, tex->tex );
    {
        // Re-load to card
        if (VideoTexture_compressed(tex->format)) {
            glCompressedTexImage2D ( GL_TEXTURE_2D,
                                    0, // start level
                                    tex->format,
                                    tex->width,
                                    tex->height,
                                    0,
                                    tex->size,
                                    tex->data );
        } else {
            glTexSubImage2D( GL_TEXTURE_2D,
                            0, // level
                            0, 0, // x,y offset
                            tex->width,
                            tex->height,
                            tex->format,
                            GL_UNSIGNED_BYTE,
                            tex->data);
        }
        
        // Clean up data!
        free(tex->data);
        tex->data = NULL;
        tex->size = 0;
    }
    
    return true;
}

bool VideoTexture_load(VideoTexture *tex) {
    
    glGenTextures(1, &tex->tex);
    glBindTexture( GL_TEXTURE_2D, tex->tex );
    
    // Filters
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, sMagFilter );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, sMinFilter );
    
    // Wrap
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    if (VideoTexture_compressed(tex->format)) {
        glCompressedTexImage2D ( GL_TEXTURE_2D,
                                0, // level
                                tex->format,
                                tex->width,
                                tex->height,
                                0, // border
                                tex->size,
                                tex->data );
    } else {
        glTexImage2D( GL_TEXTURE_2D,
                     0, // level
                     tex->format,
                     tex->width,
                     tex->height,
                     0, // levels
                     tex->format,
                     GL_UNSIGNED_BYTE,
                     tex->data);
    }
    
    free(tex->data);
    tex->data = NULL;
    tex->size = 0;
    
    return true;
}

bool VideoTexture_compressed(GLint fmt)
{
    if (fmt == GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG ||
        fmt == GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG ||
        fmt == GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG ||
        fmt == GL_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG ||
        fmt == GL_PALETTE4_RGB8_OES ||
        fmt == GL_PALETTE4_RGBA8_OES ||
        fmt == GL_PALETTE4_R5_G6_B5_OES  ||
        fmt == GL_PALETTE4_RGBA4_OES ||
        fmt == GL_PALETTE4_RGB5_A1_OES ||
        fmt == GL_PALETTE8_RGB8_OES ||
        fmt == GL_PALETTE8_RGBA8_OES  ||
        fmt == GL_PALETTE8_R5_G6_B5_OES  ||
        fmt == GL_PALETTE8_RGBA4_OES ||
        fmt == GL_PALETTE8_RGB5_A1_OES)
        return true;
    else
        return false;
}

int VideoTexture_sizeOfTexture(GLint format, int width, int height, int mipmaplevels)
{
    int base = 0; // e.g. palette size
    int bpp = 0;
    
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
    
    switch (format)
    {
            // PVRTC compressed formats
            
        case GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG:
            bpp = 4;
        case GL_COMPRESSED_RGB_PVRTC_2BPPV1_IMG:
            bpp = 2;
            break;
        case GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG:
            bpp = 4;
            break;
        case GL_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG:
            bpp = 2;
            break;
            
            // Palette formats
            
        case GL_PALETTE8_RGB8_OES:
            bpp = 8;
            base = 256*3;
            break;
        case GL_PALETTE8_RGBA8_OES:
            bpp = 8;
            base = 256*4;
            break;
        case GL_PALETTE8_R5_G6_B5_OES:
        case GL_PALETTE8_RGBA4_OES:
        case GL_PALETTE8_RGB5_A1_OES:
            bpp = 8;
            base = 256*2;
            break;
            
        case GL_PALETTE4_RGB8_OES:
            bpp = 4;
            base = 16*3;
            break;
        case GL_PALETTE4_RGBA8_OES:
            bpp = 4;
            base = 16*4;
            break;
        case GL_PALETTE4_R5_G6_B5_OES:
        case GL_PALETTE4_RGBA4_OES:
        case GL_PALETTE4_RGB5_A1_OES:
            bpp = 4;
            base = 16*2;
            break;
            
            // RGB
            
        case GL_ALPHA:
        case GL_LUMINANCE:
            bpp = 8;
            break;
            
        case GL_LUMINANCE_ALPHA:
            bpp = 16;
            break;
            
        case GL_RGB:
            bpp = 24;
            break;
            
        case GL_RGBA:
        case GL_BGRA:
            bpp = 32;
            break;
    }
    
    if (mipmaplevels > 0) {
        // Calculate size including mipmaps
        int sw = height;
        int sh = height;
        int sz = base + (width * height * bpp / 8);
        int count = mipmaplevels;
        
        if (count < 0)
            return sz;
        
        while (count-- != 0) {
            sw >>= 1;
            sh >>= 1;
            
            if (sw < 1)
                sw = 1;
            if (sh < 1)
                sh = 1;
            
            sz += base + (sw * sh * bpp / 8);
        }
        
        return sz;
    } else
        return base + (width * height * bpp / 8);
}
