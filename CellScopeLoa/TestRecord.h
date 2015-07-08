//
//  TestRecord.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 7/7/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CapillaryRecord;

@interface TestRecord : NSManagedObject

@property (nonatomic, retain) NSString * boardUUID;
@property (nonatomic, retain) NSDate * created;
@property (nonatomic, retain) NSString * deviceID;
@property (nonatomic, retain) NSNumber * latitude;
@property (nonatomic, retain) NSString * localTimeZone;
@property (nonatomic, retain) NSNumber * longitude;
@property (nonatomic, retain) NSNumber * objectsPerField;
@property (nonatomic, retain) NSNumber * objectsPerMl;
@property (nonatomic, retain) NSString * parseID;
@property (nonatomic, retain) NSString * patientNIHID;
@property (nonatomic, retain) NSString * phoneIdentifier;
@property (nonatomic, retain) NSString * simplePhoneID;
@property (nonatomic, retain) NSString * simpleTestID;
@property (nonatomic, retain) NSString * state;
@property (nonatomic, retain) NSString * testMode;
@property (nonatomic, retain) NSString * testNIHID;
@property (nonatomic, retain) NSString * testUUID;
@property (nonatomic, retain) NSNumber * surfMotionMetric;
@property (nonatomic, retain) NSSet *capillaryRecords;
@end

@interface TestRecord (CoreDataGeneratedAccessors)

- (void)addCapillaryRecordsObject:(CapillaryRecord *)value;
- (void)removeCapillaryRecordsObject:(CapillaryRecord *)value;
- (void)addCapillaryRecords:(NSSet *)values;
- (void)removeCapillaryRecords:(NSSet *)values;

@end
