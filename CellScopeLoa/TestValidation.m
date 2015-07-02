//
//  TestValidator.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/15/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "TestValidation.h"
#import "TestRecord.h"
#import "CapillaryRecord.h"
#import "Video.h"
#import "constants.h"

@implementation TestValidation

+ (NSDictionary*)ValidateTestRecord:(TestRecord*)testRecord
{
    BOOL capillaryCheck = (testRecord.capillaryRecords.count == 2);
    
    BOOL videoErrorCheck = YES;
    BOOL videoCountCheck = YES;
    BOOL videoObjectCheck = YES;
    
    BOOL fieldVarianceCheck = YES;
    BOOL capillaryVarianceCheck = YES;
    BOOL focusFieldCountCheck = YES;
    BOOL fieldCountCheck = YES;
    
    int minimumFields = 5;
    
    NSString* videoErrorString = @"";
    
    NSMutableArray* capillaryCount = [[NSMutableArray alloc] init];
    
    NSInteger maxFields = [[[NSUserDefaults standardUserDefaults] objectForKey:FieldsOfViewKey] integerValue];
    for (CapillaryRecord* record in testRecord.capillaryRecords) {
        
        // Did we capture the correct number of fields
        if (record.videos.count != maxFields) {
            videoCountCheck = NO;
        }
        
        // Is the variance of the counts within necessary bounds?
        NSMutableArray* countArray = [[NSMutableArray alloc] init];
        for (Video* video in record.videos) {
            BOOL focusError = NO;
            BOOL bubbleError = NO;
            if (![video.errorString isEqualToString:@"None"]) {
                if ([video.errorString isEqualToString:@"FocusError"]) {
                    focusError = YES;
                }
                else if ([video.errorString isEqualToString:@"BubbleError"]) {
                    bubbleError = YES;
                }
                else {
                    videoErrorCheck = NO;
                    videoErrorString = video.errorString;
                }
            }
            if (video.averageObjectCount >= 0) {
                // Pass
            }
            else {
                videoObjectCheck = NO;
            }
            // If there is no focus error and no bubble error, use this data point
            if ((focusError == NO) && (bubbleError == NO)) {
                [countArray addObject:[NSNumber numberWithFloat:video.averageObjectCount.floatValue]];
            }
        }
        
        // How many in focus videos did we collect?
        NSLog(@"%d fields in focus and without bubbles", (int)countArray.count);
        if (countArray.count < minimumFields) {
            focusFieldCountCheck = NO;
        }
        
        // Clean any outliers from the array
        [self cleanOutliersFromArray:countArray];
        
        // Are there enough videos left to make a decision?
        if (countArray.count < minimumFields) {
            fieldCountCheck = NO;
        }
        
        // Check for variance of data results
        NSMutableDictionary* stats = [self statisticsFromArray:countArray];
        float mean = [[stats objectForKey:@"mean"] floatValue];
        float sigma = [[stats objectForKey:@"sigma"] floatValue];
        
        if (sigma > sqrtf(mean)) {
            fieldVarianceCheck = NO;
        }
        
        [capillaryCount addObject:[NSNumber numberWithFloat:mean]];
    }
    
    NSMutableDictionary* stats = [self statisticsFromArray:capillaryCount];
    float mean = [[stats objectForKey:@"mean"] floatValue];
    float sigma = [[stats objectForKey:@"sigma"] floatValue];
    if (sigma > sqrtf(mean)) {
        capillaryVarianceCheck = NO;
    }
    
    NSMutableDictionary* results = [[NSMutableDictionary alloc] init];
    
    if (focusFieldCountCheck && capillaryCheck && videoErrorCheck && videoObjectCheck && videoObjectCheck && fieldVarianceCheck && capillaryVarianceCheck) {
            [results setObject:@"Valid" forKey:@"Code"];
    }
    else {
        // Errors are arranged in preferential heiarchy. Final error overwrites previous ones.
        if (videoErrorCheck == NO) {
            NSLog(@"Validation detected a video error");
            NSString* code = [@"Invalid " stringByAppendingString:videoErrorString];
            [results setObject:code forKey:@"Code"];
        }
        if (fieldVarianceCheck == NO) {
            NSLog(@"Validation detected a field variance error");
            [results setObject:@"Invalid FieldVariance" forKey:@"Code"];
        }
        if (fieldCountCheck == NO) {
            NSLog(@"Insufficient fields to make a decision error");
            [results setObject:@"Invalid FieldCount" forKey:@"Code"];
        }
        if (capillaryVarianceCheck == NO) {
            NSLog(@"Validation detected a field variance error");
            [results setObject:@"Invalid CapillaryVariance" forKey:@"Code"];
        }
        if (focusFieldCountCheck == NO) {
            NSLog(@"Validation detected a field focus error");
            [results setObject:@"Invalid FieldFocusCount" forKey:@"Code"];
        }
    }
    
    return results;
}

