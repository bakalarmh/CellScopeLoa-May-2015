//
//  CaptureViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/9/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "CaptureViewController.h"
#import "constants.h"
#import "Video.h"
#import "CameraDispatcher.h"
#import "FrameBuffer.h"

@interface CaptureViewController () {
    NSInteger maxFields;
    NSInteger fieldIndex;
    NSInteger maxFrames;
    NSInteger frameIndex;
    FrameBuffer* frameBuffer;
}

@end

@implementation CaptureViewController

@synthesize camera;
@synthesize delegate;
@synthesize cameraPreviewView;
@synthesize focusSlider;
@synthesize focusModeControl;
@synthesize cameraButton;
@synthesize managedObjectContext;
@synthesize cslContext;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Hard code the number of frames expected from the camera. Not happy about this
    maxFrames = 150;
    
    // Load the number of fields of view to acquire from user defaults
    maxFields = [[[NSUserDefaults standardUserDefaults] objectForKey:FieldsOfViewKey] integerValue];
    
    // Set up the camera
    camera = [[LLCamera alloc] init];
    [camera setPreviewLayer:cameraPreviewView.layer];
    
    // Start the camera session
    [camera startCamera];

    // Set up the delegates
    camera.focusDelegate = self;
    camera.captureDelegate = self;
    camera.frameProcessingDelegate = self;
    
    NSNumber* manualFocusDefault = [[NSUserDefaults standardUserDefaults] objectForKey:ManualFocusLensPositionKey];
    [camera setFocusLensPosition:manualFocusDefault];
    
    // Set the camera exposure and white balance to default values
    float exposure = [[[NSUserDefaults standardUserDefaults] objectForKey:ExposureKey] floatValue];
    float iso = [[[NSUserDefaults standardUserDefaults] objectForKey:ISOKey] floatValue];
    
    [camera setRelativeExposure:exposure];
    [camera setRelativeISO:iso];
    
    // Set up UI
    CGAffineTransform trans = CGAffineTransformMakeRotation(M_PI_2);
    focusSlider.transform = trans;
    focusSlider.enabled = YES;
    focusSlider.alpha = 1.0;
    
    // Set the capture state
    fieldIndex = 0;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)launchDataAcquisition
{
    if (fieldIndex < maxFields) {
        NSURL* assetURL = [cslContext generateUniqueURLWithRecord:cslContext.activeTestRecord];
        [camera captureWithDuration:5.0 URL:assetURL];
        [UIView animateWithDuration:0.3 animations:^{
            cameraButton.enabled = NO;
        }];
    }
    else {
        NSLog(@"Acquisition of %d fields of view complete", (int)maxFields);
        [delegate didCompleteCapture];
        // Return to the test view controller
        [[self navigationController] popViewControllerAnimated:YES];
    }
}

- (void)prepareNextDataAcquisition
{
    fieldIndex += 1;
    frameBuffer = [[FrameBuffer alloc] initWithWidth:camera.width Height:camera.height Frames:maxFrames];
    frameIndex = 0;
    NSLog(@"Advance bluetooth stage");
    NSLog(@"Wait for sync");
    [self launchDataAcquisition];
}

- (void)captureDidFinishWithURL:(NSURL *)assetURL
{
    NSLog(@"Capture finished!");
    [delegate didCaptureVideoWithURL:assetURL];
    [self prepareNextDataAcquisition];
}

- (void)didReceiveFrameBuffer:(CVBufferRef)buffer
{
    [frameBuffer writeFrame:buffer atIndex:[NSNumber numberWithLong:frameIndex]];
    frameIndex += 1;
    NSLog(@"Wrote frame at %d", (int)(frameIndex)-1);
}

- (void)didFinishRecordingFrames:(LLCamera*)sender
{
    
}

- (IBAction)cameraPressed:(id)sender {
    [self.navigationItem setHidesBackButton:YES animated:YES];
    [UIView animateWithDuration:0.3 animations:^{
        focusSlider.alpha = 0.0;
        focusModeControl.alpha = 0.0;
    }];
    [self launchDataAcquisition];
}

- (IBAction)focusSliderValueChanged:(id)sender {
    [camera setFocusLensPosition:[NSNumber numberWithFloat:focusSlider.value]];
}

- (IBAction)focusModeChanged:(id)sender {
    if (focusModeControl.selectedSegmentIndex == 0) {
        [camera setFocusLensPosition:[NSNumber numberWithFloat:focusSlider.value]];
        focusSlider.enabled = YES;
        // Fade the focusSlider in
        [UIView animateWithDuration:0.3 animations:^{
            focusSlider.alpha = 1.0;
        }];
    }
    else if (focusModeControl.selectedSegmentIndex == 1) {
        [camera setContinuousAutoFocusState];
        focusSlider.enabled = NO;
        // Fade the focusSlider out
        [UIView animateWithDuration:0.3 animations:^{
            focusSlider.alpha = 0.0;
        }];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    // Stop the capture session
    [camera stopCamera];
    
    // Store the latest manual focus setting as default
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:focusSlider.value] forKey:ManualFocusLensPositionKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)focusDidChange:(NSNumber*)focusLensPosition
{
    focusSlider.value = focusLensPosition.floatValue;
}

@end
