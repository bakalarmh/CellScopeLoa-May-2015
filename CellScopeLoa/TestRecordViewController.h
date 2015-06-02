//
//  TestRecordViewController.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/31/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CSLContext.h"
#import "TestRecord.h"

@interface TestRecordViewController : UIViewController

@property (weak, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (weak, nonatomic) CSLContext *cslContext;

@property (weak, nonatomic) TestRecord *testRecord;

@property (weak, nonatomic) IBOutlet UILabel *capillaryOneDataLabel;
@property (weak, nonatomic) IBOutlet UILabel *capillaryTwoDataLabel;
@property (weak, nonatomic) IBOutlet UILabel *mfmlLabel;
@property (weak, nonatomic) IBOutlet UILabel *mffieldLabel;

- (IBAction)videoButtonOnePressed:(id)sender;
- (IBAction)videoButtonTwoPressed:(id)sender;

@end
