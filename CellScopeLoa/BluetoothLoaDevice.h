//
//  BluetoothStage.h
//  CellScopeLoa
//
//  Created by Mike D'Ambrosio on 5/8/14.
//  Copyright (c) 2014 Matthew Bakalar. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLE.h"
#import "BLEManager.h"

@interface BluetoothLoaDevice : UIViewController

@property (weak, nonatomic) BLEManager* bleManager;
@property (weak, nonatomic) BLE* ble;

- (id)initWithBLEManager:(BLEManager*)manager;

-(BOOL) connected;
-(void) connectBLE;
-(void) servoPowerUp;
-(void) servoPowerDown;
-(void) servoMoveToPos:(int)pos;
-(void) servoReturn;
-(void) servoAdvance;
-(void) servoSync;
-(void) servoLock;
-(void) servoUnlock;
-(void) servoLoadPosition;
-(void) servoConfigure:(int) fields;
-(void) LEDOn;
-(void) LEDOff;
-(void) iled1Toggle:(int) on; //1 for on, 0 for off. I hate booleans.
-(void) iled2Toggle:(int) on;
-(void) iled3Toggle:(int) on;
-(void) ledPulse:(int) iledNum:(float) onTime: (NSNumber *) numPulse; //iledNum can be 1, 2, or 3.
-(void) queryBattery;

@end