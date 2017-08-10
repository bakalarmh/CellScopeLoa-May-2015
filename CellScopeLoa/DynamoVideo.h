//
//  DynamoVideo.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 10/30/16.
//  Copyright © 2016 Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AWSDynamoDB/AWSDynamoDB.h>

@interface DynamoVideo : AWSDynamoDBObjectModel <AWSDynamoDBModeling>


@property (nonatomic, strong) NSString * URL;
@property (nonatomic, strong) NSString * parseID;
@property (nonatomic, strong) NSString * testUUID;
@property (nonatomic, strong) NSNumber * created;
@property (nonatomic, strong) NSString * errorString;
@property (nonatomic, strong) NSNumber * averageObjectCount;
@property (nonatomic, strong) NSNumber * fieldIndex;
@property (nonatomic, strong) NSString * resourceURL;
@property (nonatomic, strong) NSNumber * surfMotionMetric;
@property (nonatomic, strong) NSNumber * videoDeleted;
@property (nonatomic, strong) NSOrderedSet *motionObjects;

@end
