//
//  MotionAnalysis.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 1/26/13.
//  Copyright (c) 2013 Matthew Bakalar. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import "FrameBuffer.h"

@interface MotionAnalysis : NSObject

- (NSMutableArray*)processFramesForMovie:(FrameBuffer*)frameBuffer;  // Mike D method

- (void)processFrameBuffer:(FrameBuffer*)frameBuffer withSerial:(NSString*)serial;  // Matt B organizing method

@end
