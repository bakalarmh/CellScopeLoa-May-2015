//
//  SettingsTableTableViewController.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/11/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SettingsTableViewController : UITableViewController <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UITextField *phoneIDField;
@property (weak, nonatomic) IBOutlet UITextField *deviceIDField;

- (IBAction)phoneIDEdited:(id)sender;
@end
