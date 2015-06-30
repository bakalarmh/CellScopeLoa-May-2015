//
//  InvalidResultsViewController.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/17/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CSLContext.h"

@interface InvalidResultsViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIBarButtonItem *finishedButtonItem;
@property (weak, nonatomic) CSLContext* cslContext;
@property (weak, nonatomic) IBOutlet UILabel *testResultLabel;
@property (weak, nonatomic) IBOutlet UILabel *errorMessageLabel;
@property (weak, nonatomic) IBOutlet UILabel *countsLabel1;
@property (weak, nonatomic) IBOutlet UILabel *countsLabel2;

- (IBAction)finishedPressed:(id)sender;

@end
