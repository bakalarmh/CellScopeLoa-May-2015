//
//  InvalidResultsViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/17/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "InvalidResultsViewController.h"
#import "TestValidation.h"
#import "Video.h"
#import "CapillaryRecord.h"

@interface InvalidResultsViewController ()

@end

@implementation InvalidResultsViewController

@synthesize cslContext;
@synthesize testResultLabel;
@synthesize errorMessageLabel;
@synthesize countsLabel1;
@synthesize countsLabel2;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    TestRecord* testRecord = cslContext.activeTestRecord;
    
    [self.navigationItem setHidesBackButton:YES];
    NSDictionary* testResults = [TestValidation ResultsFromTestRecord:testRecord];
    
    NSString* state = [testResults objectForKey:@"state"];
    if ([state rangeOfString:@"FieldFocusCount"].location != NSNotFound) {
        // Are there bubbles in the field?
        if ([state rangeOfString:@"BubbleCount"].location != NSNotFound) {
            testResultLabel.text = NSLocalizedString(@"Blood fill Error",nil);
            errorMessageLabel.text = NSLocalizedString(@"Bubbles are in the capillary or blood has coagulated.",nil);
        }
        else if ([state rangeOfString:@"Flow"].location != NSNotFound) {
            testResultLabel.text = NSLocalizedString(@"Flow Error",nil);
            errorMessageLabel.text = NSLocalizedString(@"There is blood flow within the capillary.",nil);
        }
        else {
            testResultLabel.text = NSLocalizedString(@"Focus Error",nil);
            errorMessageLabel.text = NSLocalizedString(@"Images are not in focus.",nil);
        }
    }
    else if ([state rangeOfString:@"FieldCount"].location != NSNotFound) {
        testResultLabel.text = NSLocalizedString(@"Insuffient data",nil);
        errorMessageLabel.text = NSLocalizedString(@"Low quality fields of view.",nil);
    }
    else if ([state rangeOfString:@"BubbleError"].location != NSNotFound) {
        testResultLabel.text = NSLocalizedString(@"Bubble Error",nil);
        errorMessageLabel.text = NSLocalizedString(@"There are bubbles in the capillary.",nil);
    }
    else if ([state rangeOfString:@"FieldVariance"].location != NSNotFound) {
        testResultLabel.text = NSLocalizedString(@"Test result is invalid",nil);
        errorMessageLabel.text = NSLocalizedString(@"High field of view variance",nil);
    }
    else if ([state rangeOfString:@"CapillaryVariance"].location != NSNotFound) {
        testResultLabel.text = NSLocalizedString(@"Test result is invalid",nil);
        errorMessageLabel.text = NSLocalizedString(@"High capillary to capillary variance",nil);
    }
    else {
        NSLog(@"Undocumented error: %@", state);
    }
    
    int i = 0;
    for (CapillaryRecord* record in testRecord.capillaryRecords) {
        NSString* string = @"";
        for (Video* video in record.videos) {
            float count = video.averageObjectCount.floatValue;
            string = [string stringByAppendingFormat:@"%.1f, ",count];
        }
        string = [string substringToIndex:string.length - 2];
        if (i == 0) {
            countsLabel1.text = string;
        }
        else {
            countsLabel2.text = string;
        }
        i += 1;
    }
    
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

- (IBAction)finishedPressed:(id)sender {
    [self performSegueWithIdentifier:@"ReturnToMenu" sender:self];
}

@end
