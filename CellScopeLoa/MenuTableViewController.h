//
//  MenuTableViewController.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/9/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLEManager.h"
#import "CSLContext.h"

@interface MenuTableViewController : UITableViewController <BLEManagerDelegate>

@property (weak, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (weak, nonatomic) CSLContext *cslContext;

// Labels
@property (weak, nonatomic) IBOutlet UILabel *dataButtonLabel;
@property (weak, nonatomic) IBOutlet UILabel *devicesButtonLabel;
@property (weak, nonatomic) IBOutlet UILabel *cloudButtonLabel;
@property (weak, nonatomic) IBOutlet UILabel *settingsButtonLabel;

// BLE
@property (weak, nonatomic) IBOutlet UIBarButtonItem *connectionStatusItem;
@property (weak, nonatomic) IBOutlet UILabel *testButtonLabel;
@property (weak, nonatomic) IBOutlet UIImageView *testButtonIcon;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *batteryBarButtonItem;

@property (strong, nonatomic) IBOutlet UITableView *MenuTableView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *ToolbarStatusButton;
- (IBAction)connectionStatusPressed:(id)sender;

@end
