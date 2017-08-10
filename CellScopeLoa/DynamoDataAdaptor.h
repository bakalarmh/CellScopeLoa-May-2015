//
//  DynamoDataAdaptor.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 10/27/16.
//  Copyright © 2016 Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TestRecord.h"
#import "CapillaryRecord.h"

@interface DynamoDataAdaptor : NSObject

+ (void)syncTestRecord:(TestRecord*)record WithBlock:(void (^)(BOOL, NSError*))completionBlock;
+ (void)syncVideosForCapillaryRecords:(NSArray*)records withBlock:(void (^)(BOOL, NSError*))completionBlock;


@end
