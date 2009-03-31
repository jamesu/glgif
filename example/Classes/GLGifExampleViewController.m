/*
 
 glgif
 
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

#import "GLGifExampleViewController.h"
#import "GifVideo.h"
#import "VideoSource.h"
#import "PlayerView.h"

@implementation GLGifExampleViewController

@synthesize okToRotate;


// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
        okToRotate = false;
    }
    return self;
}


/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/



// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    PlayerView *plView = (PlayerView*)self.view;
    
    // Load test.gif VideoSource
    NSString *str = [[NSBundle mainBundle] pathForResource:@"test.gif" ofType:nil];
    FILE *fp = fopen([str UTF8String], "r");
    VideoSource *src = VideoSource_init(fp, VIDEOSOURCE_FILE);
    src->writeable = false;
    
    // Init video using VideoSource
    Video *vid = [[GifVideo alloc] initWithSource:src inContext:[plView context]];
    VideoSource_release(src);
    
    // Start if loaded
    if (vid) {
        [plView startAnimation:vid];
        [vid release];
        return;
    }
    
    // Cleanup if failed
    fclose(fp);
    return;
}




// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    if (okToRotate)
        [(PlayerView*)self.view setTargetOrient:interfaceOrientation];
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc {
    [super dealloc];
}

@end
