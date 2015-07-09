//
//  DiskSpaceManager.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 6/30/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "DiskSpaceManager.h"
#import "LoaAppDelegate.h"
#import "TestRecord.h"
#import "CapillaryRecord.h"
#import "Video.h"

@implementation DiskSpaceManager

// Delete videos from old records
+ (void)ManageDiskSpace:(NSManagedObjectContext*)managedObjectContext;
{
    // Trigger a disk clean when 1 GB is remaining
    uint64_t lowSpaceTrigger = 1000ll;
    
    uint64_t totalFreeSpace = [LoaAppDelegate FreeDiskSpace];
    uint64_t freeMB = ((totalFreeSpace/1024ll)/1024ll);
    if (freeMB < lowSpaceTrigger) {
        NSInteger days = 7;
        NSMutableArray* videoTrashBin = [self findVideosToDelete:managedObjectContext daysOld:days];
        if (videoTrashBin.count == 0) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Out of Space" message:@"Disk space is low. Sync files to the cloud" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
        
        for (Video* video in videoTrashBin) {
            [self deleteVideoFile:video withContext:managedObjectContext];
        }
    }
}

// Delete uncompressed videos from old records
+ (void)ManageUncompressedVideos:(NSManagedObjectContext*)managedObjectContext;
{
    NSInteger days = 7;
    NSMutableArray* videoTrashBin = [self findUncompressedVideosToDelete:managedObjectContext daysOld:days];
    if (videoTrashBin.count == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Could not find uncompressed videos to delete. If necessary, sync files to the cloud" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
    
    for (Video* video in videoTrashBin) {
        [self deleteVideoFile:video withContext:managedObjectContext];
    }
}

+ (NSNumber*)FreeDiskSpace
{
    uint64_t totalFreeSpace = [LoaAppDelegate FreeDiskSpace];
    uint64_t freeMB = ((totalFreeSpace/1024ll)/1024ll);
    NSNumber* freeSpace = [NSNumber numberWithLongLong:freeMB];
    return freeSpace;
}

+ (NSMutableArray*)findVideosToDelete:(NSManagedObjectContext*)managedObjectContext daysOld:(NSInteger)days
{
    NSInteger count = 0;
    NSArray* testRecords;
    while ((count == 0) && (days >= 1)) {
        // Select records that were created more than N days ago
        NSDate *today = [NSDate date];
        NSDate *lastWeek = [today dateByAddingTimeInterval:-days*24*60*60];
        
        NSError *error;
        
        NSString *sortKey = @"created";
        NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sortKey ascending:NO];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"(created < %@)", lastWeek];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"TestRecord"
                                                  inManagedObjectContext:managedObjectContext];
        [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
        [fetchRequest setEntity:entity];
        testRecords = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
        
        count = 0;
        for (TestRecord* testRecord in testRecords) {
            BOOL cleaned = YES;
            for (CapillaryRecord* capillaryRecord in testRecord.capillaryRecords) {
                for (Video* video in capillaryRecord.videos) {
                    if (video.videoDeleted.boolValue == NO) {
                        cleaned = NO;
                    }
                }
            }
            if (cleaned == NO) {
                count += 1;
            }
        }
        
        days -= 1;
    }
    days += 1;
    
    NSMutableArray* videoTrashBin = [[NSMutableArray alloc] init];
    // Has the test record been fully synced?
    BOOL synced = NO;
    for (TestRecord* testRecord in testRecords) {
        if (testRecord.parseID != nil) {
            for (CapillaryRecord* capillaryRecord in testRecord.capillaryRecords) {
                if (capillaryRecord.parseID != nil) {
                    // Record is synced if all videos are synced
                    synced = YES;
                    for (Video* video in capillaryRecord.videos) {
                        // If the video has not yet been deleted
                        if (video.videoDeleted.boolValue == NO) {
                            // Has the video has not been synced?
                            if (video.parseID == nil) {
                                synced = NO;
                            }
                            else {
                                // The video is slated for deletion
                                [videoTrashBin addObject:video];
                            }
                        }
                    }
                }
            }
        }
    }
    return videoTrashBin;
}

+ (NSMutableArray*)findUncompressedVideosToDelete:(NSManagedObjectContext*)managedObjectContext daysOld:(NSInteger)days
{
    NSInteger count = 0;
    NSArray* testRecords;
    // Delete uncompressed video records from today if you need to
    while ((count == 0) && (days >= 0)) {
        // Select records that were created more than N days ago
        NSDate *today = [NSDate date];
        NSDate *lastWeek = [today dateByAddingTimeInterval:-days*24*60*60];
        
        NSError *error;
        
        NSString *sortKey = @"created";
        NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sortKey ascending:NO];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"(created < %@)", lastWeek];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"TestRecord"
                                                  inManagedObjectContext:managedObjectContext];
        [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
        [fetchRequest setEntity:entity];
        testRecords = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
        
        count = 0;
        for (TestRecord* testRecord in testRecords) {
            BOOL cleaned = YES;
            for (CapillaryRecord* capillaryRecord in testRecord.capillaryRecords) {
                for (Video* video in capillaryRecord.uncompressedVideos) {
                    if (video.videoDeleted.boolValue == NO) {
                        cleaned = NO;
                    }
                }
            }
            if (cleaned == NO) {
                count += 1;
            }
        }
        
        days -= 1;
    }
    days += 1;
    
    NSMutableArray* videoTrashBin = [[NSMutableArray alloc] init];
    // Has the test record been fully synced?
    BOOL synced = NO;
    for (TestRecord* testRecord in testRecords) {
        if (testRecord.parseID != nil) {
            for (CapillaryRecord* capillaryRecord in testRecord.capillaryRecords) {
                if (capillaryRecord.parseID != nil) {
                    // Record is synced if all videos are synced
                    synced = YES;
                    for (Video* video in capillaryRecord.uncompressedVideos) {
                        // If the video has not yet been deleted
                        if (video.videoDeleted.boolValue == NO) {
                            // The video is slated for deletion
                            [videoTrashBin addObject:video];
                        }
                    }
                }
            }
        }
    }
    return videoTrashBin;
}

+ (void)deleteVideoFile:(Video*)video withContext:(NSManagedObjectContext*)managedObjectContext
{
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:video.resourceURL];
    
    NSError *error;
    BOOL success = [fileManager removeItemAtPath:filePath error:&error];
    if (success) {
        NSLog(@"File has been deleted");
        video.resourceURL = @"";
        video.videoDeleted = [NSNumber numberWithBool:YES];
        [managedObjectContext save:&error];
    }
    else
    {
        NSLog(@"Could not delete file -:%@ ",[error localizedDescription]);
    }
}

@end
