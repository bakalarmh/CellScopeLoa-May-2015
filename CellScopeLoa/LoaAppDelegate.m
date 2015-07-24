//
//  AppDelegate.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/9/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "LoaAppDelegate.h"
#import <Parse/Parse.h>
#import "MenuTableViewController.h"
#import "constants.h"

@interface LoaAppDelegate ()

@end

@implementation LoaAppDelegate

@synthesize cslContext;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Register first launch
    if ([[NSUserDefaults standardUserDefaults] boolForKey:HasLaunchedKey])
    {
        // Application has launched previously.
        
        // Clean up parse cache.
        [LoaAppDelegate cleanUpPFFileCacheDirectory];
        [LoaAppDelegate cleanUpPFFilePrivateFilesDirectory];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:HasLaunchedKey];
        // This is the first launch ever
        
        // Store the administrators password (unsecure)
        [[NSUserDefaults standardUserDefaults] setObject:@"capillary" forKey:AdminPassKey];
        
        // Store a temporary SimplePhontID password (unsecure)
        [[NSUserDefaults standardUserDefaults] setObject:@"Null" forKey:SimplePhoneIDKey];
        [[NSUserDefaults standardUserDefaults] setObject:@"Null" forKey:SimpleDeviceIDKey];
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:FocusCheckSwitchKey];
        
        // Store a counter - global test count for this device
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:0] forKey:TestCounterKey];
        
        // Lock the relative exposure and ISO to a set value
        // CMTime exposure = CMTimeMake(1, 256);
        // NSValue *exposureValue = [NSValue valueWithBytes:&exposure objCType:@encode(CMTime)];
        // [[NSUserDefaults standardUserDefaults] setObject:exposureValue forKey:ExposureKey];
        //[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:0] forKey:ISOKey];
        
        // Store Default number of fields of view
        NSInteger fieldsOfView = 7;
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:fieldsOfView] forKey:FieldsOfViewKey];
        
        // Require two capillaries?
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:RequireTwoCapillariesKey];
        
        // Store uncompressed video?
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:SaveUncompressedVideoKey];
    }
    
    // Store the volume of the capillary. Mf/ml = objects per field / capillaryVolume
    float capillaryVolume = .00259;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:capillaryVolume] forKey:CapillaryVolumeKey];
    
    // Gold standard multiplier - gold count = Loa count * gold multiplier
    float goldMultiplier = 1.9885;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:goldMultiplier] forKey:GoldMultiplierKey];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // [Optional] Power your app with Local Datastore. For more info, go to
    // https://parse.com/docs/ios_guide#localdatastore/iOS
    [Parse enableLocalDatastore];
    
    // Initialize Parse.
    [Parse setApplicationId:@"vitn53WDyyclIvAXm8TgKVOdfsQUnEN83l17Dnyq"
                  clientKey:@"LCRoIkrX6riioaS0uHwlqUtN0hw4W6Xfn7vH3wAF"];
    
    // [Optional] Track statistics around application opens.
    [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
    
    // Pass the managed object context to the root controller
    UINavigationController *rootViewController = (UINavigationController*)self.window.rootViewController;
    MenuTableViewController* menuViewController = (MenuTableViewController*)rootViewController.topViewController;
    menuViewController.managedObjectContext = self.managedObjectContext;
    
    // Create a CSLContext and pass it to the root controller
    cslContext = [[CSLContext alloc] init];
    menuViewController.cslContext = cslContext;
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

#pragma mark - Core Data stack

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (NSURL *)applicationDocumentsDirectory {
    // The directory the application uses to store the Core Data store file. This code uses a directory named "FL.CellScopeLoa" in the application's documents directory.
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSManagedObjectModel *)managedObjectModel {
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Model" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it.
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    // Create the coordinator and store
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Model.sqlite"];
    NSError *error = nil;
    NSString *failureReason = @"There was an error creating or loading the application's saved data.";
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        // Report any error we got.
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
        dict[NSLocalizedFailureReasonErrorKey] = failureReason;
        dict[NSUnderlyingErrorKey] = error;
        error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        // Replace this with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}


- (NSManagedObjectContext *)managedObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    return _managedObjectContext;
}

#pragma mark - Core Data Saving support

- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

+ (void)cleanUpPFFileCacheDirectory
{
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *cacheDirectoryURL = [[fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *PFFileCacheDirectoryURL = [cacheDirectoryURL URLByAppendingPathComponent:@"Parse/PFFileCache" isDirectory:YES];
    NSArray *PFFileCacheDirectory = [fileManager contentsOfDirectoryAtURL:PFFileCacheDirectoryURL includingPropertiesForKeys:nil options:0 error:&error];
    
    if (!PFFileCacheDirectory || error) {
        if (error && error.code != NSFileReadNoSuchFileError) {
            NSLog(@"Error : Retrieving content of directory at URL %@ failed with error : %@", PFFileCacheDirectoryURL, error);
        }
        return;
    }
    
    for (NSURL *fileURL in PFFileCacheDirectory) {
        BOOL success = [fileManager removeItemAtURL:fileURL error:&error];
        if (!success || error) {
            NSLog(@"Error : Removing item at URL %@ failed with error : %@", fileURL, error);
            error = nil;
        }
    }
}

+ (void)cleanUpPFFilePrivateFilesDirectory
{
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *libraryDirectory = [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *PFFilePrivateDocumentsDirectoryURL = [libraryDirectory URLByAppendingPathComponent:@"Private Documents/Parse/PFFileStaging" isDirectory:YES];
    NSArray *PFFileCacheDirectory = [fileManager contentsOfDirectoryAtURL:PFFilePrivateDocumentsDirectoryURL includingPropertiesForKeys:nil options:0 error:&error];
    
    if (!PFFileCacheDirectory || error) {
        if (error && error.code != NSFileReadNoSuchFileError) {
            NSLog(@"Error : Retrieving content of directory at URL %@ failed with error : %@", PFFilePrivateDocumentsDirectoryURL, error);
        }
        return;
    }
    
    for (NSURL *fileURL in PFFileCacheDirectory) {
        BOOL success = [fileManager removeItemAtURL:fileURL error:&error];
        if (!success || error) {
            NSLog(@"Error : Removing item at URL %@ failed with error : %@", fileURL, error);
            error = nil;
        }
    }
}

+ (uint64_t)FreeDiskSpace
{
    uint64_t totalSpace = 0;
    uint64_t totalFreeSpace = 0;
    
    __autoreleasing NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    
    if (dictionary) {
        NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
        NSLog(@"Memory Capacity of %llu MiB with %llu MiB Free memory available.", ((totalSpace/1024ll)/1024ll), ((totalFreeSpace/1024ll)/1024ll));
    } else {
        NSLog(@"Error Obtaining System Memory Info: Domain = %@, Code = %d", [error domain], [error code]);
    }
    
    return totalFreeSpace;
}

@end
