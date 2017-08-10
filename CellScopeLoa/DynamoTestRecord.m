//
//  DynamoTestRecord.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 10/27/16.
//  Copyright © 2016 Fletcher Lab. All rights reserved.
//

#import "DynamoTestRecord.h"
#import <AWSDynamoDB/AWSDynamoDB.h>

@implementation DynamoTestRecord

+ (NSString *)dynamoDBTableName {
    return @"CSLTestRecords";
}

+ (NSString *)hashKeyAttribute {
    return @"testUUID";
}

@end
