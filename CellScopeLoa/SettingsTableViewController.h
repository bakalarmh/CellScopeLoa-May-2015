//
//  SettingsTableTableViewController.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/11/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CSLContext.h"

@interface SettingsTableViewController : UITableViewController <UITextFieldDelegate>

@property (weak, nonatomic) CSLContext* cslContext;
@property (weak, nonatomic) NSManagedObjectContext *managedObjectContext;

@property (weak, nonatomic) IBOutlet UITextField *phoneIDField;
@property (weak, nonatomic) IBOutlet UITextField *deviceIDField;
@property (weak, nonatomic) IBOutlet UISwitch *uncompressedVideoSwitch;
@property (weak, nonatomic) IBOutlet UILabel *diskSpaceLabel;

- (IBAction)phoneIDEdited:(id)sender;
- (IBAction)uncompressedVideoSwitchValueChanged:(id)sender;
- (IBAction)deviceIDEdited:(id)sender;
- (IBAction)deleteVideosPressed:(id)sender;

@end
