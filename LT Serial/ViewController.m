//
//  ViewController.m
//  nRF UART
//
//  Created by Ole Morten on 1/11/13.
//  Copyright (c) 2013 Nordic Semiconductor. All rights reserved.
//

#import "ViewController.h"
#import "DeviceViewController.h"
#import "AboutViewController.h"

typedef enum
{
    IDLE = 0,
    SCANNING,
    CONNECTED,
} ConnectionState;

typedef enum
{
    LOGGING,
    RX,
    TX,
} ConsoleDataType;

@interface ViewController ()
@property CBCentralManager *cm;
@property ConnectionState state;
@property UARTPeripheral *currentPeripheral;

@property NSTimer          *receiveTimer;
@property NSMutableData    *receiveBuffer;
@property NSLock           *receiveLocker;
@end

@implementation ViewController
@synthesize cm = _cm;
@synthesize state = _state;
@synthesize currentPeripheral = _currentPeripheral;

@synthesize receiveTimer = _receiveTimer;
@synthesize receiveBuffer = _receiveBuffer;

@synthesize devicePerpArray = _devicePerpArray;
@synthesize deviceRssiArray = _deviceRssiArray;
@synthesize rcvTimerCount;
@synthesize scanComplete;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Define my own colors to match Android
    self.myRedColor = [UIColor colorWithRed:250/255.0 green:0/255.0 blue:0/255.0 alpha:1.0];
    self.myBlueColor = [UIColor colorWithRed:16/255.0 green:160/255.0 blue:244/255.0 alpha:1.0];
    self.myGreenColor = [UIColor colorWithRed:0/255.0 green:150/255.0 blue:0/255.0 alpha:1.0];
    
    //**************** Hide the navigation bar which is behind the image view ****************
    [[self navigationController] setNavigationBarHidden:YES animated:YES];
    [self.myNavigationBar setBackgroundColor:self.myBlueColor];
    
    /*
     if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
     [self.navigationController.navigationBar setBarTintColor:navColor];
     else
     [self.navigationController.navigationBar setTintColor:navColor];
     */
    
    //**************** Add a border and corner radius for 'Send' and 'Scan and Connect' buttons ****************
    // self.connectButton.layer.borderWidth = 0.5;
    // self.connectButton.layer.cornerRadius = 0;
    // self.sendButton.layer.borderWidth = 0.5;
    // self.sendButton.layer.cornerRadius = 0;
	
    self.cm = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    [self addTextToConsole:@"Touch Connect to make connection" dataType:LOGGING];
    
    self.receiveTimer = nil;
    self.receiveBuffer = nil;
    self.currentPeripheral = nil;
    _receiveLocker = [[NSLock alloc] init];
    
    // Check Device Platform
    // NSString *deviceModel = [[UIDevice currentDevice] model];
    // NSRange range = [deviceModel rangeOfString:@"iPhone"];
    // if(range.location != NSNotFound)
    
    NSDictionary *infoDictionary = [[NSBundle mainBundle]infoDictionary];
    NSString *build = infoDictionary[(NSString *)kCFBundleVersionKey];
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    NSString *versionBuild = @"  Version ";
    versionBuild = [versionBuild stringByAppendingString:version];
    versionBuild = [versionBuild stringByAppendingString:@"."];
    versionBuild = [versionBuild stringByAppendingString:build];
    [self.labelVersion setTextColor:self.myBlueColor];
    self.labelVersion.text = versionBuild;

    [self.sendButton setBackgroundColor:[UIColor whiteColor]];
    [self.sendButton setUserInteractionEnabled :NO];
    [self.sendTextField setReturnKeyType:UIReturnKeySend];
    [self.sendTextField setUserInteractionEnabled :NO];
    
    self.devicePerpArray = [[NSMutableArray alloc] init];
    self.deviceRssiArray = [[NSMutableArray alloc] init];
    [self.sendTextField setDelegate:self];
    self.consoleTextView.editable = NO;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.clearButton.layer.borderWidth = 1.5;
    self.aboutButton.layer.borderWidth = 1.5;
    [self.clearButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.aboutButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.clearButton setBackgroundColor:[UIColor whiteColor]];
    [self.aboutButton setBackgroundColor:[UIColor whiteColor]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)aboutButtonPressed:(id)sender {
    AboutViewController *aboutViewController;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        aboutViewController = [[AboutViewController alloc] initWithNibName:@"AboutView_iPhone" bundle:nil];
    else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        aboutViewController = [[AboutViewController alloc] initWithNibName:@"AboutView_iPad" bundle:nil];
    
    [self.navigationController pushViewController:aboutViewController animated:YES];
}

