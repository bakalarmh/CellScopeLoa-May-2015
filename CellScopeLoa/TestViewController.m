//
//  TestViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/9/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "TestViewController.h"
#import <AdSupport/AdSupport.h>
#import "ValidResultsViewController.h"
#import "InvalidResultsViewController.h"
#import "BarcodeIDViewController.h"
#import "CapillaryRecord.h"
#import "TestValidation.h"
#import "Video.h"
#import "MotionObject.h"
#import "constants.h"

@interface TestViewController ()

@end

@implementation TestViewController {
    NSInteger fieldsAcquired;
    NSInteger fieldsProcessed;
    NSInteger capillariesAcquired;
    NSInteger capillariesProcessed;
    NSInteger maxFields;
    BOOL processingFinished;
    BOOL cameraSettling;
    
    NSMutableArray* activeVideos;
}

@synthesize managedObjectContext;
@synthesize cslContext;

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
    
    // Hard coded camera properties. Not happy about this.
    int width = 480;
    int height = 360;
    int maxFrames = 150;
    maxFields = [[[NSUserDefaults standardUserDefaults] objectForKey:FieldsOfViewKey] integerValue];
    
    // Do any additional setup after loading the view.
    [self.navigationItem setHidesBackButton:YES];
    [self.navigationController setNavigationBarHidden:NO];
    actionLabel.alpha = 0.2;
    
    // Listen for processing results
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveNotification:)
                                                 name:@"eventAnalysisComplete" object:nil];
    
    // Set up the new test and initialize properties
    if (newTest) {
        [self createActiveTest];
        newTest = NO;
        // Initialize the motion analysis object. Analysis object lives for the duration of the TestViewController
        MotionAnalysis* analysis = [[MotionAnalysis alloc] initWithWidth: width
                                                                  Height: height
                                                                  Frames: maxFrames
                                                                  VideoCount: maxFields];
        cslContext.motionAnalysis = analysis;
        processingFinished = NO;
    }
    else {
        // Return to existing test
        capillariesAcquired = cslContext.capillaryIndex.intValue;
        capillariesProcessed = cslContext.capillaryIndex.intValue;
        if (capillariesAcquired > 0) {
            capLabel1.text = @"Completed";
        }
        else if (capillariesAcquired > 1) {
            capLabel2.text = @"Completed";
        }
    }
    
    // Set up UI
    resultsButtonItem.enabled = NO;
    patientIDLabel.numberOfLines = 1;
    patientIDLabel.adjustsFontSizeToFitWidth = YES;
    patientIDLabel.text = patientNIHID;
    
    deviceIDLabel.text = [[NSUserDefaults standardUserDefaults] objectForKey:SimpleDeviceIDKey];
    cellscopeIDLabel.text = cslContext.activeTestRecord.simpleTestID;
}

