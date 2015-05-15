//
//  LLCamera.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/10/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "CameraDispatcher.h"

@protocol FocusDelegate
- (void)focusDidChange:(NSNumber*)focusLensPosition;
@end

@protocol CaptureDelegate
- (void)captureDidFinishWithURL:(NSURL*)assetURL;
@end

@protocol FrameProcessingDelegate
- (void)didReceiveFrameBuffer:(CVBufferRef)buffer;
- (void)didFinishRecordingFrames:(LLCamera*)sender;
@end

@interface LLCamera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (weak, nonatomic) id<AVCaptureVideoDataOutputSampleBufferDelegate> sampleBufferDelegate;
@property (weak, nonatomic) id<AVCaptureFileOutputRecordingDelegate> recordingDelegate;
@property (weak, nonatomic) id<FocusDelegate> focusDelegate;
@property (weak, nonatomic) id<CaptureDelegate> captureDelegate;
@property (weak, nonatomic) id<FrameProcessingDelegate> frameProcessingDelegate;

@property (weak, nonatomic) NSNumber* focusLensPosition;
@property (assign, nonatomic) NSInteger width;
@property (assign, nonatomic) NSInteger height;
@property (strong, nonatomic) AVCaptureSession* session;

- (void)setPreviewLayer:(CALayer*)previewLayer;
- (void)startCamera;
- (void)stopCamera;
- (void)captureWithDuration:(Float32)duration URL:(NSURL*)outputURL;
- (AVCaptureWhiteBalanceGains)getCurrentWhiteBalanceGains;
- (void)setManualFocusState;
- (void)setContinuousAutoFocusState;
- (void)setImmediateAutoFocusState;
- (void)setImmediateWhiteBalanceState;
- (void)setContinuousWhiteBalanceState;
- (void)setLockedWhiteBalanceState;
- (void)setWhiteBalanceGains:(AVCaptureWhiteBalanceGains)gains;
- (void)setFocusLensPosition:(NSNumber*)position;
- (void)setRelativeExposure:(float)value;
- (void)setRelativeISO:(float)iso;

@end
