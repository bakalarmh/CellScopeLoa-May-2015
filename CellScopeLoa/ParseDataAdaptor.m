//
//  ParseDataAdaptor.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/17/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "ParseDataAdaptor.h"
#import <Parse/Parse.h>
#import "Video.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@implementation ParseDataAdaptor

+ (void)syncTestRecord:(TestRecord*)record WithBlock:(void (^)(BOOL, NSError*))completionBlock
{
    PFUser *currentUser = [PFUser currentUser];
    if (currentUser) {
        NSLog(@"Current user: %@", currentUser.username);
        //run the query here
    }
    else {
        NSLog(@"user not logged in");
    }
    
    PFObject *post = [PFObject objectWithClassName:@"TestRecord"];
    
    /*
    [post setObject:record.boardUUID forKey:@"boardUUID"];
    [post setObject:record.testUUID forKey:@"testUUID"];
    [post setObject:record.created forKey:@"created"];
    
    [post setObject:record.localTimeZone forKey:@"localTimeZone"];
    [post setObject:record.phoneIdentifier forKey:@"phoneIdentifier"];
    
    if (record.deviceID != nil) {
        [post setObject:record.deviceID forKey:@"deviceID"];
    }
    if (record.simplePhoneID != nil) {
        [post setObject:record.simplePhoneID forKey:@"simplePhoneID"];
    }
    
    if (record.state != nil) {
        [post setObject:record.state forKey:@"state"];
    }
    if ((record.objectsPerMl != nil) && (![record.objectsPerMl isEqualToNumber:[NSDecimalNumber notANumber]])) {
        [post setObject:record.objectsPerMl forKey:@"objectsPerMl"];
    }
    if ((record.objectsPerField != nil) && (![record.objectsPerField isEqualToNumber:[NSDecimalNumber notANumber]])) {
        [post setObject:record.objectsPerField forKey:@"objectsPerField"];
    }
    if (record.latitude != nil) {
        [post setObject:record.latitude forKey:@"latitude"];
    }
    if (record.longitude != nil) {
        [post setObject:record.longitude forKey:@"longitude"];
    }
    if (record.patientNIHID != nil) {
        [post setObject:record.patientNIHID forKey:@"patientNIHID"];
    }
    if (record.testMode != nil) {
        [post setObject:record.testMode forKey:@"testMode"];
    }
    if (record.testNIHID != nil) {
        [post setObject:record.testNIHID forKey:@"testNIHID"];
    }
    */

    // Save it to Parse with completion block
    [post saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (completionBlock != nil) {
            record.parseID = post.objectId;
            completionBlock(succeeded, error);
        }
    }];
}

+ (void)syncCapillaryRecord:(CapillaryRecord*)record WithBlock:(void (^)(BOOL, NSError*))completionBlock
{
    PFObject *post = [PFObject objectWithClassName:@"CapillaryRecord"];

    if (record.created != nil) {
        [post setObject:record.created forKey:@"created"];
    }
    if (record.testUUID != nil) {
        [post setObject:record.testUUID forKey:@"testUUID"];
    }
    if (record.errorString != nil) {
        [post setObject:record.errorString forKey:@"errorString"];
    }
    if (record.capillaryIndex != nil) {
        [post setObject:record.capillaryIndex forKey:@"capillaryIndex"];
    }
    if ((record.objectsPerMl != nil) && (![record.objectsPerMl isEqualToNumber:[NSDecimalNumber notANumber]])) {
        [post setObject:record.objectsPerMl forKey:@"objectsPerMl"];
    }
    if ((record.objectsPerField != nil) && (![record.objectsPerField isEqualToNumber:[NSDecimalNumber notANumber]])) {
        [post setObject:record.objectsPerField forKey:@"objectsPerField"];
    }
    
    if ((record.testRecord != nil) && (record.testRecord.parseID != nil)) {
        PFObject* testRecord = [PFObject objectWithoutDataWithClassName:@"TestRecord" objectId:record.testRecord.parseID];
        [post setObject:testRecord forKey:@"testRecord"];
    }
    
    // Save it to Parse with completion block
    [post saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (completionBlock != nil) {
            record.parseID = post.objectId;
            completionBlock(succeeded, error);
        }
    }];
}

+ (void)syncVideosForCapillaryRecord:(CapillaryRecord*)record withBlock:(void (^)(BOOL, NSError*))completionBlock
{
    // Retreive the capillary record
    PFQuery *query = [PFQuery queryWithClassName:@"CapillaryRecord"];
    [query getObjectInBackgroundWithId:record.parseID block:^(PFObject *post, NSError *error) {
        
        // Store all capillary videos
        for (Video* video in record.videos) {
            if (video.parseID == nil) {
                PFObject *pfvideo = [PFObject objectWithClassName:@"Video"];
                
                [pfvideo setObject:video.created forKey:@"created"];
                [pfvideo setObject:video.resourceURL forKey:@"resourceURL"];
                [pfvideo setObject:video.testUUID forKey:@"testUUID"];
                [pfvideo setObject:video.capillaryIndex forKey:@"capillaryIndex"];
                [pfvideo setObject:video.fieldIndex forKey:@"fieldIndex"];
                
                if (video.errorString != nil) {
                    [pfvideo setObject:video.errorString forKey:@"errorString"];
                }
                if (video.averageObjectCount != nil) {
                    [pfvideo setObject:video.averageObjectCount forKey:@"averageObjectCount"];
                }
                if (video.motionObjects != nil) {
                    NSLog(@"Motion objects available to store");
                }
                if (video.surfMotionMetric != nil) {
                    [pfvideo setObject:video.averageObjectCount forKey:@"surfMotionMetric"];
                }
                if (video.diffMotionMetric != nil) {
                    [pfvideo setObject:video.averageObjectCount forKey:@"diffMotionMetric"];
                }
                
                // Upload the video to the cloud
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString* path = [[paths objectAtIndex:0] stringByAppendingPathComponent:video.resourceURL];

                BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
                if (exists) {
                    NSData* data = [NSData dataWithContentsOfFile:path];
                    PFFile *videoFile = [PFFile fileWithName:@"cslvideo.mov" data:data];
                    NSLog(@"%@", videoFile);
                     [videoFile saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                         if (!error) {
                             [pfvideo setObject:videoFile forKey:@"videoFile"];
                             [pfvideo saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                                 // Save the video parseID in core data
                                 video.parseID = pfvideo.objectId;
                                 completionBlock(succeeded, error);
                             }];
                         }
                         else {
                             NSLog(@"Parse save error!");
                         }
                     }];
                }
                else {
                    completionBlock(FALSE, error);
                }
            }
        }
    }];
}

- (void)convertVideoToLowQuality:(Video*)video
                                     handler:(void (^)(AVAssetExportSession*))handler
{
    NSString *tempFilePath = [NSTemporaryDirectory()
                                  stringByAppendingPathComponent:@"recording.mov"];
    NSURL* outputURL = [NSURL URLWithString:tempFilePath];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* path = [[paths objectAtIndex:0] stringByAppendingPathComponent:video.resourceURL];
    
    NSURL* url = [NSURL fileURLWithPath:path isDirectory:NO];
    AVURLAsset* asset = [AVURLAsset assetWithURL:url];
    
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetMediumQuality];
    
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeQuickTimeMovie;
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void)
     {
         handler(exportSession);
     }];
}

@end
