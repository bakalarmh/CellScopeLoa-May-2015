//
//  DeviceTableViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/9/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "DeviceTableViewController.h"

@interface DeviceTableViewController ()

@end

@implementation DeviceTableViewController {
    BOOL busy;
}

@synthesize textBluetoothScanner;
@synthesize bleManager;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Listen for connection events
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bleDidUpdateDevices:)
                                                 name:@"bleDidUpdateDevices" object:nil];
    
    // Listen for Disconnection events
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(bleDidDisconnect:)
                                                 name:@"bleDidDisconnect" object:nil];
    
    busy = NO;
    
    if (!bleManager.connected) {
        [bleManager seekDevices];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)bleDidUpdateDevices:(NSNotification*)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return bleManager.mDevices.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Device Cell"];
    
    UILabel *mainLabel = (UILabel *)[cell.contentView viewWithTag:5];
    mainLabel.text = [bleManager.mDevices objectAtIndex:indexPath.row];
    
    return cell;
}

- (UITableViewCell*)parentCellForView:(id)theView
{
    id viewSuperView = [theView superview];
    while (viewSuperView != nil) {
        if ([viewSuperView isKindOfClass:[UITableViewCell class]]) {
            return (UITableViewCell *)viewSuperView;
        }
        else {
            viewSuperView = [viewSuperView superview];
        }
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString* newUUID = [bleManager.mDevices objectAtIndex:indexPath.row];
    
    if (![newUUID isEqualToString:bleManager.lastUUID]) {
        [bleManager clearConnections];
    }
    
    // Store new UUID in the ble manager
    [bleManager storeDefaultUUID:newUUID];
    
    // Return to the device manager
    [[self navigationController] popViewControllerAnimated:YES];
}

-(IBAction)identifyBoard:(id)sender
{
    UIButton *butn = (UIButton *)sender;
    UITableViewCell *cell = [self parentCellForView:butn];
    
    if (cell != nil) {
        UILabel *mainLabel = (UILabel *)[cell.contentView viewWithTag:5];
        NSString* newUUID = mainLabel.text;
        
        // Avoid duplicate disconnect signal
        busy = YES;
        
        [bleManager clearConnections];
        int delayms = 1000;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayms * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            [bleManager connectWithUUID:newUUID];
            bleManager.lastUUID = newUUID;
        });
    }
}

- (void)bleDidConnect:(NSNotification*)notification
{
    NSLog(@"Did connect!");
    busy = NO;
}

- (void)bleDidDisconnect:(NSNotification*)notification
{
    if (busy == NO) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!bleManager.connected) {
                [bleManager seekDevices];
            }
        });
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