- (void)viewDidAppear:(BOOL)animated
{
    // Wait for capture session to be available - to avoid crashes
    cameraSettling = YES;
    actionLabel.alpha = 0.2;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        cameraSettling = NO;
        actionLabel.alpha = 1.0;
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated
{
    // Save the CoreData state
    NSError* error;
}

-(void)receiveNotification:(NSNotification*)notification
{
    if ([notification.name isEqualToString:@"eventAnalysisComplete"])
    {
        NSDictionary* userInfo = notification.userInfo;
        
        NSString* errorString = (NSString*)userInfo[@"ErrorString"];
        NSString* resourceURL = (NSString*)userInfo[@"ResourceURL"];
        NSNumber* averageCount = (NSNumber*)userInfo[@"AverageCount"];
        NSNumber* focusMetric = (NSNumber*)userInfo[@"FocusMetric"];
        NSMutableArray* motionObjects = (NSMutableArray*)userInfo[@"MotionObjects"];
        
        // Check that the focus metric is within range
        float focusValue = focusMetric.floatValue;
        NSLog(@"FocusValue: %f", focusValue);
        NSString* focusStatus;
        if (focusValue < 0.2) {
            focusStatus = @"Bad";
        }
        else if (focusValue < 0.5) {
            focusStatus = @"Fair";
        }
        else if (focusValue >= 0.5) {
            focusStatus = @"Good";
        }
        else {
            focusStatus = @"Unknown";
        }
        
        if (errorString != nil) {
            if ([focusStatus isEqualToString:@"Bad"]) {
                errorString = [errorString stringByAppendingString:@" FocusError"];
            }
        }
        else {
            if ([focusStatus isEqualToString:@"Bad"]) {
                errorString = @"FocusError";
            }
        }
        
        if (errorString != nil) {
            NSLog(@"Processing detected Error: %@", errorString);
            // Store error with Video object
            Video* video = [self fetchVideoWithResourceURL:resourceURL];
            if (video != nil) {
                video.errorString = errorString;
            }
        }
        else {
            // Store results with Video object
            Video* video = [self fetchVideoWithResourceURL:resourceURL];
            video.errorString = @"None";
            if (video != nil) {
                video.averageObjectCount = averageCount;
                for (NSDictionary* m in motionObjects) {
                    /*
                    // Copy the motion object data into a new core data object
                    MotionObject* coreObject = (MotionObject*)[NSEntityDescription insertNewObjectForEntityForName:@"MotionObject"
                                                                                inManagedObjectContext:managedObjectContext];
                    coreObject.x = [m objectForKey:@"x"];
                    coreObject.y = [m objectForKey:@"y"];
                    coreObject.start = [m objectForKey:@"start"];
                    coreObject.start = [m objectForKey:@"end"];

                    [video addMotionObjectsObject:coreObject];
                     */
                }
            }
        }
        
        // How many fields have we processed, and what should we do next?
        fieldsProcessed += 1;
        
        if (fieldsProcessed == maxFields) {
            capillariesProcessed += 1;
            NSLog(@"%d Capillaries processed", (int)capillariesProcessed);
            if (capillariesProcessed == 2) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
                    processingFinished = YES;
                    actionLabel.text = @"Continue to results";
                    [self continueToResults];
                }];
            }
            else {
                fieldsProcessed = 0;
            }
        }

    }
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
    else if ([segue.identifier isEqualToString:@"ResultsValid"]) {
        ValidResultsViewController* vc = (ValidResultsViewController*)segue.destinationViewController;
        vc.cslContext = cslContext;
        vc.managedObjectContext = managedObjectContext;
        NSError* error;
        [managedObjectContext save:&error];
    }
    else if ([segue.identifier isEqualToString:@"ResultsInvalid"]) {
        InvalidResultsViewController* vc = (InvalidResultsViewController*)segue.destinationViewController;
        vc.cslContext = cslContext;
        NSError* error;
        [managedObjectContext save:&error];
    }
    else if ([segue.identifier isEqualToString:@"Abort"]) {
        // Stop any processing
        // [cslContext.motionAnalysis suspendProcessing];
        // Discard the new test object from the managed object context
        [managedObjectContext reset];
    }
}

- (void)createActiveTest
{
    // Create a new record in the managed object context
    TestRecord* activeTestRecord = [NSEntityDescription insertNewObjectForEntityForName:@"TestRecord" inManagedObjectContext: managedObjectContext];
    
    NSDictionary* currentDateTime = [self currentDateAndTime];

    // Set basic test record properties
    activeTestRecord.state = @"Incomplete";
    activeTestRecord.created = [currentDateTime objectForKey:@"Date"];
    activeTestRecord.localTimeZone = [currentDateTime objectForKey:@"LocalTimeZone"];
    activeTestRecord.boardUUID = cslContext.bleManager.lastUUID;
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
    NSNumber* capillaryIndex = [NSNumber numberWithInt:0];
    CapillaryRecord* capillaryRecord = [self generateCapillaryRecordWithIndex:capillaryIndex
                                                                   TestRecord:activeTestRecord];
    cslContext.activeCapillaryRecord = capillaryRecord;
    [activeTestRecord addCapillaryRecordsObject:capillaryRecord];
    
    cslContext.activeTestRecord = activeTestRecord;
    
    // Keep track of currently acquiring capillary, currently processing capillary, active videos
    cslContext.capillaryIndex = [NSNumber numberWithInt:0];
    cslContext.capillaryProcessingIndex = [NSNumber numberWithInt:0];
    
    activeVideos = [[NSMutableArray alloc] initWithCapacity:maxFields];
    
    fieldsAcquired = 0;
    fieldsProcessed = 0;
    capillariesAcquired = 0;
    capillariesProcessed = 0;
}

- (void)didCaptureVideoWithURL:(NSURL*)assetURL frameBuffer:(FrameBuffer *)buffer
{
    Video* video = [NSEntityDescription insertNewObjectForEntityForName:@"Video" inManagedObjectContext: managedObjectContext];
    
    // Set video properties
    // Generate a local path (relative to the documents directory)
    NSArray* pathComponents = assetURL.pathComponents;
    long count = pathComponents.count;
    NSArray* constantComponents = [pathComponents subarrayWithRange:NSMakeRange(8,count-8)];
    NSString* localPath = [constantComponents componentsJoinedByString:@"/"];
    
    video.resourceURL = localPath;
    video.created = [NSDate date];
    video.capillaryIndex = cslContext.activeCapillaryRecord.capillaryIndex;
    video.fieldIndex = [NSNumber numberWithInteger:fieldsAcquired];
    video.testUUID = cslContext.activeTestRecord.testUUID;
    [cslContext.activeCapillaryRecord addVideosObject:video];
    
    // Queue the video for processing by the motion analysis object
    [cslContext.motionAnalysis processFrameBuffer:buffer withResourceURL:video.resourceURL];
    
    // Increment the field of view counter
    fieldsAcquired += 1;
}

