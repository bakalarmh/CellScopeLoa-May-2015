//
//  VideosViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/31/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "VideosViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface VideosViewController () {
    NSArray* orderedVideos;
    NSInteger index;
}

@end

@implementation VideosViewController {
    CIImage* backgroundImage;
    CIImage* lastMotionImage;
    CIImage* sumImage;
    CIImage* processedMotionImage;
    CIImage* blackImage;
    NSMutableArray* imageQueue;
    AVAssetReader* reader;
    NSTimer* animationTimer;
}

@synthesize video;
@synthesize videos;
@synthesize managedObjectContext;
@synthesize cslContext;

@synthesize imageView;
@synthesize errorLabel;
@synthesize scrollView;
@synthesize layerSegmentedControl;
@synthesize videoIndex;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    orderedVideos = [videos allObjects];
    [self.navigationController setToolbarHidden:YES animated:YES];
    
    scrollView.minimumZoomScale = 0.9;
    scrollView.maximumZoomScale = 6.0;
    [scrollView setZoomScale:1.0 animated:YES];
    scrollView.delegate = self;
    
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    
    index = 0;
    video = [orderedVideos objectAtIndex:index];
    videoIndex.text = [NSString stringWithFormat:@"%d", (int)index];
    
    [self populateVideoInformation];
    [self initProcessing];
    
    [self startProcessing];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)populateVideoInformation
{
    if (![video.errorString isEqualToString:@"None"]) {
        errorLabel.text = video.errorString;
        errorLabel.alpha = 1.0;
    }
    else {
        errorLabel.alpha = 0.0;
    }
}

- (void)initProcessing
{
    // Set up the image queue
    imageQueue = [[NSMutableArray alloc] initWithCapacity:10];
    
    // Create a black image
    CIFilter* blackGenerator = [CIFilter filterWithName:@"CIConstantColorGenerator"];
    CIColor* black = [CIColor colorWithString:@"0.0 0.0 0.0 1.0"];
    [blackGenerator setValue:black forKey:@"inputColor"];
    blackImage = [blackGenerator valueForKey:@"outputImage"];
}

- (void)startProcessing
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* path = [[paths objectAtIndex:0] stringByAppendingPathComponent:video.resourceURL];
    
    NSURL* url = [NSURL fileURLWithPath:path isDirectory:NO];
    AVURLAsset* asset = [AVURLAsset assetWithURL:url];
    reader = [[AVAssetReader alloc] initWithAsset:asset error:Nil];
    
    NSArray* tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack* track = [tracks objectAtIndex:0];
    
    NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] init];
    NSNumber* format = [NSNumber numberWithInt:kCVPixelFormatType_32BGRA];
    [dictionary setObject:format forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
    AVAssetReaderTrackOutput* readerOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:dictionary];
    [reader addOutput:readerOutput];
    [reader startReading];
    
    float interval = 1.0/10.0;
    animationTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(animateVideo:) userInfo:nil repeats:YES];
}

- (void)animateVideo:(NSTimer *)timer
{
    if ([reader status] == AVAssetReaderStatusReading) {
        CMSampleBufferRef buffer = [reader.outputs.firstObject copyNextSampleBuffer];
        if (buffer == nil) {
            // NSLog(@"Nil!");
        }
        else {
            CGImageRef image = [self imageFromSampleBuffer:buffer];
            [self didReceiveFrame:image];
            CFRelease(buffer);
        }
    }
    else {
        [self stopPlayback];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self startProcessing];
        });
    }
}

- (void)stopPlayback
{
    [animationTimer invalidate];
    [reader cancelReading];
    [imageQueue removeAllObjects];
    
    backgroundImage = nil;
    processedMotionImage = nil;
    lastMotionImage = nil;
    sumImage = nil;
    reader = nil;
}

