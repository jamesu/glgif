# glgif

## What is it?

glgif is a fast and comprehensive library for playing back .gif animations on the iPhone using OpenGLES.

## Sounds great, how do i use it?

At the core, glgif merely uploads frames from a gif animation to an OpenGLES texture. So all you need to do is the following:

    // Load the gif
    FILE *fp = fopen("test.gif", "r");
    VideoSource *src = VideoSource_init(fp, VIDEOSOURCE_FILE);
    
    // Init video using VideoSource
    GifVideo *vid = [[GifVideo alloc] initWithSource:src inContext:[yourGLESContext]];
    VideoSource_release(src);
    
    // Start playing the video
    [vid play:YES];
    
    // Then every frame...
    [vid getFrame]; // grab new frame data
    glBindTexture(GL_TEXTURE_2D, vid.tex->tex); // bind the video texture!
    
## Whoah, that is so complicated. Is there an easier way?

Why yes, indeed there is! An example project has been included which implements a nice OpenGLES view to display a test .gif. So all you need to do once you make a GifVideo* is:

    [playerView startAnimation:vid]; 

## Do any cool iPhone applications use this code?

The only app at the moment is "anim8gif":http://www.itunes.com/app/anim8gif .
