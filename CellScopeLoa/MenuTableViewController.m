//
//  MenuTableViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/9/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "MenuTableViewController.h"
#import "LoaAppDelegate.h"
#import "DeviceManagerViewController.h"
#import "BarcodeIDViewController.h"
#import "SettingsPasswordViewController.h"
#import "CloudSyncViewController.h"
#import "DiskSpaceManager.h"

@interface MenuTableViewController ()

@end

@implementation MenuTableViewController {
    BOOL commlock;
    BOOL batteryRequest;
    NSTimer* batteryTimer;
    NSTimer* diskTimer;
}

@synthesize managedObjectContext;
@synthesize cslContext;

// UI Objects
@synthesize MenuTableView;
@synthesize ToolbarStatusButton;
@synthesize connectionStatusItem;
@synthesize testButtonLabel;
@synthesize testButtonIcon;
@synthesize batteryBarButtonItem;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Bluetooth manager lives here
    BLEManager* bleManager = [[BLEManager alloc] init];
    bleManager.delegate = self;
    cslContext.bleManager = bleManager;
    
    // Setup UI state of the connected indicator
    testButtonLabel.alpha = 0.2;
    testButtonIcon.alpha = 0.2;
    if (bleManager.connected) {
        connectionStatusItem.title = NSLocalizedString(@"Connected",nil);
        connectionStatusItem.tintColor = [UIColor colorWithRed:0.0 green:0.8 blue:0 alpha:1]; /*#00CC00*/
    }
    else {
        cslContext.loaDevice = nil;
        connectionStatusItem.title = NSLocalizedString(@"Disconnected",nil);
        connectionStatusItem.tintColor = [UIColor colorWithRed:1.0 green:0.0 blue:0 alpha:1]; /*#00CC00*/
    }
    
    batteryRequest = NO;
    commlock = NO;
    [self setBatteryState:@"Unknown"];
    
    // Set up a disk space monitor. Check the disk every 4 hours (just in case the device has been left on).
    diskTimer = [NSTimer scheduledTimerWithTimeInterval:60.0*60.0*4.0
                                                    target:self
                                                  selector:@selector(diskTimerFired:)
                                                  userInfo:nil
                                                   repeats:YES];
    [diskTimer fire];
}

