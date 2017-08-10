//
//  SettingsTableViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/11/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "SettingsTableViewController.h"
#import "DiskSpaceManager.h"
#import "constants.h"

@interface SettingsTableViewController ()

@end

@implementation SettingsTableViewController

@synthesize cslContext;
@synthesize managedObjectContext;

@synthesize phoneIDField;
@synthesize deviceIDField;
@synthesize diskSpaceLabel;
@synthesize uncompressedVideoSwitch;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    phoneIDField.delegate = self;
    deviceIDField.delegate = self;

    phoneIDField.text = [[NSUserDefaults standardUserDefaults] objectForKey:SimplePhoneIDKey];
    deviceIDField.text = [[NSUserDefaults standardUserDefaults] objectForKey:SimpleDeviceIDKey];
    uncompressedVideoSwitch.on = [[[NSUserDefaults standardUserDefaults] objectForKey:SaveUncompressedVideoKey] boolValue];
    
    NSNumber* diskSpace = [DiskSpaceManager FreeDiskSpace];
    diskSpaceLabel.text = [NSString stringWithFormat:@"%lld MB", diskSpace.longLongValue];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {

}

- (BOOL)textFieldShouldReturn: (UITextField *) textField {
    [textField resignFirstResponder];
    return YES;
}

- (IBAction)phoneIDEdited:(id)sender {
    // Store the latest SimplePhoneID as default
    [[NSUserDefaults standardUserDefaults] setObject:phoneIDField.text forKey:SimplePhoneIDKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)uncompressedVideoSwitchValueChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:uncompressedVideoSwitch.on] forKey:SaveUncompressedVideoKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)deviceIDEdited:(id)sender {
    [[NSUserDefaults standardUserDefaults] setObject:deviceIDField.text forKey:SimpleDeviceIDKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)deleteVideosPressed:(id)sender {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Delete videos?"
                                                                   message:@"This action will delete all videos from the device. Are you sure you want to continue?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *delete = [UIAlertAction
                             actionWithTitle:@"Delete videos"
                             style:UIAlertActionStyleDestructive
                             handler:^(UIAlertAction * action)
                             {
                                 [DiskSpaceManager DeleteAllVideos:managedObjectContext];
                                 NSNumber* diskSpace = [DiskSpaceManager FreeDiskSpace];
                                 diskSpaceLabel.text = [NSString stringWithFormat:@"%lld MB", diskSpace.longLongValue];
                                 [alert dismissViewControllerAnimated:YES completion:nil];
                             }];
    
    UIAlertAction *cancel = [UIAlertAction
                             actionWithTitle:@"Cancel"
                             style:UIAlertActionStyleDestructive
                             handler:^(UIAlertAction * action)
                             {
                                 [alert dismissViewControllerAnimated:YES completion:nil];
                             }];
    
    
    [alert addAction:delete];
    [alert addAction:cancel];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
