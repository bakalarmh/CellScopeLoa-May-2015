//
//  TestViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/9/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "TestViewController.h"
#import <AdSupport/AdSupport.h>
#import "BarcodeIDViewController.h"
#import "CapillaryRecord.h"
#import "Video.h"
#import "constants.h"

@interface TestViewController ()

@end

@implementation TestViewController

@synthesize managedObjectContext;
@synthesize cslContext;

@synthesize bleManager;
@synthesize patientNIHID;
@synthesize testNIHID;

// UI Objects
@synthesize resultsButtonItem;
@synthesize patientIDLabel;
@synthesize deviceIDLabel;
@synthesize cellscopeIDLabel;
@synthesize capLabel1;
@synthesize capLabel2;
@synthesize actionLabel;

@synthesize newTest;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.navigationItem setHidesBackButton:YES];
    [self.navigationController setNavigationBarHidden:NO];
    
    // Set up the new test and initialize properties
    if (newTest) {
        [self createActiveTest];
        newTest = NO;
    }
    else {
        // Return to existing test
    }
    
    // Set up UI
    resultsButtonItem.enabled = NO;
    patientIDLabel.numberOfLines = 1;
    patientIDLabel.adjustsFontSizeToFitWidth = YES;
    patientIDLabel.text = patientNIHID;
    
    deviceIDLabel.text = [[NSUserDefaults standardUserDefaults] objectForKey:SimpleDeviceIDKey];
    cellscopeIDLabel.text = cslContext.activeTestRecord.simpleTestID;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated
{
    // Save the CoreData state
    NSError* error;
    [managedObjectContext save:&error];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"newBarcodeID"]) {
        BarcodeIDViewController* vc = (BarcodeIDViewController*)segue.destinationViewController;
        vc.recaptureID = YES;
    }
    else if ([segue.identifier isEqualToString:@"Capture"]) {
        CaptureViewController* vc = (CaptureViewController*)segue.destinationViewController;
        vc.delegate = self;
        vc.cslContext = cslContext;
    }
}

- (void)createActiveTest
{
    // Create a new record in the managed object context
    TestRecord* activeTestRecord = [NSEntityDescription insertNewObjectForEntityForName:@"TestRecord" inManagedObjectContext: managedObjectContext];
    
    NSDate* sourceDate = [NSDate date];

    NSTimeZone* sourceTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    NSTimeZone* destinationTimeZone = [NSTimeZone systemTimeZone];
    
    NSInteger sourceGMTOffset = [sourceTimeZone secondsFromGMTForDate:sourceDate];
    NSInteger destinationGMTOffset = [destinationTimeZone secondsFromGMTForDate:sourceDate];
    NSTimeInterval interval = destinationGMTOffset - sourceGMTOffset;
    
    NSDate* destinationDate = [[NSDate alloc] initWithTimeInterval:interval sinceDate:sourceDate];

    // Set basic test record properties
    activeTestRecord.state = @"Incomplete";
    activeTestRecord.createdGMT = sourceDate;
    activeTestRecord.createdLocalTime = destinationDate;
    activeTestRecord.boardUUID = bleManager.lastUUID;
    activeTestRecord.patientNIHID = patientNIHID;
    activeTestRecord.testNIHID = testNIHID;
    activeTestRecord.testUUID = [[NSUUID UUID] UUIDString];
    activeTestRecord.phoneIdentifier = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    activeTestRecord.simplePhoneID = [[NSUserDefaults standardUserDefaults] objectForKey:SimplePhoneIDKey];
    activeTestRecord.deviceID = [[NSUserDefaults standardUserDefaults] objectForKey:SimpleDeviceIDKey];
    
    // Get a psuedo-unique CSLID
    NSString* CSLID = [cslContext generateSimpleCSLIDWithRecord:activeTestRecord];
    activeTestRecord.simpleTestID = CSLID;
    
    // Add location to the test record
    cslContext.locationManager.delegate = self;
    [cslContext startLocationUpdates];
    
    // Create a new capillary record for the test
    CapillaryRecord* capillaryRecord = [NSEntityDescription insertNewObjectForEntityForName:@"CapillaryRecord" inManagedObjectContext: managedObjectContext];
    capillaryRecord.createdGMT = sourceDate;
    capillaryRecord.createdLocal = destinationDate;
    capillaryRecord.capillaryIndex = [NSNumber numberWithInt:0];
    capillaryRecord.testUUID = activeTestRecord.testUUID;
    
    cslContext.activeCapillaryRecord = capillaryRecord;
    [activeTestRecord addCapillaryRecordsObject:capillaryRecord];
    cslContext.activeTestRecord = activeTestRecord;
    cslContext.capillaryIndex = [NSNumber numberWithInt:0];
}

// Location manager delegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation* location = [locations lastObject];
    NSDate* eventDate = location.timestamp;
    NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
    if (abs(howRecent) < 15.0) {
        // If the event is recent, handle it.
        [manager stopUpdatingLocation];
        cslContext.activeTestRecord.latitude = [NSNumber numberWithDouble:location.coordinate.latitude];
        cslContext.activeTestRecord.longitude = [NSNumber numberWithDouble:location.coordinate.longitude];
    }
}

- (IBAction)cancelPushed:(id)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Abort test?"
                                                    message:@"All results from this test will be discarded."
                                                   delegate:nil
                                          cancelButtonTitle:@"Abort"
                                          otherButtonTitles:@"No",nil];
    alert.delegate = self;
    [alert show];
}

- (void)didCaptureVideoWithURL:(NSURL*)assetURL
{
    // Save a new video object in CoreData
    Video* video = [NSEntityDescription insertNewObjectForEntityForName:@"Video" inManagedObjectContext: managedObjectContext];
    video.resourceURL = assetURL.absoluteString;
    video.created = [NSDate date];
    [cslContext.activeCapillaryRecord addVideosObject:video];
}

- (void)didCompleteCapture
{
    int capidx = cslContext.capillaryIndex.intValue;
    if (capidx == 0) {
        cslContext.capillaryIndex = [NSNumber numberWithInt:capidx+1];
        capLabel1.text = @"Completed";
        NSLog(@"First capillary collected");
    }
    else if (capidx == 1) {
        cslContext.capillaryIndex = [NSNumber numberWithInt:capidx+1];
        capLabel2.text = @"Completed";
        NSLog(@"Final capillary collected");
        
        resultsButtonItem.enabled = YES;
        actionLabel.text = @"Continue to results";
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    else if (indexPath.section == 1) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    else if (indexPath.section == 2) {
        if ([actionLabel.text isEqualToString:@"Capture"]) {
            [self performSegueWithIdentifier:@"Capture" sender:self];
        }
        else {
            [self performSegueWithIdentifier:@"ShowResults" sender:self];
        }
        
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        [self performSegueWithIdentifier:@"Abort" sender:self];
    }
}

- (IBAction)capturePushed:(id)sender {
    [self performSegueWithIdentifier:@"Capture" sender:self];
}

- (IBAction)changeIDPushed:(id)sender {
    [self performSegueWithIdentifier:@"newBarcodeID" sender:self];
}

@end
