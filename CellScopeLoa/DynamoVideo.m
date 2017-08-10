//
//  DynamoVideo.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 10/30/16.
//  Copyright © 2016 Fletcher Lab. All rights reserved.
//

#import "DynamoVideo.h"

@implementation DynamoVideo

+ (NSString *)dynamoDBTableName {
    return @"CSLVideos2";
}

+ (NSString *)hashKeyAttribute {
    return @"URL";
}

@end
