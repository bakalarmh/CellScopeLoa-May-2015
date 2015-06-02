//
//  Video.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/31/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MotionObject;

@interface Video : NSManagedObject

@property (nonatomic, retain) NSNumber * averageObjectCount;
@property (nonatomic, retain) NSNumber * capillaryIndex;
@property (nonatomic, retain) NSDate * created;
@property (nonatomic, retain) NSString * errorString;
@property (nonatomic, retain) NSNumber * fieldIndex;
@property (nonatomic, retain) NSString * parseID;
@property (nonatomic, retain) NSString * resourceURL;
@property (nonatomic, retain) NSString * testUUID;
@property (nonatomic, retain) NSNumber * deleted;
@property (nonatomic, retain) NSOrderedSet *motionObjects;
@end

@interface Video (CoreDataGeneratedAccessors)

- (void)insertObject:(MotionObject *)value inMotionObjectsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromMotionObjectsAtIndex:(NSUInteger)idx;
- (void)insertMotionObjects:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeMotionObjectsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInMotionObjectsAtIndex:(NSUInteger)idx withObject:(MotionObject *)value;
- (void)replaceMotionObjectsAtIndexes:(NSIndexSet *)indexes withMotionObjects:(NSArray *)values;
- (void)addMotionObjectsObject:(MotionObject *)value;
- (void)removeMotionObjectsObject:(MotionObject *)value;
- (void)addMotionObjects:(NSOrderedSet *)values;
- (void)removeMotionObjects:(NSOrderedSet *)values;
@end
