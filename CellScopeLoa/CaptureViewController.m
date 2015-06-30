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
    BOOL launchAfterFocus;
    BOOL checkingFocusFrame;
}

@end

@implementation CaptureViewController

@synthesize camera;
@synthesize delegate;
@synthesize cameraPreviewView;
@synthesize focusSlider;
@synthesize cameraButton;
@synthesize metricLabel;
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
    
    // Turn on the imaging LED and initialize the capillary position
    if (cslContext.loaDevice != nil) {
        [cslContext.loaDevice LEDOn];
        [cslContext.loaDevice servoLoadPosition];
    }
    
    // Do not default to manual focus
    [camera setContinuousAutoFocusState];
    focusSlider.enabled = NO;
    
    // Hard coded exposure and iso. I am not happy with this.
    CMTime exposure = CMTimeMake(1, 128);
    [camera setExposureMinISO:exposure];
    [camera setColorTemperatureKelvin:5700];
    
    // Launch the self test
    cameraButton.enabled = YES;
    
    // Set up UI
    CGAffineTransform trans = CGAffineTransformMakeRotation(M_PI_2);
    focusSlider.transform = trans;
    
    // Set the capture state
    fieldIndex = 0;
    launchAfterFocus = NO;
    checkingFocusFrame = NO;
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

- (void)checkFocusFrame
{
    NSLog(@"Check?");
    checkingFocusFrame = YES;
    [camera processSingleFrame];
}

- (void)launchDataAcquisition
{
    if (fieldIndex < maxFields) {
        // Record the final focus position to check for error
        NSNumber* focusPosition = camera.focusLensPosition;
        NSLog(@"Focus position = %f", focusPosition.floatValue);
        
        // Create a new frame buffer to store video frames
        frameBuffer = [[FrameBuffer alloc] initWithWidth:camera.width Height:camera.height Frames:maxFrames];
        NSURL* assetURL = [cslContext generateUniqueURLWithRecord:cslContext.activeTestRecord];
        [camera captureWithDuration:5.0 URL:assetURL];
        [UIView animateWithDuration:0.3 animations:^{
            cameraButton.enabled = NO;
        }];
    }
}

- (void)precaptureDeviceTest
{
    cameraButton.enabled = YES;
}

- (void)prepareNextDataAcquisition
{
    fieldIndex += 1;
    frameIndex = 0;
    
    if (fieldIndex < maxFields) {
        // Advance the capillary and delay for sync
        if (cslContext.loaDevice != nil) {
            [cslContext.loaDevice servoAdvance];
        }
        int msdelay = 250;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, msdelay * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            // MHB Focus Test
            //[camera setImmediateAutoFocusState];
            [camera setFocusLensPosition:[NSNumber numberWithFloat:0.0]];
            int msdelay = 2500;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, msdelay * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                // [self launchDataAcquisition];
                [self checkFocusFrame];
            });
        });
    }
    else {
        // Capillary capture is complete
        [delegate didCompleteCapillaryCapture];
        
        // Advance the capillary and delay for sync
        if (cslContext.loaDevice != nil) {
            [cslContext.loaDevice servoLoadPosition];
        }
        
        // Return to the test view controller
        [[self navigationController] popViewControllerAnimated:YES];
    }
}

- (void)captureDidFinishWithURL:(NSURL *)assetURL
{
    NSLog(@"Capture finished!");
    [delegate didCaptureVideoWithURL:assetURL frameBuffer:frameBuffer];
    // Prepare next acquisition
    [self prepareNextDataAcquisition];
}

- (void)didReceiveFrame:(CVBufferRef)frame
{
    if (checkingFocusFrame) {
        // Launch data acquisition after checking the focus
        checkingFocusFrame = NO;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
            [camera stopSendingFrames];
            [self launchDataAcquisition];
        }];
    }
    else {
        [frameBuffer writeFrame:frame atIndex:[NSNumber numberWithLong:frameIndex]];
        frameIndex += 1;
    }
}

- (void)didFinishRecordingFrames:(LLCamera*)sender
{
    
}

- (IBAction)cameraPressed:(id)sender {
    [self.navigationItem setHidesBackButton:YES animated:YES];
    [UIView animateWithDuration:0.3 animations:^{
        cameraButton.enabled = NO;
    }];
    
    [camera setImmediateAutoFocusState];
    int msdelay = 2500;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, msdelay * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        // [self launchDataAcquisition];
        [self checkFocusFrame];
    });

}

- (IBAction)focusSliderValueChanged:(id)sender {
    [camera setFocusLensPosition:[NSNumber numberWithFloat:focusSlider.value]];
}

- (void)viewWillDisappear:(BOOL)animated
{
    // Stop the capture session
    [camera stopCamera];
    
    // Turn off the imaging LED
    if (cslContext.loaDevice != nil) {
        [cslContext.loaDevice LEDOff];
    }
    
    // Store the latest manual focus setting as default
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:focusSlider.value] forKey:ManualFocusLensPositionKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)focusDidChange:(NSNumber*)focusLensPosition
{
    focusSlider.value = focusLensPosition.floatValue;
}

@end