- (void)didReceiveFrame:(CGImageRef)imageRef
{
    @autoreleasepool {
        CIImage *inputImage = [CIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        
        CIFilter* filter = [CIFilter filterWithName:@"CIPhotoEffectMono"];
        [filter setValue:inputImage forKey:kCIInputImageKey];
        CIImage *grayscaleImage = [filter valueForKey:kCIOutputImageKey];
        
        if (backgroundImage != nil) {
            filter = [CIFilter filterWithName:@"CISubtractBlendMode"];
            [filter setValue:grayscaleImage forKey:kCIInputImageKey];
            [filter setValue:backgroundImage forKey:kCIInputBackgroundImageKey];
            CIImage* output = [filter valueForKey:kCIOutputImageKey];
            
            [imageQueue insertObject:output atIndex:0];
            
            if (sumImage == nil) {
                sumImage = output;
            }
            else {
                filter = [CIFilter filterWithName:@"CIAdditionCompositing"];
                [filter setValue:output forKey:kCIInputImageKey];
                [filter setValue:sumImage forKey:kCIInputBackgroundImageKey];
                output = [filter valueForKey:kCIOutputImageKey];
                sumImage = output;
            }
            
            if (imageQueue.count > 10) {
                filter = [CIFilter filterWithName:@"CIGaussianBlur"];
                [filter setValue:output forKey:kCIInputImageKey];
                [filter setValue:[NSNumber numberWithFloat:4.0] forKey:kCIInputRadiusKey];
                output = [filter valueForKey:kCIOutputImageKey];
                
                filter = [CIFilter filterWithName:@"CIFalseColor"];
                [filter setValue:output forKey:kCIInputImageKey];
                [filter setValue:[CIColor colorWithRed:0.0 green:0.0 blue:0.0] forKey:@"inputColor0"];
                [filter setValue:[CIColor colorWithRed:0.0 green:1.0 blue:0.0] forKey:@"inputColor1"];
                processedMotionImage = [filter valueForKey:kCIOutputImageKey];
                
                // Empty the image queue
                [imageQueue removeAllObjects];
                sumImage = nil;
            }
            
            if (layerSegmentedControl.selectedSegmentIndex == 0) {
                output = grayscaleImage;
            }
            else {
                if (processedMotionImage != nil) {
                    // Add the motion layer on top of the grayscale image
                    filter = [CIFilter filterWithName:@"CIAdditionCompositing"];
                    [filter setValue:processedMotionImage forKey:kCIInputImageKey];
                    [filter setValue:grayscaleImage forKey:kCIInputBackgroundImageKey];
                    output = [filter valueForKey:kCIOutputImageKey];
                }
                else {
                    output = blackImage;
                }
            }
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
                // Create a CG-back UIImage
                CGImageRef cgOutputImage = [[CIContext contextWithOptions:nil] createCGImage:output fromRect:grayscaleImage.extent];
                UIImage* outputImage = [UIImage imageWithCGImage:cgOutputImage];
                UIImage * rotatedImage = [[UIImage alloc] initWithCGImage: outputImage.CGImage
                                                                    scale: 1.0
                                                              orientation: UIImageOrientationRight];
                imageView.image = rotatedImage;
                CGImageRelease(cgOutputImage);
            }];
            
        }
        backgroundImage = grayscaleImage;
    }
}

// Create a CGImageRef from sample buffer data
- (CGImageRef)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);        // Lock the image buffer
    
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);   // Get information of the image
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    CGContextRelease(newContext);
    
    CGColorSpaceRelease(colorSpace);

    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // CVBufferRelease(imageBuffer);  // do not call this!
    
    return newImage;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.imageView;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopPlayback];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)forwardPressed:(id)sender {
    [self stopPlayback];
    [self populateVideoInformation];
    [self initProcessing];
    index += 1;
    if (index >= orderedVideos.count) {
        index = 0;
    }
    video = [orderedVideos objectAtIndex:index];
    videoIndex.text = [NSString stringWithFormat:@"%d", (int)index];
    [self startProcessing];
}
@end
