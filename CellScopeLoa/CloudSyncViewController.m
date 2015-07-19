//
//  CloudSyncViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/17/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "CloudSyncViewController.h"
#import "TestRecord.h"
#import "ParseDataAdaptor.h"
#import "Video.h"

@interface CloudSyncViewController ()

@end

@implementation CloudSyncViewController {
    int testRecordCount;
    int testRecordSyncCount;
    int capillaryRecordCount;
    int capillaryRecordSyncCount;
    int videoCount;
    int videoSyncCount;
    
    int counter;
    int target;
}

@synthesize managedObjectContext;
@synthesize cslContext;

@synthesize dataReportLabel;
@synthesize testRecordsLabel;
@synthesize capillaryRecordsLabel;
@synthesize videosLabel;
@synthesize syncVideosSwitch;
@synthesize videosProgressView;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    videosProgressView.alpha = 0.0;
    [self performDataCensus];
    [self updateSyncReport];
    syncVideosSwitch.on = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateSyncReport
{
    testRecordsLabel.text = [NSString stringWithFormat:@"%d/%d", testRecordSyncCount, testRecordCount];
    capillaryRecordsLabel.text = [NSString stringWithFormat:@"%d/%d", capillaryRecordSyncCount, capillaryRecordCount];
    videosLabel.text = [NSString stringWithFormat:@"%d/%d", videoSyncCount, videoCount];
}

- (void)performDataCensus
{
    // Sync test records
    NSError *error;
    
    NSString *sortKey = @"created";
    NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sortKey ascending:NO];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    // Query all TestRecords from CoreData
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"TestRecord"
                                              inManagedObjectContext:managedObjectContext];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [fetchRequest setEntity:entity];
    NSArray *fetchedObjects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    testRecordCount = (int)fetchedObjects.count;
    testRecordSyncCount = 0;
    for (TestRecord* record in fetchedObjects) {
        if (record.parseID != nil) {
            testRecordSyncCount += 1;
        }
    }
    
    // Query capillary records
    sortKey = @"created";
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sortKey ascending:NO];
    fetchRequest = [[NSFetchRequest alloc] init];
    
    // Query all TestRecords from CoreData
    entity = [NSEntityDescription entityForName:@"CapillaryRecord"
                         inManagedObjectContext:managedObjectContext];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [fetchRequest setEntity:entity];
    fetchedObjects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    capillaryRecordCount = (int)fetchedObjects.count;
    capillaryRecordSyncCount = 0;
    // Store the basic data for each capillary record
    for (CapillaryRecord* record in fetchedObjects) {
        if (record.parseID != nil) {
            capillaryRecordSyncCount += 1;
        }
    }
    
    videoCount = 0;
    videoSyncCount = 0;
    // Store the videos for each capillary record
    for (CapillaryRecord* record in fetchedObjects) {
        videoCount += (int)record.videos.count;
        for (Video* video in record.videos) {
            if (video.parseID != nil) {
                videoSyncCount += 1;
            }
        }
    }
}

- (IBAction)syncButtonPressed:(id)sender {
    
    // Sync test records
    NSError *error;
    
    NSString *sortKey = @"created";
    NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sortKey ascending:NO];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    // Query all TestRecords from CoreData
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"TestRecord"
                                              inManagedObjectContext:managedObjectContext];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [fetchRequest setEntity:entity];
    NSArray *fetchedObjects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    for (TestRecord* record in fetchedObjects) {
        if (record.parseID == nil) {
            [ParseDataAdaptor syncTestRecord:record WithBlock:^(BOOL succeeded, NSError *error) {
                if (succeeded) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
                        // Save record back in managed object context
                        [managedObjectContext save:nil];
                        testRecordSyncCount += 1;
                        [self updateSyncReport];
                    }];
                }
                else {
                    NSLog(@"Parse error: %@", error.description);
                }
            }];
        }
    }
    
    // Sync capillary records
    sortKey = @"created";
    sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sortKey ascending:NO];
    fetchRequest = [[NSFetchRequest alloc] init];
    
    // Query all TestRecords from CoreData
    entity = [NSEntityDescription entityForName:@"CapillaryRecord"
                                              inManagedObjectContext:managedObjectContext];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [fetchRequest setEntity:entity];
    fetchedObjects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    // Store the basic data for each capillary record
    for (CapillaryRecord* record in fetchedObjects) {
        if (record.parseID == nil) {
            [ParseDataAdaptor syncCapillaryRecord:record WithBlock:^(BOOL succeeded, NSError *error) {
                if (succeeded) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
                        // Save record back in managed object context
                        [managedObjectContext save:nil];
                        capillaryRecordSyncCount += 1;
                        [self updateSyncReport];
                    }];
                }
                else {
                    NSLog(@"Parse error: %@", error.description);
                }
            }];
        }
    }
    
    // Store the videos for each capillary record
    if (syncVideosSwitch.on == YES) {
        for (CapillaryRecord* record in fetchedObjects) {
            counter = 0;
            target = videoCount-videoSyncCount;
            [ParseDataAdaptor syncVideosForCapillaryRecord:record withBlock:^(BOOL succeeded, NSError *error) {
                if (succeeded) {
                    counter += 1;
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
                        
                        // Save record back in managed object context
                        [managedObjectContext save:nil];
                        videoSyncCount += 1;
                        [self updateSyncReport];
                    }];
                }
                else {
                    NSLog(@"Parse error: %@", error.description);
                }
            }];
        }
    }

}


@end