- (void)didCompleteCapillaryCapture
{
    int index = cslContext.capillaryIndex.intValue;
    NSNumber* capillaryIndex = [NSNumber numberWithInt:index+1];
    if (capillariesAcquired == 0) {
        CapillaryRecord* capillaryRecord = [self generateCapillaryRecordWithIndex:capillaryIndex
                                                                       TestRecord:cslContext.activeTestRecord];
        cslContext.activeCapillaryRecord = capillaryRecord;
        [cslContext.activeTestRecord addCapillaryRecordsObject:capillaryRecord];
        cslContext.capillaryIndex = capillaryIndex;
        
        capLabel1.text = @"Completed";
        fieldsAcquired = 0;
        capillariesAcquired += 1;
    }
    else if (capillariesAcquired == 1) {
        cslContext.activeCapillaryRecord = nil;
        cslContext.capillaryIndex = [NSNumber numberWithInt:index+1];
        
        capLabel2.text = @"Completed";
        fieldsAcquired = 0;
        
        if (capillariesProcessed == 2) {
            actionLabel.text = @"Continue to results";
            
        }
        else {
            actionLabel.text = @"Processing...";
            capillariesAcquired += 1;
        }
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // rows in section 0 should not be selectable
    if (indexPath.section == 2) {
        if ([actionLabel.text isEqualToString:@"Capture"]) {
            if (([cslContext deviceIsConnected]) && (cameraSettling == NO)) {
                return indexPath;
            }
            else {
                return nil;
            }
        }

    }
    // By default, allow row to be selected
    return indexPath;
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
        else if ([actionLabel.text isEqualToString:@"Continue to results"]) {
            [self continueToResults];
        }
        else {
            NSLog(@"Processing is not yet complete");
        }
    }
}

- (void)continueToResults
{
    // Validate the results of the test before loading the next view controller
    NSDictionary* results = [TestValidation ValidateTestRecord:cslContext.activeTestRecord];
    if ([[results objectForKey:@"Code"] isEqualToString:@"Valid"]) {
        cslContext.activeTestRecord.state = @"Valid";
        [self performSegueWithIdentifier:@"ResultsValid" sender:self];
    }
    else {
        cslContext.activeTestRecord.state = [results objectForKey:@"Code"];
        [self performSegueWithIdentifier:@"ResultsInvalid" sender:self];
    }
}

- (CapillaryRecord*)generateCapillaryRecordWithIndex:(NSNumber*)capillaryIndex TestRecord:(TestRecord*)testRecord
{
    NSDictionary* currentDateTime = [self currentDateAndTime];
    // Create a new capillary record for the test
    CapillaryRecord* capillaryRecord = [NSEntityDescription insertNewObjectForEntityForName:@"CapillaryRecord" inManagedObjectContext: managedObjectContext];
    capillaryRecord.created = [currentDateTime objectForKey:@"Date"];
    capillaryRecord.capillaryIndex = capillaryIndex;
    capillaryRecord.testUUID = testRecord.testUUID;
    return capillaryRecord;
}

- (NSDictionary*)currentDateAndTime
{
    NSDate* sourceDate = [NSDate date];
    NSString* localTimeZone = [[NSTimeZone systemTimeZone] abbreviation];
    
    NSDictionary* dateTime = [NSDictionary dictionaryWithObjectsAndKeys:
                              sourceDate, @"Date",
                              localTimeZone, @"LocalTimeZone", nil];
    return dateTime;
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

// Location manager delegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation* location = [locations lastObject];
    NSDate* eventDate = location.timestamp;
    NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
    if (fabs(howRecent) < 15.0) {
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

#pragma mark - CoreData helpers

- (Video*)fetchVideoWithResourceURL:(NSString*)resourceURL
{
    Video* video;
    
    // Save a new video object in CoreData
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Video" inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];
    
    // Retrive the objects with a given value for a certain property
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"resourceURL == %@", resourceURL];
    [request setPredicate:predicate];
    NSError *error = nil;
    NSArray *result = [managedObjectContext executeFetchRequest:request error:&error];
    
    // Create the Video object if it does not already exist
    if ((result != nil) && (result.count == 1) && (error == nil)){
        video = [result objectAtIndex:0];
        return video;
    }
    else {
        NSLog(@"Cannot find video!!!!");
        return nil;
    }
}

@end
