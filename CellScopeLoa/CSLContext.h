//
//  CSLContext.h
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/10/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "TestRecord.h"

@interface CSLContext : NSObject

@property (nonatomic, strong) CLLocationManager* locationManager;

@property (strong, nonatomic) TestRecord* activeTestRecord;
@property (weak, nonatomic) CapillaryRecord* activeCapillaryRecord;
@property (strong, nonatomic) NSNumber* capillaryIndex;

- (void)startLocationUpdates;
- (NSString*)generateSimpleCSLIDWithRecord:(TestRecord*)record;
- (NSURL*)generateUniqueURLWithRecord:(TestRecord*)record;

@end