- (IBAction)clearConsole:(id)sender {
    self.consoleTextView.text = @"";   // Clear the Console screen
    _receiveBuffer = nil;
    if(self.currentPeripheral != nil) self.currentPeripheral.sendBuffer = nil;
}

- (IBAction)plusCarriageReturn:(id)sender {
    if([self.plusEnter isOn]) [self.labelPlusEnter setText:@"+CR"];
    else [self.labelPlusEnter setText:@"-CR"];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSLog(@"prepareForSegue 1:");
    
    if([segue.identifier isEqualToString:@"connectDevice"])
    {
    }
}

- (void) showDevices
{
    DeviceViewController *deviceViewController;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        deviceViewController = [[DeviceViewController alloc] initWithNibName:@"DeviceView_iPhone" bundle:nil];
    else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        deviceViewController = [[DeviceViewController alloc] initWithNibName:@"DeviceView_iPad" bundle:nil];
    
    deviceViewController.rootView = self;
    [self.navigationController pushViewController:deviceViewController animated:YES];
}

- (void)disconnectTimout:(NSTimer *) theTimer
{
    self.state = IDLE;
    [self.connectButton setTitle:@"Scan and Connect" forState:UIControlStateNormal];
    self.isConnectButtonBusy = 0;
}

- (IBAction)connectButtonPressed:(id)sender
{
    if(self.isConnectButtonBusy > 0) return;
    
    self.connectButton.enabled = NO;
    self.isConnectButtonBusy = 1;
    // [self.sendTextField resignFirstResponder];
    NSLog(@"connectButtonPressed 1:");
    
    switch (self.state) {
        case IDLE:
            self.state = SCANNING;
            NSLog(@"Started scan ...");
            [self.connectButton setTitle:@"Scanning ..." forState:UIControlStateNormal];
            
            if( [self. devicePerpArray count] > 0 )
            {
                [self.devicePerpArray removeAllObjects];
                [self.deviceRssiArray removeAllObjects];
            }
            
            [self.cm scanForPeripheralsWithServices:@[UARTPeripheral.uartServiceUUID] options:@{CBCentralManagerScanOptionAllowDuplicatesKey: [NSNumber numberWithBool:NO]}];
            [NSThread sleepForTimeInterval:0.2];
            [self showDevices];
            self.isConnectButtonBusy = 0;
            break;
            
        case SCANNING:
            self.state = IDLE;
            NSLog(@"Stopped scan");
            [self.cm stopScan];
            
            [NSThread sleepForTimeInterval:1];
            [self.connectButton setTitle:@"Scan and Connect" forState:UIControlStateNormal];
            self.isConnectButtonBusy = 0;
            break;
            
        case CONNECTED:
            NSLog(@"Disconnect peripheral %@", self.currentPeripheral.peripheral.name);
            [self.cm cancelPeripheralConnection:self.currentPeripheral.peripheral];
            
            // [NSThread sleepForTimeInterval:1];
            [self.connectButton setTitle:@"Disconnecting ..." forState:UIControlStateNormal];
            self.receiveTimer = [NSTimer scheduledTimerWithTimeInterval:10
                                                                 target:self
                                                               selector:@selector(disconnectTimout:)
                                                               userInfo:nil
                                                                repeats:NO];
            break;
    }
    
    self.connectButton.enabled = YES;
}

- (void) connectSelectedDevice:(NSInteger)index
{
    if( index >= 0 && index < [self. devicePerpArray count] )
    {
        CBPeripheral * peripheral = self.devicePerpArray[index];
        self.currentPeripheral = [[UARTPeripheral alloc] initWithPeripheral:peripheral delegate:self];
        NSLog(@"Connecting to peripheral %@", peripheral.name);
        [self.cm connectPeripheral:peripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey: [NSNumber numberWithBool:YES]}];
    }
}

- (void) getNumDevices:(NSInteger *)numDevices
{
    *numDevices = [self.devicePerpArray count];
}

- (void) getDeviceData:(NSInteger)index rtDeviceName:(NSString **)deviceName rtRSSI:(NSInteger *)rssi
{
    *deviceName = nil;
    rssi = nil;
    
    
    if( index > 0 && index < [self. devicePerpArray count] )
    {
        CBPeripheral * peripheral = self.devicePerpArray[index];
        *deviceName = peripheral.name;
        *rssi = self.deviceRssiArray[index];
    }
}

- (IBAction)sendTextFieldEditingDidBegin:(id)sender {
}

