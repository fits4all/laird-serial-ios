//
//  ViewController.h
//  nRF UART
//
//  Created by Ole Morten on 1/11/13.
//  Copyright (c) 2013 Nordic Semiconductor. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "UARTPeripheral.h"

#define MAX_SCAN_DEVICES  10
#define MAX_SCAN_TIME     10
#define MIN_SCAN_TIME      5

@interface ViewController : UIViewController <UITextFieldDelegate, CBCentralManagerDelegate, UARTPeripheralDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *myNavigationBar;
@property (weak, nonatomic) IBOutlet UITextView *consoleTextView;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UITextField *sendTextField;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;
@property (weak, nonatomic) IBOutlet UISwitch *plusEnter;
@property (weak, nonatomic) IBOutlet UILabel *labelPlusEnter;
@property (weak, nonatomic) IBOutlet UILabel *labelVersion;
@property (weak, nonatomic) IBOutlet UIButton *clearButton;
@property (weak, nonatomic) IBOutlet UIButton *aboutButton;

@property (nonatomic, strong) NSMutableArray  *devicePerpArray;
@property (nonatomic, strong) NSMutableArray  *deviceRssiArray;
@property unsigned int        rcvTimerCount;
@property unsigned int        scanComplete;
@property UIColor     *myRedColor;
@property UIColor     *myBlueColor;
@property UIColor     *myGreenColor;
@property NSUInteger   isConnectButtonBusy;

- (IBAction)clearConsole:(id)sender;
- (IBAction)aboutButtonPressed:(id)sender;
- (IBAction)plusCarriageReturn:(id)sender;
- (IBAction)connectButtonPressed:(id)sender;
- (IBAction)sendButtonPressed:(id)sender;
- (IBAction)sendTextFieldEditingDidBegin:(id)sender;
- (IBAction)sendTextFieldEditingChanged:(id)sender;

- (void) makeBtConnection:(NSInteger)index;
- (void) stopBtScan;

@end
