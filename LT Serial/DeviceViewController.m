//
//  DeviceViewController.m
//  LT Serial
//
//  Created by PINWU KAO on 6/2/14.
//  Copyright (c) 2014 Laird Technologies. All rights reserved.
//

#import "DeviceViewController.h"
#import "ViewController.h"
#import "DeviceCellDetail.h"

@interface DeviceViewController ()
@property NSTimer     * scanTimer;
@end

@implementation DeviceViewController
{
    NSMutableArray *deviceNameArray;
    NSMutableArray *deviceRssiArray;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    NSLog(@"numberOfRowsInSection: %d", (int)[self.rootView.devicePerpArray count]);
    deviceNameArray = [[NSMutableArray alloc] init];
    deviceRssiArray = [[NSMutableArray alloc] init];
    for(NSInteger i = 0; i < [self.rootView.devicePerpArray count]; ++i)
    {
        CBPeripheral *peripheral = [self.rootView.devicePerpArray objectAtIndex:i];
        [deviceNameArray addObject:peripheral.name];
        [deviceRssiArray addObject:[self.rootView.deviceRssiArray objectAtIndex:i]];
    }
    
    self.selectedRow = -1;
    self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                      target:self
                                                    selector:@selector( updateNewDevice:)
                                                    userInfo:nil
                                                     repeats:YES ];
}

- (void) viewWillDisappear:(BOOL)animated
{
    if(self.scanTimer)
    {
        [self.scanTimer invalidate];
        self.scanTimer = nil;
    }
    
    if(self.selectedRow >= 0)
        [self.rootView makeBtConnection:self.selectedRow];
    else
    {
        // [NSThread sleepForTimeInterval:0.1];
        [self.rootView stopBtScan];
    }
}


- (void) updateNewDevice:(NSTimer *) theTimer
{
    NSInteger oldCount = [deviceNameArray count];
    NSInteger newCount = [self.rootView.devicePerpArray count];
    NSMutableArray *indexPaths = [NSMutableArray array];
    
    
    // Adding new devices information
    for(NSInteger i = oldCount; i < newCount; ++i)
    {
        [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        CBPeripheral *peripheral = [self.rootView.devicePerpArray objectAtIndex:i];
        [deviceNameArray addObject:peripheral.name];
        [deviceRssiArray addObject:[self.rootView.deviceRssiArray objectAtIndex:i]];
    }
    
    if(newCount > oldCount)
    {
        // tell the table view to update (at all of the inserted index paths)
        [self.tableView beginUpdates];
        [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
        [self.tableView endUpdates];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.rootView.devicePerpArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *myTableIdentifier = @"DeviceCellDetailID";
    // NSLog(@"numberOfRowsInSection: %d", [self.rootView.devicePerpArray count]);
    
    DeviceCellDetail *cell = [tableView dequeueReusableCellWithIdentifier:myTableIdentifier];
    
    if (cell == nil) {
        NSLog(@"cellForRowAtIndexPath 1: cell is nil");
        // cell = [[DeviceCellDetail alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:myTableIdentifier];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            cell = (DeviceCellDetail *)[DeviceCellDetail cellFromNibNamed:@"DeviceDetail_iPhone"];
        else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            cell = (DeviceCellDetail *)[DeviceCellDetail cellFromNibNamed:@"DeviceDetail_iPad"];
            // cell = (DeviceCellDetail *)[DeviceCellDetail cellFromNibNamed:@"DeviceDetail_iPhone"];
        if(cell == nil)
            NSLog(@"cellForRowAtIndexPath 2: cell is nil");
    }
    
    cell.deviceName.text = [deviceNameArray objectAtIndex:indexPath.row];
    cell.deviceRSSI.text = [deviceRssiArray objectAtIndex:indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.selectedRow = indexPath.row;
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)clearSelected:(id)sender {
    // This function is for "Cancel"
    self.selectedRow = -1;
    [self.navigationController popViewControllerAnimated:YES];
}

@end