- (IBAction)sendTextFieldEditingChanged:(id)sender {
    // Warning length was changed from 20 to 124
    if (self.sendTextField.text.length > 124)
    {
        [self.sendTextField setBackgroundColor:[UIColor redColor]];
    }
    else
    {
        [self.sendTextField setBackgroundColor:[UIColor whiteColor]];
    }
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
    [self sendButtonPressed:textField];

    [self.sendTextField resignFirstResponder];
    return YES;
}

- (IBAction)sendButtonPressed:(id)sender {
    static int is_previous_off = 0;
    
    [self.sendTextField resignFirstResponder];
    
    if (self.sendTextField.text.length == 0)
    {
        return;
    }
    
    if(is_previous_off == 0)
        [self addTextToConsole:@"\n************\n" dataType:TX];
    else
    {
        is_previous_off = 0;
        [self addTextToConsole:@"\n" dataType:TX];
    }

    [self addTextToConsole:self.sendTextField.text dataType:TX];
    [self addTextToConsole:@"\n" dataType:TX];
    
    NSString *string1 = [NSString stringWithString:self.sendTextField.text];
    if([self.plusEnter isOn])
    {
        string1 = [string1 stringByAppendingString:@"\r"];
    }
    else
        is_previous_off = 1;

    [self.currentPeripheral writeString:string1];
    self.sendTextField.text = @"";
}

- (void) didReadHardwareRevisionString:(NSString *)string
{
    [self addTextToConsole:[NSString stringWithFormat:@"Hardware revision: %@", string] dataType:LOGGING];
}

// Added and modified end on 5/24/2014

- (void) addTextToConsole:(NSString *) string dataType:(ConsoleDataType) dataType
{
    static bool fLastWasLog=true;
    if(dataType == LOGGING)
    {
        NSString *format;
        if(fLastWasLog)
        {
            format = @"#: %@\n";
        }
        else
        {
            format = @"\n#: %@\n";
        }
        [self.consoleTextView setText:[self.consoleTextView.text stringByAppendingFormat:format, string]];
        fLastWasLog=true;
    }
    else
    {
        [self.consoleTextView setText:[self.consoleTextView.text stringByAppendingFormat:@"%@",string]];
        fLastWasLog=false;
    }

    // Scroll down to the last line
    NSInteger len = [self.consoleTextView.text length];
    if(len > 10)
    {
        // [self.consoleTextView scrollRangeToVisible:NSMakeRange(len - 1, 1)];
        // self.consoleTextView.scrollEnabled = NO;
        // self.consoleTextView.scrollEnabled = YES;
    }
}

- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        [self.connectButton setEnabled:YES];
    }
    
}

- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Did discover peripheral 1: %@", peripheral.name);
    NSString  *deviceRssi = [NSString stringWithFormat:@"%@", RSSI];
    [self.devicePerpArray addObject:peripheral];
    [self.deviceRssiArray addObject:deviceRssi];
}


- (void) makeBtConnection:(NSInteger)index
{
    [self.cm stopScan];
    [NSThread sleepForTimeInterval:0.5];
    CBPeripheral *peripheral = [self.devicePerpArray objectAtIndex:index];
    self.currentPeripheral = [[UARTPeripheral alloc] initWithPeripheral:peripheral delegate:self];
    
    
    [self.connectButton setTitle:@"Connecting ..." forState:UIControlStateNormal];
    // If not connected in 5 seconds, should stop doing it
    self.receiveTimer = [NSTimer scheduledTimerWithTimeInterval:20
                                                         target:self
                                                       selector:@selector(connectTimout:)
                                                       userInfo:nil
                                                        repeats:NO];
    
    [self.cm connectPeripheral:peripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey: [NSNumber numberWithBool:YES]}];
}

- (void)connectTimout:(NSTimer *) theTimer
{
    [self.cm cancelPeripheralConnection:self.currentPeripheral.peripheral];
    self.state = IDLE;
    [self.connectButton setTitle:@"Scan and Connect" forState:UIControlStateNormal];
}

- (void) stopBtScan
{
    [self.cm stopScan];
    [NSThread sleepForTimeInterval:0.5];
    self.state = IDLE;
    [self.connectButton setTitle:@"Scan and Connect" forState:UIControlStateNormal];
}

- (void)killReceiveTimer
{
    if(self.receiveTimer)
    {
        [self.receiveTimer invalidate];
        self.receiveTimer = nil;
    }
}

