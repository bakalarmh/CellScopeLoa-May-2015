//
//  BluetoothStage.m
//  CellScopeLoa
//
//  Created by Mike D'Ambrosio on 5/8/14.
//  Copyright (c) 2014 Matthew Bakalar. All rights reserved.
//

#import "BluetoothStage.h"

@interface BluetoothStage ()

@end

@implementation BluetoothStage {
    int currentPos;
    int servoStep;
}

@synthesize ble;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(id)init {
    
    self = [super init];
    // Default advance step for the servo
    servoStep = 90/5;
    
    return self;
    
}
- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)servoReturn
{
    UInt8 buf[3] = {0x03, 0x00, 0x00};
    buf[1]= 32;
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
    currentPos = 32;
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

- (void)servoLoadPosition
{
    UInt8 buf[3] = {0x03, 0x00, 0x00};
    buf[1]= 30;
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
    currentPos = 30;
}

-(void) servoAdvance
{
    UInt8 buf[3] = {0x03, 0x00, 0x00};
    currentPos = currentPos + servoStep;
    buf[1] = currentPos;
    NSData *data = [[NSData alloc] initWithBytes:buf length:3];
    [ble write:data];
}

// When data is comming, this will be called
-(void) bleDidReceiveData:(unsigned char *)data length:(int)length
{
    NSLog(@"Length: %d", length);
    
    // parse data, all commands are in 3-byte
    for (int i = 0; i < length; i+=3)
    {
        NSLog(@"0x%02X, 0x%02X, 0x%02X", data[i], data[i+1], data[i+2]);
        
        if (data[i] == 0x0A)
        {
            //if (data[i+1] == 0x01)
            //swDigitalIn.on = true;
            //else
            //swDigitalIn.on = false;
        }
        else if (data[i] == 0x0B)
        {
            UInt16 Value;
            
            Value = data[i+2] | data[i+1] << 8;
            //lblAnalogIn.text = [NSString stringWithFormat:@"%d", Value];
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */


@end