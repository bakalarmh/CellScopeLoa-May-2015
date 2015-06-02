//
//  CapillaryRecord.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/31/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class TestRecord, Video;

@interface CapillaryRecord : NSManagedObject

@property (nonatomic, retain) NSNumber * capillaryIndex;
@property (nonatomic, retain) NSDate * created;
@property (nonatomic, retain) NSString * errorString;
@property (nonatomic, retain) NSNumber * objectsPerField;
@property (nonatomic, retain) NSNumber * objectsPerMl;
@property (nonatomic, retain) NSString * parseID;
@property (nonatomic, retain) NSString * testUUID;
@property (nonatomic, retain) NSNumber * videosDeleted;
@property (nonatomic, retain) TestRecord *testRecord;
@property (nonatomic, retain) NSSet *videos;
@end

@interface CapillaryRecord (CoreDataGeneratedAccessors)

- (void)addVideosObject:(Video *)value;
- (void)removeVideosObject:(Video *)value;
- (void)addVideos:(NSSet *)values;
- (void)removeVideos:(NSSet *)values;

@end
