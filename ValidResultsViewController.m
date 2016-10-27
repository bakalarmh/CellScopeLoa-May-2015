//
//  ValidResultsViewController.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/15/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "ValidResultsViewController.h"
#import "TestValidation.h"

@interface ValidResultsViewController ()

@end

@implementation ValidResultsViewController

@synthesize cslContext;
@synthesize managedObjectContext;
@synthesize cardColorView;
@synthesize finishedButtonItem;
@synthesize mffieldLabel;
@synthesize mfmlLabel;
@synthesize tntIDLabel;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.navigationItem setHidesBackButton:YES];
    
    NSDictionary* testResults = [TestValidation ResultsFromTestRecord:cslContext.activeTestRecord];
    
    NSNumber* objectsPerField = [testResults objectForKey:@"ObjectsPerField"];
    NSNumber* objectsPerMl = [testResults objectForKey:@"ObjectsPerMl"];
    
    NSNumber* reportObjectsPerMl = objectsPerMl;
    NSString* mfmlString;
    if (objectsPerField.floatValue < 0.05) {
        reportObjectsPerMl = @0.0;
        mfmlString = @"0";
    }
    else if (objectsPerField.floatValue < 0.2) {
        mfmlString = @"< 150";
    }
    else {
        NSNumberFormatter *formatter = [NSNumberFormatter new];
        [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [formatter setMaximumFractionDigits:0];
        mfmlString = [formatter stringFromNumber:reportObjectsPerMl];
    }
    
    mffieldLabel.text = [NSString stringWithFormat:@"%.2f mf/field", objectsPerField.floatValue];
    mfmlLabel.text = [NSString stringWithFormat:@"%@ mf/ml", mfmlString];
    
    tntIDLabel.text = cslContext.activeTestRecord.patientNIHID;
    
    if (objectsPerMl.floatValue < 5000) {
        cardColorView.backgroundColor = [UIColor greenColor];
    }
    else if (objectsPerMl.floatValue < 20000) {
        cardColorView.backgroundColor = [UIColor yellowColor];
    }
    else {
        cardColorView.backgroundColor = [UIColor redColor];
    }
    
    // Store the output in the ManagedObjectContext
    [managedObjectContext save:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ReturnToMenu"]) {
        NSLog(@"Back to menu");
    }
}

- (IBAction)finishedPressed:(id)sender {
    [self performSegueWithIdentifier:@"ReturnToMenu" sender:self];
}
@end
