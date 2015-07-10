//
//  TestRecordViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/31/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "TestRecordViewController.h"
#import "CapillaryRecord.h"
#import "Video.h"
#import "MotionObject.h"
#import "VideosViewController.h"
#import "TestValidation.h"
#import "constants.h"

@interface TestRecordViewController () {
    NSMutableArray* orderedCapillaryRecords;
}

@end

@implementation TestRecordViewController {
    float numSeconds;
    CapillaryRecord* activeCapillaryRecord;
    BOOL twoCapillariesRequired;
}

@synthesize testRecord;
@synthesize resultCardView;
@synthesize mffieldLabel;
@synthesize mfmlLabel;
@synthesize capillaryOneDataLabel;
@synthesize capillaryTwoDataLabel;
@synthesize videosButton1;
@synthesize videosButton2;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Hard coded video seconds. I am not happy with this.
    numSeconds = 5.0;
    
    // Acquire one or two capillaries?
    twoCapillariesRequired = [[[NSUserDefaults standardUserDefaults] objectForKey:RequireTwoCapillariesKey] boolValue];
    
    NSNumberFormatter *formatter = [NSNumberFormatter new];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setMaximumFractionDigits:0];
    NSString* mfmlString = [formatter stringFromNumber:testRecord.objectsPerMl];
    
    mffieldLabel.text = [NSString stringWithFormat:@"%.2f mf/field", testRecord.objectsPerField.floatValue];
    mfmlLabel.text = [NSString stringWithFormat:@"%@ mf/ml", mfmlString];
    
    orderedCapillaryRecords = [[NSMutableArray alloc] init];
    
    BOOL videosAvailable = YES;
    
    int i = 0;
    for (CapillaryRecord* record in testRecord.capillaryRecords) {
        [orderedCapillaryRecords addObject:record];
        NSString* string = @"";
        for (Video* video in record.videos) {
            if (video.videoDeleted.boolValue == YES) {
                videosAvailable = NO;
            }
            float count = video.averageObjectCount.floatValue;
            string = [string stringByAppendingFormat:@"%.1f, ",count];
        }
        string = [string substringToIndex:string.length - 2];
        if (i == 0) {
            capillaryOneDataLabel.text = string;
        }
        else {
            capillaryTwoDataLabel.text = string;
        }
        i += 1;
    }
    
    // Color the result card
    if ([testRecord.state rangeOfString:@"Invalid"].location != NSNotFound) {
        resultCardView.backgroundColor = [UIColor blackColor];
        mfmlLabel.text = @"Invalid";
        mffieldLabel.text = @"";
    }
    else {
        if (testRecord.objectsPerMl.floatValue < 10000) {
            resultCardView.backgroundColor = [UIColor greenColor];
        }
        else if (testRecord.objectsPerMl.floatValue < 23000) {
            resultCardView.backgroundColor = [UIColor yellowColor];
        }
        else {
            resultCardView.backgroundColor = [UIColor redColor];
        }
    }
    
    if (videosAvailable == NO) {
        videosButton1.enabled = NO;
        videosButton2.enabled = NO;
    }
    else {
        videosButton1.enabled = YES;
        videosButton2.enabled = YES;
    }
    
    if (testRecord.capillaryRecords.count == 1) {
        videosButton2.enabled = NO;
        capillaryTwoDataLabel.text = @"";
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"ShowVideos"]) {
        VideosViewController* vc = (VideosViewController*)segue.destinationViewController;
        vc.videos = activeCapillaryRecord.videos;
    }
}

- (IBAction)videoButtonOnePressed:(id)sender {
    activeCapillaryRecord = [orderedCapillaryRecords objectAtIndex:0];
    [self performSegueWithIdentifier:@"ShowVideos" sender:self];
}

- (IBAction)videoButtonTwoPressed:(id)sender {
    activeCapillaryRecord = [orderedCapillaryRecords objectAtIndex:1];
    [self performSegueWithIdentifier:@"ShowVideos" sender:self];
}

@end
