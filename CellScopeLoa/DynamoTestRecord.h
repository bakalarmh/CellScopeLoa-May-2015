//
//  DynamoTestRecord.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 10/27/16.
//  Copyright © 2016 Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AWSDynamoDB/AWSDynamoDB.h>

@interface DynamoTestRecord : AWSDynamoDBObjectModel <AWSDynamoDBModeling>

@property (nonatomic, strong) NSString * boardUUID;
@property (nonatomic, strong) NSNumber * created;
@property (nonatomic, strong) NSString * deviceID;
@property (nonatomic, strong) NSNumber * latitude;
@property (nonatomic, strong) NSString * localTimeZone;
@property (nonatomic, strong) NSNumber * longitude;
@property (nonatomic, strong) NSNumber * objectsPerField;
@property (nonatomic, strong) NSNumber * objectsPerMl;
@property (nonatomic, strong) NSString * patientNIHID;
@property (nonatomic, strong) NSString * phoneIdentifier;
@property (nonatomic, strong) NSString * simplePhoneID;
@property (nonatomic, strong) NSString * simpleTestID;
@property (nonatomic, strong) NSString * state;
@property (nonatomic, strong) NSString * testNIHID;
@property (nonatomic, strong) NSString * testUUID;

@end
