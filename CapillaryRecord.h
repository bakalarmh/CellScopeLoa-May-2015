//
//  CapillaryRecord.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 7/8/15.
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
@property (nonatomic, retain) Video *uncompressedVideos;
@end

@interface CapillaryRecord (CoreDataGeneratedAccessors)

- (void)addVideosObject:(Video *)value;
- (void)removeVideosObject:(Video *)value;
- (void)addVideos:(NSSet *)values;
- (void)removeVideos:(NSSet *)values;

@end
