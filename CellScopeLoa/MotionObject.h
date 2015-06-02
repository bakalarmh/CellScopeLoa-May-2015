//
//  MotionObject.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/31/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface MotionObject : NSManagedObject

@property (nonatomic, retain) NSNumber * start;
@property (nonatomic, retain) NSNumber * x;
@property (nonatomic, retain) NSNumber * y;
@property (nonatomic, retain) UNKNOWN_TYPE end;

@end
