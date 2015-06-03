//
//  BLEManager.m
//  CellScopeLoa
//
//  Created by Matthew Bakalar on 5/10/15.
//  Copyright (c) 2015 Fletcher Lab. All rights reserved.
//

#import "BLEManager.h"
#import "constants.h"

@implementation BLEManager {
    int bluetoothState;
    BOOL seeking;
}

@synthesize ble;
@synthesize mDevices;
@synthesize mDevicesName;
@synthesize mPeripherals;
@synthesize delegate;
@synthesize lastUUID;
@synthesize connected;

int const BluetoothPowered = 5;

- (id)init
{
    // Set up the BLE device
    ble = [[BLE alloc] init];
    [ble controlSetup];
    ble.delegate = self;
    
    bluetoothState = 0;
    connected = NO;
    seeking = NO;
    
    mDevices = [[NSMutableArray alloc] init];
    mDevicesName = [[NSMutableArray alloc] init];
    mPeripherals = [[NSMutableArray alloc] init];
    
    lastUUID = [[NSUserDefaults standardUserDefaults] objectForKey:UUIDPrefKey];
    
    return self;
}

- (void)seekDevices
{
    if (!seeking) {
        // [self clearConnections];
        [mDevices removeAllObjects];
        [mDevicesName removeAllObjects];
        [mPeripherals removeAllObjects];
        
        if (ble.peripherals)
            ble.peripherals = nil;
        [ble findBLEPeripherals:3];
        
        int delayms = 1000;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayms * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            for (int i = 0; i < ble.peripherals.count; i++)
            {
                CBPeripheral *p = [ble.peripherals objectAtIndex:i];
                if (p.identifier != NULL)
                {
                    NSUUID* pid = p.identifier;
                    [mDevices insertObject:pid.UUIDString atIndex:i];
                    [mPeripherals insertObject:p atIndex:i];
                }
            }
            [delegate didUpdateDevices];
            seeking = NO;
        });
    }
}

- (void)clearConnections
{
    if (ble.activePeripheral) {
        if(ble.activePeripheral.state == CBPeripheralStateConnected)
        {
            [[ble CM] cancelPeripheralConnection:[ble activePeripheral]];
            return;
        }
    }
}

- (void)storeDefaultUUID:(NSString*)newUUID
{
    [[NSUserDefaults standardUserDefaults] setObject:newUUID forKey:UUIDPrefKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    lastUUID = newUUID;
}

- (void)connectWithUUID:(NSString*)UUID
{
    for (int i = 0; i < mDevices.count; i++) {
        if ([[mDevices objectAtIndex:i] isEqualToString:UUID]) {
            CBPeripheral *p = (CBPeripheral*)[mPeripherals objectAtIndex:i];
            [ble connectPeripheral:p];
        }
    }
}

- (void)bleDidConnect
{
    NSLog(@"->DidConnect");
    connected = YES;
    [delegate didConnect];
}

// Universal command for board to flash an indentifying sequence
- (void)identifyDevice
{
    // Turn on the main LED
    UInt8 buf[3] = {0x05, 0x00, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (ble.isConnected) {
            // Turn off the main LED
            UInt8 buf[3] = {0x06, 0x00, 0x00};
            NSData *data = [[NSData alloc] initWithBytes:buf length:3];
            [ble write:data];
        }
    });
}

// When data is coming, this will be called
- (void)bleDidReceiveData:(unsigned char *)data length:(int)length
{
    NSMutableArray* packets = [[NSMutableArray alloc] init];
    // parse data, all commands are in 3-byte
    for (int i = 0; i < length; i+=3)
    {
        [packets addObject:[NSData dataWithBytes:(void*)(data+i) length:3]];
    }
    [delegate bleDidReceiveData:packets];
}

- (void)bleDidDisconnect
{
    NSLog(@"->DidDisconnect");
    connected = NO;
    [delegate didDisconnect];
}

- (void)bleDidUpdateRSSI:(NSNumber *) rssi
{
    NSLog(@"Did update RSSI");
}

- (void)bleCoreBluetoothChange:(CBCentralManager*)manager
{
    [delegate bluetoothStateDidChange:manager.state];
}

-(NSString *)getUUIDString:(CFUUIDRef)ref {
    NSString *str = [NSString stringWithFormat:@"%@", ref];
    return [[NSString stringWithFormat:@"%@", str] substringWithRange:NSMakeRange(str.length - 36, 36)];
}


@end
