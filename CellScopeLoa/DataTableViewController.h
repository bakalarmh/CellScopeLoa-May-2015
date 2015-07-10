//
//  DataTableViewController.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/20/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CSLContext.h"

@interface DataTableViewController : UITableViewController

@property (weak, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (weak, nonatomic) CSLContext *cslContext;

- (void)didConnect;

@end