- (int) getCompleteUTF8Length
{
    int len = (int)[_receiveBuffer length];
    int rlen = len;
    uint8_t * bytePtr = (uint8_t *)[_receiveBuffer bytes];
    
    for(int i = len - 1; i >= 0; --i)
    {
        if(bytePtr[i] & 0x80)
        {
            if(bytePtr[i] & 0x40)
            {
                if(bytePtr[i] & 0x20)
                {
                    if(bytePtr[i] & 0x10)
                    {
                        if( (len - i) >= 4 ) rlen = i + 4;
                        else rlen = i;
                        break;
                    }
                    else
                    {
                        if( (len - i) >= 3 ) rlen = i + 3;
                        else rlen = i;
                        break;
                    }
                }
                else
                {
                    if( (len - i) >= 2 ) rlen = i + 2;
                    else rlen = i;
                    break;
                }
            }
        }
        else
        {
            rlen = i + 1;
            break;
        }
    }
    
    return rlen;
}

// Added and modified for receiving data on 5/24/2014
- (void) updateReceivingConsole:(NSTimer *) theTimer
{
    if(_receiveBuffer != nil)
    {
        int len = (int)_receiveBuffer.length;
        if(len > 0)
        {
            NSDate *curdate = [NSDate date];
            NSDate *timeout = [curdate dateByAddingTimeInterval:10];   // 10 seconds timeout
            BOOL bResult = [_receiveLocker lockBeforeDate:timeout];
            
            if(bResult == YES)
            {
                NSString *string = nil;
                // Check the complete UTF8 data length
                // If not complete, should leave data in the buffer
                int len1 = [self getCompleteUTF8Length];
                // int len1 = len;
                
                if(len1 > 0)
                {
                    NSRange range = NSMakeRange(0, len1);
                    NSData *data = [_receiveBuffer subdataWithRange:range];
                    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    [_receiveBuffer replaceBytesInRange:range withBytes:NULL length:0];
                    if(string == nil)
                    {
                        string = [NSString stringWithFormat:@"%@", data];
                    }
                    
                    // NSLog(@"-> %@" , data);
                    // NSLog(@"=> %@" , string);
                }
                [_receiveLocker unlock];
                
                if(string != nil)
                {
                    [self addTextToConsole:string dataType:RX];
                }
            }
        }
    }
}

- (void) didReceiveData:(NSData *)data
{
    NSDate *curdate = [NSDate date];
    NSDate *timeout = [curdate dateByAddingTimeInterval:10];   // 10 seconds timeout
    BOOL bResult = [_receiveLocker lockBeforeDate:timeout];
    
    if(bResult == YES)
    {
        if(_receiveBuffer == nil)
            _receiveBuffer = [[NSMutableData alloc] initWithData:data];
        else
            [_receiveBuffer appendData:data];
        
        [_receiveLocker unlock];
    }
}

- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Did connect peripheral %@", peripheral.name);

    [self addTextToConsole:[NSString stringWithFormat:@"Connected to %@", peripheral.name] dataType:LOGGING];
    
    self.state = CONNECTED;
    [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
    [self.sendButton setBackgroundColor:[UIColor lightGrayColor]];
    [self.sendButton setUserInteractionEnabled:YES];
    [self.sendTextField setUserInteractionEnabled:YES];
    [self killReceiveTimer];
    
    if ([self.currentPeripheral.peripheral isEqual:peripheral])
    {
        _receiveBuffer = nil;
        self.currentPeripheral.sendBuffer = nil;
        [self.currentPeripheral didConnect];
        
        self.receiveTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                     target:self
                                     selector:@selector(updateReceivingConsole:)
                                     userInfo:nil
                                     repeats:YES ];
    }
}

- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Did disconnect peripheral %@", peripheral.name);
    
    [self addTextToConsole:[NSString stringWithFormat:@"Disconnected from %@", peripheral.name] dataType:LOGGING];
    
    // self.connectButton.enabled = NO;
    self.state = IDLE;
    [self.connectButton setTitle:@"Scan and Connect" forState:UIControlStateNormal];
    // self.connectButton.enabled = YES;

    [self.sendButton setBackgroundColor:[UIColor whiteColor]];
    [self.sendButton setUserInteractionEnabled:NO];
    self.sendTextField.text = @"";
    [self.sendTextField setUserInteractionEnabled:NO];
    
    if (self.currentPeripheral != nil && [self.currentPeripheral.peripheral isEqual:peripheral])
    {
        [self.currentPeripheral didDisconnect];
        [self killReceiveTimer];
        self.currentPeripheral = nil;
    }

    [NSThread sleepForTimeInterval:0.2];
    self.isConnectButtonBusy = 0;
}

@end
