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

+ (NSDictionary*)ValidateTestRecord:(TestRecord*)testRecord
{
    BOOL videoErrorCheck = YES;
    BOOL videoCountCheck = YES;
    BOOL videoObjectCheck = YES;
    
    BOOL fieldVarianceCheck = YES;
    BOOL capillaryVarianceCheck = YES;
    BOOL validFieldCountCheck = YES;
    BOOL fieldCountCheck = YES;
    BOOL bubbleCheck = YES;
    BOOL flowCheck = YES;
    
    int minimumFields = 5;
    
    // Acquire one or two capillaries?
    BOOL twoCapillariesRequired = [[[NSUserDefaults standardUserDefaults] objectForKey:RequireTwoCapillariesKey] boolValue];
    BOOL capillaryCheck;
    if (twoCapillariesRequired) {
        capillaryCheck = (testRecord.capillaryRecords.count == 2);
    }
    else {
        capillaryCheck = (testRecord.capillaryRecords.count == 1);
    }
    
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
            BOOL flowError = NO;
            NSString* errorString = video.errorString;
            if (![errorString isEqualToString:@"None"]) {
                if ([errorString rangeOfString:@"FocusError"].location != NSNotFound) {
                    focusError = YES;
                }
                if ([errorString rangeOfString:@"BubbleError"].location != NSNotFound) {
                    bubbleError = YES;
                }
                if ([errorString rangeOfString:@"FlowError"].location != NSNotFound) {
                    flowError = YES;
                }
                if (!focusError && !bubbleError && !flowError) {
                    videoErrorCheck = NO;
                    videoErrorString = video.errorString;
                }
            }
            
            // If there is no focus error and no bubble error and no flow error, use this data point
            if ((focusError == NO) && (bubbleError == NO) && (flowError == NO)) {
                [countArray addObject:[NSNumber numberWithFloat:video.averageObjectCount.floatValue]];
            }
            else {
                if (flowError == YES) {
                    flowCheck = NO;
                }
                if (bubbleError == YES) {
                    bubbleCheck = NO;
                }
            }
        }
        
        // How many in focus videos did we collect?
        NSLog(@"%d fields in focus and without bubbles", (int)countArray.count);
        if (countArray.count < minimumFields) {
            validFieldCountCheck = NO;
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
    
    if (twoCapillariesRequired == YES) {
        NSMutableDictionary* stats = [self statisticsFromArray:capillaryCount];
        float mean = [[stats objectForKey:@"mean"] floatValue];
        float sigma = [[stats objectForKey:@"sigma"] floatValue];
        if (sigma > sqrtf(mean)) {
            capillaryVarianceCheck = NO;
        }
    }
    
    NSMutableDictionary* results = [[NSMutableDictionary alloc] init];
    
    if (validFieldCountCheck && capillaryCheck && videoErrorCheck && videoObjectCheck && videoObjectCheck && fieldVarianceCheck) {
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
        // Do not run a capillary variance check
        /*
        if (capillaryVarianceCheck == NO) {
            NSLog(@"Validation detected a field variance error");
            [results setObject:@"Invalid CapillaryVariance" forKey:@"Code"];
        }
         */
        if (validFieldCountCheck == NO) {
            NSString* errorCode = @"Invalid";
            if (flowCheck == NO) {
                NSLog(@"Validation detected a flow error");
                errorCode = [errorCode stringByAppendingString:@" Flow"];
            }
            if (bubbleCheck == NO) {
                NSLog(@"Validation detected a field focus or bubble error");
                errorCode = [errorCode stringByAppendingString:@" BubbleCount"];
            }
            errorCode = [errorCode stringByAppendingString:@" FieldFocusCount"];
            [results setObject:errorCode forKey:@"Code"];
        }
    }
    
    return results;
}

// Method also stores results in CoreData objects
+ (NSDictionary*)ResultsFromTestRecord:(TestRecord*)testRecord
{
    NSNumber* capillaryVolume = [[NSUserDefaults standardUserDefaults] objectForKey:CapillaryVolumeKey];
    NSNumber* goldMultiplier = [[NSUserDefaults standardUserDefaults] objectForKey:GoldMultiplierKey];

    NSMutableArray* capillaryMeans = [[NSMutableArray alloc] init];
    for (CapillaryRecord* record in testRecord.capillaryRecords) {
        
        // Is the variance of the counts within necessary bounds?
        NSMutableArray* countArray = [[NSMutableArray alloc] init];

        for (Video* video in record.videos) {
            BOOL focusError = NO;
            BOOL bubbleError = NO;
            BOOL flowError = NO;
            NSString* errorString = video.errorString;
            if (![errorString isEqualToString:@"None"]) {
                if ([errorString rangeOfString:@"FocusError"].location != NSNotFound) {
                    focusError = YES;
                }
                if ([errorString rangeOfString:@"BubbleError"].location != NSNotFound) {
                    bubbleError = YES;
                }
                if ([errorString rangeOfString:@"FlowError"].location != NSNotFound) {
                    flowError = YES;
                }
            }
            
            // If there is no focus error and no bubble error and no flow error, use this data point
            if ((focusError == NO) && (bubbleError == NO) && (flowError == NO)) {
                [countArray addObject:[NSNumber numberWithFloat:video.averageObjectCount.floatValue]];
            }
        }
        // Clean any outliers from the array
        [self cleanOutliersFromArray:countArray];
        NSLog(@"%d fields used to compute mean", (int)countArray.count);
        
        float sum = 0.0;
        for (NSNumber* number in countArray) {
            sum += number.floatValue;
        }
        float mean = sum/countArray.count;
        NSNumber* value = [NSNumber numberWithFloat:mean];
        
        // Store in CoreData
        record.objectsPerField = value;
        
        // Compute objectsPerMl
        float objectsPerMl = (value.floatValue/capillaryVolume.floatValue)*goldMultiplier.floatValue;
        record.objectsPerMl = [NSNumber numberWithFloat:objectsPerMl];
        
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
    
    float objectsPerMl = (objectsPerField/capillaryVolume.floatValue)*goldMultiplier.floatValue;
    
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
