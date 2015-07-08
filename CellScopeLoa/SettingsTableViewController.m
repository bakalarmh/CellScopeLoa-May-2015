//
//  SettingsTableViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/11/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "SettingsTableViewController.h"
#import "constants.h"

@interface SettingsTableViewController ()

@end

@implementation SettingsTableViewController

@synthesize cslContext;
@synthesize phoneIDField;
@synthesize deviceIDField;
@synthesize twoCapillariesSwitch;
@synthesize uncompressedVideoSwitch;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    phoneIDField.delegate = self;
    deviceIDField.delegate = self;

    phoneIDField.text = [[NSUserDefaults standardUserDefaults] objectForKey:SimplePhoneIDKey];
    deviceIDField.text = [[NSUserDefaults standardUserDefaults] objectForKey:SimpleDeviceIDKey];
    twoCapillariesSwitch.on = [[[NSUserDefaults standardUserDefaults] objectForKey:RequireTwoCapillariesKey] boolValue];
    uncompressedVideoSwitch.on = [[[NSUserDefaults standardUserDefaults] objectForKey:SaveUncompressedVideoKey] boolValue];

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

- (IBAction)twoCapillariesSwitchValueChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:twoCapillariesSwitch.on] forKey:RequireTwoCapillariesKey];
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

@end