- (void)setBatteryState:(NSString*)state
{
    if ([state isEqualToString:@"Full"]) {
        UIImage *image = [[UIImage imageNamed:@"battery-full.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        [batteryBarButtonItem setImage:image];
    }
    else if([state isEqualToString:@"High"]) {
        UIImage *image = [[UIImage imageNamed:@"battery-high.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        [batteryBarButtonItem setImage:image];
    }
    else if([state isEqualToString:@"Half"]) {
        UIImage *image = [[UIImage imageNamed:@"battery-half.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        [batteryBarButtonItem setImage:image];
    }
    else if([state isEqualToString:@"Low"]) {
        UIImage *image = [[UIImage imageNamed:@"battery-low.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        [batteryBarButtonItem setImage:image];
    }
    else if([state isEqualToString:@"Unknown"]) {
        UIImage *image = [[UIImage imageNamed:@"battery-unknown.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        [batteryBarButtonItem setImage:image];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController.toolbar setHidden:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // rows in section 0 should not be selectable
    if (indexPath.row == 0) {
        if ([cslContext deviceIsConnected]) {
            return indexPath;
        }
        else {
            return nil;
        }
    }
    // By default, allow row to be selected
    return indexPath;
}

#pragma mark - Manage free disk space
// Manage disk space to make sure the file system does not fill up
- (void)manageDiskSpace
{
    [DiskSpaceManager ManageDiskSpace:managedObjectContext];
}

#pragma mark - Bluetooth

// Seek devices when the board is powered on
- (void)bluetoothStateDidChange:(CBCentralManagerState)state
{
    if (state == CBCentralManagerStatePoweredOn) {
        [cslContext.bleManager seekDevices];
    }
}

- (void)didUpdateDevices
{
    // Post a notificatipn
    [[NSNotificationCenter defaultCenter] postNotificationName:@"bleDidUpdateDevices" object:self userInfo:nil];
    
    BLEManager* manager = cslContext.bleManager;
    BOOL foundTrusted = NO;
    // Connect to trusted UUID if it is detected
    NSMutableArray* mDevices = manager.mDevices;
    for (int i=0; i< mDevices.count; i++) {
        if ([[mDevices objectAtIndex:i] isEqualToString:manager.lastUUID]) {
            [manager connectWithUUID:manager.lastUUID];
            foundTrusted = YES;
            break;
        }
    }
    if (!foundTrusted) {
        connectionStatusItem.title = NSLocalizedString(@"Disconnected",nil);
        connectionStatusItem.tintColor = [UIColor colorWithRed:1.0 green:0.0 blue:0 alpha:1]; /*#00CC00*/
    }
}

- (void)didConnect
{
    // Post a notificatipn
    [[NSNotificationCenter defaultCenter] postNotificationName:@"bleDidConnect" object:self userInfo:nil];
    
    connectionStatusItem.title = NSLocalizedString(@"Connected",nil);
    connectionStatusItem.tintColor = [UIColor colorWithRed:0 green:0.8 blue:0 alpha:1]; /*#00CC00*/
    
    testButtonLabel.alpha = 1.0;
    testButtonIcon.alpha = 1.0;
    
    cslContext.loaDevice = [[BluetoothLoaDevice alloc] initWithBLEManager:cslContext.bleManager];
    [cslContext.loaDevice LEDOn];
    
    int delay = 1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (cslContext.loaDevice != nil) {
            [cslContext.loaDevice LEDOff];
            
            batteryTimer = [NSTimer scheduledTimerWithTimeInterval:60.0*10.0
                                                               target:self
                                                             selector:@selector(batteryTimerFired:)
                                                             userInfo:nil
                                                              repeats:YES];
            [batteryTimer fire];
        }
    });
}

- (void)batteryTimerFired:(NSTimer *) theTimer
{
    NSLog(@"Battery timer fired!");
    if (commlock == NO) {
        [cslContext.loaDevice queryBattery];
        batteryRequest = YES;
        commlock = YES;
    }
}

- (void)diskTimerFired:(NSTimer *) theTimer
{
    NSLog(@"Disk timer fired!");
    [self manageDiskSpace];
}

- (void)didDisconnect
{
    // Post a notificatipn
    [[NSNotificationCenter defaultCenter] postNotificationName:@"bleDidDisconnect" object:self userInfo:nil];
    
    connectionStatusItem.title = NSLocalizedString(@"Disconnected",nil);
    connectionStatusItem.tintColor = [UIColor colorWithRed:1.0 green:0.0 blue:0 alpha:1]; /*#FF0000*/
    
    cslContext.loaDevice = nil;
    
    testButtonLabel.alpha = 0.2;
    testButtonIcon.alpha = 0.2;
    
    [self setBatteryState:@"Unknown"];
}

- (void)bleDidReceiveData:(NSMutableArray*)packets
{
    if (batteryRequest) {
        NSData* packet = [packets objectAtIndex:0];
        unsigned char* data = (unsigned char*)packet.bytes;
        float voltage = (data[0]/(float)0xFF)*5.0;
        NSLog(@"Voltage: %f", (data[0]/(float)0xFF)*5.0);
        
        if (voltage < 3.6) {
            [self setBatteryState:@"Low"];
        }
        else if (voltage < 3.8) {
            [self setBatteryState:@"Half"];
        }
        else if (voltage < 4.0) {
            [self setBatteryState:@"High"];
        }
        else if (voltage >= 4.0) {
            [self setBatteryState:@"Full"];
        }
        batteryRequest = NO;
    }
    commlock = NO;
}

#pragma mark - Navigation

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"Test"]) {
        if ([cslContext deviceIsConnected]) {
            return YES;
        }
        else {
            return NO;
        }
    }
    else {
        return YES;
    }
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"Test"]) {
        BarcodeIDViewController* vc = (BarcodeIDViewController*)segue.destinationViewController;
        vc.managedObjectContext = managedObjectContext;
        vc.cslContext = cslContext;
        vc.recaptureID = NO;
    }
    else if([segue.identifier isEqualToString:@"Settings"]) {
        SettingsPasswordViewController* vc = (SettingsPasswordViewController*)segue.destinationViewController;
        vc.cslContext = cslContext;
    }
    else if([segue.identifier isEqualToString:@"Devices"]) {
        DeviceManagerViewController* vc = (DeviceManagerViewController*)segue.destinationViewController;
        vc.bleManager = cslContext.bleManager;
    }
    else if([segue.identifier isEqualToString:@"CloudSync"]) {
        CloudSyncViewController* vc = (CloudSyncViewController*)segue.destinationViewController;
        vc.cslContext = cslContext;
        vc.managedObjectContext = managedObjectContext;
    }
    else if([segue.identifier isEqualToString:@"Data"]) {
        CloudSyncViewController* vc = (CloudSyncViewController*)segue.destinationViewController;
        vc.cslContext = cslContext;
        vc.managedObjectContext = managedObjectContext;
    }
}

// Unwind segue for changing a patient ID. Returns from the test screen, could be during an active test.
- (IBAction)unwindToMainMenu:(UIStoryboardSegue *)unwindSegue
{
    // Diable returning to the home screen from this - only for changing ID
    [self.navigationController.toolbar setHidden:YES];
    self.navigationItem.hidesBackButton = YES;
}

// Unwind segue for return from valid test results
- (IBAction)unwindToMainMenuValidTest:(UIStoryboardSegue *)unwindSegue
{
    // Diable returning to the home screen from this - only for changing ID
    [self.navigationController.toolbar setHidden:YES];
    self.navigationItem.hidesBackButton = YES;
}

// Unwind segue for return from valid test results
- (IBAction)unwindToMainMenuInvalidTest:(UIStoryboardSegue *)unwindSegue
{
    // Diable returning to the home screen from this - only for changing ID
    [self.navigationController.toolbar setHidden:YES];
    self.navigationItem.hidesBackButton = YES;
}

- (IBAction)connectionStatusPressed:(id)sender {
    BLEManager* manager = cslContext.bleManager;
    if (!manager.connected) {
        connectionStatusItem.title = NSLocalizedString(@"Searching",nil);
        connectionStatusItem.tintColor = [UIColor colorWithRed:1.0 green:0.8 blue:0 alpha:1]; /*#00CC00*/
        [manager seekDevices];
    }
}

@end
