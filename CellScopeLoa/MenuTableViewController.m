//
//  MenuTableViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/9/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "MenuTableViewController.h"
#import "DeviceManagerViewController.h"
#import "BarcodeIDViewController.h"

@interface MenuTableViewController ()

@end

@implementation MenuTableViewController

@synthesize managedObjectContext;
@synthesize cslContext;
@synthesize bleManager;

// UI Objects
@synthesize MenuTableView;
@synthesize ToolbarStatusButton;
@synthesize connectionStatusItem;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Bluetooth manager lives here
    bleManager = [[BLEManager alloc] init];
    bleManager.delegate = self;
    
    // Setup UI state of the connected indicator
    if (bleManager.connected) {
        connectionStatusItem.title = @"Connected";
        connectionStatusItem.tintColor = [UIColor colorWithRed:0.0 green:0.8 blue:0 alpha:1]; /*#00CC00*/
    }
    else {
        connectionStatusItem.title = @"Disconnected";
        connectionStatusItem.tintColor = [UIColor colorWithRed:1.0 green:0.0 blue:0 alpha:1]; /*#00CC00*/
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

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    // Return the number of rows in the section.
    return 4;
}

/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Bluetooth

// Seek devices when the board is powered on
- (void)bluetoothStateDidChange:(CBCentralManagerState)state
{
    if (state == CBCentralManagerStatePoweredOn) {
        [bleManager seekDevices];
    }
}

- (void)didUpdateDevices
{
    BOOL foundTrusted = NO;
    // Connect to trusted UUID if it is detected
    NSMutableArray* mDevices = bleManager.mDevices;
    for (int i=0; i< mDevices.count; i++) {
        if ([[mDevices objectAtIndex:i] isEqualToString:bleManager.lastUUID]) {
            [bleManager connectWithUUID:bleManager.lastUUID];
            foundTrusted = YES;
            break;
        }
    }
    if (!foundTrusted) {
        connectionStatusItem.title = @"Disconnected";
        connectionStatusItem.tintColor = [UIColor colorWithRed:1.0 green:0.0 blue:0 alpha:1]; /*#00CC00*/
    }
}

- (void)didConnect
{
    connectionStatusItem.title = @"Connected";
    connectionStatusItem.tintColor = [UIColor colorWithRed:0 green:0.8 blue:0 alpha:1]; /*#00CC00*/
}

- (void)didDisconnect
{
    connectionStatusItem.title = @"Disconnected";
    connectionStatusItem.tintColor = [UIColor colorWithRed:1.0 green:0.0 blue:0 alpha:1]; /*#FF0000*/
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"Test"]) {
        BarcodeIDViewController* vc = (BarcodeIDViewController*)segue.destinationViewController;
        vc.managedObjectContext = managedObjectContext;
        vc.cslContext = cslContext;
        vc.recaptureID = NO;
    }
    else if([segue.identifier isEqualToString:@"Devices"]) {
        DeviceManagerViewController* vc = (DeviceManagerViewController*)segue.destinationViewController;
        vc.bleManager = bleManager;
    }
}

// Unwind segue for changing a patient ID. Returns from the test screen, could be during an active test.
- (IBAction)unwindToMainMenu:(UIStoryboardSegue *)unwindSegue
{
    // Diable returning to the home screen from this - only for changing ID
    [self.navigationController.toolbar setHidden:YES];
    self.navigationItem.hidesBackButton = YES;
}

- (IBAction)connectionStatusPressed:(id)sender {
    if (!bleManager.connected) {
        connectionStatusItem.title = @"Searching...";
        connectionStatusItem.tintColor = [UIColor colorWithRed:1.0 green:0.8 blue:0 alpha:1]; /*#00CC00*/
        [bleManager seekDevices];
    }
}

@end
