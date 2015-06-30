//
//  DiskSpaceManager.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 6/30/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CSLContext.h"

@interface DiskSpaceManager : NSObject

+ (void)ManageDiskSpace:(NSManagedObjectContext*)managedObjectContext;

@end
