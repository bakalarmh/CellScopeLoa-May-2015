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

@interface TestRecordViewController ()

@end

@implementation TestRecordViewController {
    float numSeconds;
    CapillaryRecord* activeCapillaryRecord;
}

@synthesize testRecord;
@synthesize mffieldLabel;
@synthesize mfmlLabel;
@synthesize capillaryOneDataLabel;
@synthesize capillaryTwoDataLabel;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Hard coded video seconds. I am not happy with this.
    numSeconds = 5.0;
    
    NSNumberFormatter *formatter = [NSNumberFormatter new];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setMaximumFractionDigits:0];
    NSString* mfmlString = [formatter stringFromNumber:testRecord.objectsPerMl];
    
    mffieldLabel.text = [NSString stringWithFormat:@"%.2f mf/field", testRecord.objectsPerField.floatValue];
    mfmlLabel.text = [NSString stringWithFormat:@"%@ mf/ml", mfmlString];
    
    int i = 0;
    for (CapillaryRecord* record in testRecord.capillaryRecords) {
        NSString* string = @"";
        for (Video* video in record.videos) {
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
        Video* testVideo = [[activeCapillaryRecord.videos objectEnumerator] nextObject];
        VideosViewController* vc = (VideosViewController*)segue.destinationViewController;
        vc.video = testVideo;
    }
}

- (IBAction)videoButtonOnePressed:(id)sender {
    activeCapillaryRecord = [[testRecord.capillaryRecords objectEnumerator] nextObject];
    [self performSegueWithIdentifier:@"ShowVideos" sender:self];
}

- (IBAction)videoButtonTwoPressed:(id)sender {
    activeCapillaryRecord = [[testRecord.capillaryRecords objectEnumerator] nextObject];
    [self performSegueWithIdentifier:@"ShowVideos" sender:self];
}

@end
