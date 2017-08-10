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
#import "DynamoDataAdaptor.h"
#import "Video.h"

@interface CloudSyncViewController ()

@end

@implementation CloudSyncViewController {
    int testRecordCount;
    int testRecordSyncCount;
    int videoCount;
    int videoSyncCount;
    
    int counter;
    int target;
}

@synthesize managedObjectContext;
@synthesize cslContext;

@synthesize dataReportLabel;
@synthesize testRecordsLabel;
@synthesize videosLabel;
@synthesize syncVideosSwitch;
@synthesize resyncSwitch;
@synthesize videosProgressView;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    videosProgressView.alpha = 0.0;
    [self performDataCensus];
    [self updateSyncReport];
    syncVideosSwitch.on = YES;
    resyncSwitch.on = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateSyncReport
{
    testRecordsLabel.text = [NSString stringWithFormat:@"%d/%d", testRecordSyncCount, testRecordCount];
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
    
    // Query all Capillary Records from CoreData
    entity = [NSEntityDescription entityForName:@"CapillaryRecord"
                         inManagedObjectContext:managedObjectContext];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [fetchRequest setEntity:entity];
    fetchedObjects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    videoCount = 0;
    videoSyncCount = 0;
    // Store the videos for each capillary record
    for (CapillaryRecord* record in fetchedObjects) {
        for (Video* video in record.videos) {
            if (video.deleted == FALSE) {
                videoCount += 1;
                if (video.parseID != nil) {
                    videoSyncCount += 1;
                }
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
    
    NSMutableArray* recordsToSync = [[NSMutableArray alloc] init];
    
    if (resyncSwitch.on) {
        testRecordSyncCount = 0;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
            testRecordSyncCount = 0;
            [self updateSyncReport];
        }];

    }
    // Sync test records
    for (TestRecord* record in fetchedObjects) {
        // Add record if it hasn't been synced
        if (resyncSwitch.on == NO) {
            if (record.parseID == nil) {
                [recordsToSync addObject:record];
            }
        }
        // Add all records, regardless of sync state
        else {
            [recordsToSync addObject:record];
        }
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        for (TestRecord* record in recordsToSync) {
            [DynamoDataAdaptor syncTestRecord:record WithBlock:^(BOOL succeeded, NSError *error) {
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

    });
    
    // Query all CapillaryRecords from CoreData
    entity = [NSEntityDescription entityForName:@"CapillaryRecord"
                                              inManagedObjectContext:managedObjectContext];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [fetchRequest setEntity:entity];
    fetchedObjects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    recordsToSync = [[NSMutableArray alloc] init];
    
    for (CapillaryRecord* record in fetchedObjects) {
        if (resyncSwitch.on == NO) {
            // Add the record if all of its videos have not been synced
            bool add = NO;
            for (Video* video in record.videos) {
                if (video.parseID == nil) {
                    add = YES;
                }
            }
            if (add) {
                [recordsToSync addObject:record];
            }
        }
        else {
            // Add all records to the sync queue
            [recordsToSync addObject:record];
        }
    }

    if (resyncSwitch.on) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
            videoSyncCount = 0;
            [self updateSyncReport];
        }];
    }
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [DynamoDataAdaptor syncVideosForCapillaryRecords:recordsToSync withBlock:^(BOOL succeeded, NSError *error) {
            if (succeeded) {
                counter += 1;
                [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
                    // Save record back in managed object context
                    [managedObjectContext save:nil];
                    videoSyncCount += 1;
                    [self updateSyncReport];
                }];
            }
        }];
    });
}


@end
