# glgif

## What is it?

glgif is a comprehensive library for playing back .gif animations on the iPhone using OpenGLES.

## Sounds great, how do i use it?

At the core, glgif merely uploads frames from a gif animation to an OpenGLES texture. So all you need to do is the following:

    // Load the gif
    FILE *fp = fopen("test.gif", "r");
    VideoSource *src = VideoSource_init(fp, VIDEOSOURCE_FILE);
    
    // Init video using VideoSource
    GifVideo *vid = [[GifVideo alloc] initWithSource:src inContext:[yourGLESContext]];
    VideoSource_release(src);

    // Set up the disposal texture
    [vid setupRenderTexture];

    // Setup our OpenGL context (viewFramebuffer is the frame buffer, backingWidth & backingHeight is the framebuffer size)
    GLfloat projectionMatrix[16];
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(0, backingWidth, 0, backingHeight, -1, 1);
    glGetFloatv(GL_PROJECTION_MATRIX, projectionMatrix);

    // Tell the gif renderer where we are rendering to
    vid.viewRenderInfo = TargetRenderInfoMake(viewFramebuffer, GIFRectMake(0, 0, backingWidth, backingHeight), projectionMatrix);

    // Then every frame...
    [vid drawNextFrame:1.0f/60.0f]; // draw in the current opengl context
    
## Whoah, that is so complicated. Is there an easier way?

Why yes, indeed there is! An example project has been included which implements a nice OpenGLES view to display a test .gif. So all you need to do once you make a GifVideo* is:

    [playerView startAnimation:vid];

## Why is there a modified version of lungif?

Normally lungif will keep around decoded versions of frames. Currently glgif does not use these frames - rather it decodes frames on the fly - so there is a hack which turns off the storage of these images via generateSavedImages.

If you want to use a normal version of lungif simply uncomment the following in GifVideo.m:

    if (gifinfo)
        gifinfo->generateSavedImages = false;

## Do any cool iPhone applications use this code?

The only app at the moment is <a href="http://www.itunes.com/app/anim8gif">anim8gif</a>.
