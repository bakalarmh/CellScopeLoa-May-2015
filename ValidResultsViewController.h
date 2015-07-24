//
//  ValidResultsViewController.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/15/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CSLContext.h"

@interface ValidResultsViewController : UIViewController

@property (weak, nonatomic) CSLContext* cslContext;
@property (weak, nonatomic) NSManagedObjectContext *managedObjectContext;

@property (weak, nonatomic) IBOutlet UILabel *mffieldLabel;
@property (weak, nonatomic) IBOutlet UILabel *mfmlLabel;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *finishedButtonItem;
@property (weak, nonatomic) IBOutlet UIView *cardColorView;
@property (weak, nonatomic) IBOutlet UILabel *tntIDLabel;

- (IBAction)finishedPressed:(id)sender;

@end
