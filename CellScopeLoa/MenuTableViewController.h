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

// BLE
@property (strong, nonatomic) BLEManager* bleManager;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *connectionStatusItem;

@property (strong, nonatomic) IBOutlet UITableView *MenuTableView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *ToolbarStatusButton;
- (IBAction)connectionStatusPressed:(id)sender;

@end
