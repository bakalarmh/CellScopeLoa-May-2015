//
//  BluetoothLoaDevice.m
//  CellScopeLoa
//
//  Created by Mike D'Ambrosio on 5/8/14.
//  Copyright (c) 2014 Matthew Bakalar. All rights reserved.
//

#import "BluetoothLoaDevice.h"

@implementation BluetoothLoaDevice {
    int currentPos;
    int servoStep;
    BOOL batteryQuery;
}

@synthesize bleManager;
@synthesize ble;

- (id)initWithBLEManager:(BLEManager*)manager
{
    self = [super init];
    self.bleManager = manager;
    self.ble = manager.ble;
    // Default advance step for the servo
    servoStep = 15;
    
    batteryQuery = NO;
    
    return self;
}

- (void)LEDOn
{
    UInt8 buf[3] = {0x05, 0x00, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
}

- (void)LEDOff
{
    UInt8 buf[3] = {0x06, 0x00, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
}

- (void)iled1Toggle:(int) on
{ //not ready to be used yet
    if (on==1) {
        UInt8 buf[3] = {0x07, 0x01, 0x00};
        NSData *data = [[NSData alloc] initWithBytes:buf length:3];
        [ble write:data];
    }
    else {
        UInt8 buf[3] = {0x07, 0x00, 0x00};
        NSData *data = [[NSData alloc] initWithBytes:buf length:3];
        [ble write:data];
    }
}

- (void)iled2Toggle:(int) on {
    if (on==1) {
        UInt8 buf[3] = {0x08, 0x01, 0x00};
        NSData *data = [[NSData alloc] initWithBytes:buf length:3];
        [ble write:data];
    }
    else {
        UInt8 buf[3] = {0x08, 0x00, 0x00};
        NSData *data = [[NSData alloc] initWithBytes:buf length:3];
        [ble write:data];
    }
}

- (void)iled3Toggle:(int) on {
    if (on==1) {
        UInt8 buf[3] = {0x09, 0x01, 0x00};
        NSData *data = [[NSData alloc] initWithBytes:buf length:3];
        [ble write:data];
    }
    else {
        UInt8 buf[3] = {0x09, 0x00, 0x00};
        NSData *data = [[NSData alloc] initWithBytes:buf length:3];
        [ble write:data];
    }
}

- (void)ledPulse:(int) iledNum:(float) onTime: (NSNumber *) numPulse { //iledNum can be 1, 2, or 3.
    if (iledNum==1) {
        NSNumber *stopNum = [NSNumber numberWithInt:numPulse];
        NSNumber *currNum = [NSNumber numberWithInt:0];
        
        NSArray* timerInfo = [NSArray arrayWithObjects:currNum ,stopNum,nil];
        
        NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:iledNum
                                                          target:self
                                                        selector:@selector(handleIled1Timer:)
                                                        userInfo:timerInfo repeats:NO];
    }
}

- (void)handleIled1Timer:(NSTimer*)iled1Timer {
    //NSLog (@"Got the string: %@", (NSString*)[iled1Timer userInfo]);
}

- (void)servoPowerUp
{
    UInt8 buf[3] = {0x13, 0x00, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
}

- (void)servoPowerDown
{
    UInt8 buf[3] = {0x14, 0x00, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
}

- (void)servoSync
{
    UInt8 buf[3] = {0x17, 0x00, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
}

- (void)servoMoveToPos:(int)pos
{
    UInt8 buf[3] = {0x15, 0x00, 0x00};
    buf[1]= pos;
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
    currentPos = pos;
}

- (void)servoLoadPosition
{
    [self servoMoveToPos:25];
    [self servoPowerUp];
    [self servoSync];
    [self servoPowerDown];
}

- (void)servoAdvance
{
    
    int testPos = currentPos + servoStep;
    if (testPos > 137) {
        NSLog(@"Servo is at maximum position");
    }
    else {
        [self servoMoveToPos:testPos];
        [self servoPowerUp];
        [self servoSync];
        [self servoPowerDown];
        currentPos = testPos;
    }
}

- (void)queryBattery
{
    UInt8 buf[3] = {0x10, 0x00, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
    batteryQuery = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end