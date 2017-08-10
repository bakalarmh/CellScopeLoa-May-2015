//
//  DynamoDataAdaptor.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 10/27/16.
//  Copyright © 2016 Fletcher Lab. All rights reserved.
//

#import "DynamoDataAdaptor.h"
#import "Video.h"
#import "DynamoTestRecord.h"
#import "DynamoVideo.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AWSCore/AWSCore.h>
#import <AWSCognito/AWSCognito.h>
#import <AWSS3/AWSS3.h>


@implementation DynamoDataAdaptor

+ (DynamoTestRecord*)createPostWithRecord: (TestRecord*)record
{
    DynamoTestRecord *post = [[DynamoTestRecord alloc] init];
    
    post.testUUID = record.testUUID;
    NSLog(@"%@", post.testUUID);
    
    post.boardUUID = record.boardUUID;
    post.created = [NSNumber numberWithLong: [record.created timeIntervalSince1970]];
    post.localTimeZone = record.localTimeZone;
    post.phoneIdentifier = record.phoneIdentifier;
    post.deviceID = record.deviceID;
    post.simplePhoneID = record.simplePhoneID;
    post.simpleTestID = record.simpleTestID;
    post.state = record.state;
    
    post.latitude = record.latitude;
    post.longitude = record.longitude;
    post.patientNIHID = record.patientNIHID;
    
    post.objectsPerMl = record.objectsPerMl;
    post.objectsPerField = record.objectsPerField;
    post.testNIHID = record.testNIHID;
    
    
    if (isnan(post.objectsPerMl.doubleValue)) {
        post.objectsPerMl = 0;
    }
    if (isnan(post.objectsPerField.doubleValue)) {
        post.objectsPerField = 0;
    }
    if(record.testNIHID == nil) {
        post.testNIHID = @"NA";
    }

    return post;
}

+ (DynamoVideo*)createPostWithVideo: (Video*)video withTestRecord:(TestRecord*)testRecord
{
    DynamoVideo* post = [[DynamoVideo alloc] init];
    
    post.URL = [NSString stringWithFormat:@"%@/%@/%@",
                        testRecord.phoneIdentifier,
                        video.testUUID,
                        [video.resourceURL lastPathComponent]];
    post.created = [NSNumber numberWithLong: [video.created timeIntervalSince1970]];
    post.resourceURL = video.resourceURL;
    post.testUUID = video.testUUID;
    post.fieldIndex = video.fieldIndex;
    
    post.errorString = video.errorString;
    post.averageObjectCount = video.averageObjectCount;
    post.surfMotionMetric = video.surfMotionMetric;
    
    if (post.errorString == nil) {
        post.errorString = @"";
    }
    if (isnan(post.averageObjectCount.doubleValue)) {
        post.averageObjectCount = [NSNumber numberWithInteger:0];
    }
    if (post.surfMotionMetric == nil) {
        post.surfMotionMetric = [NSNumber numberWithInteger:0];
    }

    return post;
}

+ (void)syncTestRecord:(TestRecord*)record WithBlock:(void (^)(BOOL, NSError*))completionBlock
{
    // Initialize AWS
    AWSCognitoCredentialsProvider *credentialsProvider = [[AWSCognitoCredentialsProvider alloc]
                                                          initWithRegionType:AWSRegionEUCentral1
                                                          identityPoolId:@"eu-central-1:0db477eb-da4c-445a-91c1-2f9ce10f54a6"];
    
    AWSServiceConfiguration *configuration = [[AWSServiceConfiguration alloc] initWithRegion:AWSRegionEUCentral1 credentialsProvider:credentialsProvider];
    
    [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = configuration;

    // Retrieve your Amazon Cognito ID
    [[credentialsProvider getIdentityId] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            NSLog(@"Error: %@", task.error);
        }
        else {
            AWSDynamoDBObjectMapper *dynamoDBObjectMapper = [AWSDynamoDBObjectMapper defaultDynamoDBObjectMapper];
            DynamoTestRecord *post = [DynamoDataAdaptor createPostWithRecord: record];
            
            [[dynamoDBObjectMapper save:post]
             continueWithBlock:^id(AWSTask *task) {
                 if (task.error) {
                     NSLog(@"The request failed. Error: [%@]", task.error);
                 }
                 if (task.exception) {
                     NSLog(@"The request failed. Exception: [%@]", task.exception);
                 }
                 if (task.result) {
                     record.parseID = post.testUUID;
                     completionBlock(YES, task.error);
                 }
                 return nil;
             }];
        }
        return nil;
    }];
}

+ (void)syncVideosForCapillaryRecords:(NSArray*)records withBlock:(void (^)(BOOL, NSError*))completionBlock
{
    // Initialize AWS
    AWSCognitoCredentialsProvider *credentialsProvider = [[AWSCognitoCredentialsProvider alloc]
                                                          initWithRegionType:AWSRegionEUCentral1
                                                          identityPoolId:@"eu-central-1:0db477eb-da4c-445a-91c1-2f9ce10f54a6"];
    AWSServiceConfiguration *configuration = [[AWSServiceConfiguration alloc] initWithRegion:AWSRegionEUCentral1 credentialsProvider:credentialsProvider];
    [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = configuration;
    AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
    
    [[credentialsProvider getIdentityId] continueWithBlock:^id(AWSTask *task) {
        AWSDynamoDBObjectMapper *dynamoDBObjectMapper = [AWSDynamoDBObjectMapper defaultDynamoDBObjectMapper];
        for (CapillaryRecord* record in records) {
            for (Video* video in record.videos) {
                if (video.videoDeleted == FALSE) {
                    DynamoVideo* post = [self createPostWithVideo:video withTestRecord:record.testRecord];
                    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                    NSString* path = [[paths objectAtIndex:0] stringByAppendingPathComponent:video.resourceURL];
                    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
                    if (exists) {
                        
                        // Formulate video upload request
                        NSURL* fileUrl = [NSURL fileURLWithPath:path];
                        
                        AWSS3TransferManagerUploadRequest *uploadRequest = [AWSS3TransferManagerUploadRequest new];
                        uploadRequest.bucket = @"cslvideos";
                        uploadRequest.key = post.URL;
                        uploadRequest.contentType = @"movie/mov";
                        uploadRequest.body = fileUrl;
                        
                        // Reset task
                        task = [task continueWithSuccessBlock:^id(AWSTask *task) {
                            return [[transferManager upload:uploadRequest] continueWithExecutor:[AWSExecutor mainThreadExecutor]
                                                                                      withBlock:^id(AWSTask *task) {
                                [[dynamoDBObjectMapper save:post]
                                    continueWithBlock:^id(AWSTask *task) {
                                        if (task.error) {
                                            NSLog(@"The request failed. Error: [%@]", task.error);
                                        } else {
                                            //Do something with task.result or perform other operations.
                                            completionBlock(YES, task.error);
                                        }
                                        return nil;
                                }];
                                
                                return task;
                            }];
                        }];
                    }
                }
            }
        }
        return task;
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