+ (NSMutableDictionary*)statisticsFromArray:(NSMutableArray*)countArray
{
    // Check for variance of data results
    float sum = 0.0;
    for (NSNumber* number in countArray) {
        sum += number.floatValue;
    }
    float mean = sum/countArray.count;
    
    sum = 0.0;
    for (NSNumber* number in countArray) {
        float num = number.floatValue;
        sum += ((num-mean)*(num-mean));
    }
    float var = sum/countArray.count;
    float sigma = sqrtf(var);
    
    NSNumber* m = [NSNumber numberWithFloat:mean];
    NSNumber* v = [NSNumber numberWithFloat:var];
    NSNumber* s = [NSNumber numberWithFloat:sigma];

    NSMutableDictionary* results = [[NSMutableDictionary alloc]
                                    initWithObjectsAndKeys: m, @"mean", v, @"var", s, @"sigma", nil];
    return results;
}

// Returns YES if less than maxTrials outliers were cleared from the array. NO if too many outliers in array.
+ (void)cleanOutliersFromArray:(NSMutableArray*)countArray
{
    // Try to remove up to 2 outliers
    int trials = 0;
    int maxTrials = 2;
    
    // Hard coded validation parameters. I do not like this.
    float sigmaFactor = 1.75;
    
    while (trials < maxTrials) {
        // Check for variance of data results
        NSMutableDictionary* stats = [self statisticsFromArray:countArray];
        float mean = [[stats objectForKey:@"mean"] floatValue];
        float sigma = [[stats objectForKey:@"sigma"] floatValue];
        
        NSMutableArray* toRemove = [[NSMutableArray alloc] init];
        int i = 0;
        for (NSNumber* number in countArray) {
            float diff = mean - number.floatValue;
            if (fabs(diff) > sigmaFactor*sigma) {
                [toRemove addObject:number];
            }
            i += 1;
        }
        
        for (NSNumber* outlier in toRemove){
            [countArray removeObject:outlier];
        }

        trials += 1;
    }
}

// Method also stores results in CoreData objects
+ (NSDictionary*)ResultsFromTestRecord:(TestRecord*)testRecord
{
    NSNumber* capillaryVolume = [[NSUserDefaults standardUserDefaults] objectForKey:CapillaryVolumeKey];

    NSMutableArray* capillaryMeans = [[NSMutableArray alloc] init];
    for (CapillaryRecord* record in testRecord.capillaryRecords) {
        
        // Is the variance of the counts within necessary bounds?
        NSMutableArray* countArray = [[NSMutableArray alloc] init];

        for (Video* video in record.videos) {
            // Ignore any out of focus images when making the calculation
            if ([video.errorString isEqualToString:@"FocusError"]) {
                // Pass
            }
            else {
                [countArray addObject:[NSNumber numberWithFloat:video.averageObjectCount.floatValue]];
            }
        }
        // Clean any outliers from the array
        [self cleanOutliersFromArray:countArray];
        
        float sum = 0.0;
        for (NSNumber* number in countArray) {
            sum += number.floatValue;
        }
        float mean = sum/countArray.count;
        NSNumber* value = [NSNumber numberWithFloat:mean];
        
        // Store in CoreData
        record.objectsPerField = value;
        // Add the value to the list of capillary means
        [capillaryMeans addObject:value];
    }
    
    float capillarySum = 0.0;
    int capillaryCount = 0;
    for (NSNumber* cmean in capillaryMeans) {
        capillarySum += cmean.floatValue;
        capillaryCount += 1;
    }
    
    float objectsPerField = capillarySum/capillaryCount;
    
    float objectsPerMl = objectsPerField/capillaryVolume.floatValue;
    
    NSMutableDictionary* results = [[NSMutableDictionary alloc] init];
    [results setObject:[NSNumber numberWithFloat:objectsPerField] forKey:@"ObjectsPerField"];
    [results setObject:[NSNumber numberWithFloat:objectsPerMl] forKey:@"ObjectsPerMl"];
    [results setObject:testRecord.state forKey:@"state"];
    
    // Store in CoreData
    testRecord.objectsPerField = [NSNumber numberWithFloat:objectsPerField];
    testRecord.objectsPerMl = [NSNumber numberWithFloat:objectsPerMl];
    
    return results;
}


+ (NSDictionary*)ValidateTestRecordWithUUID:(NSString*)testUUID
{
    NSLog(@"Validate: %@", testUUID);
    return nil;
}

@end
