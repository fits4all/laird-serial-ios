//
//  DeviceViewController.h
//  LT Serial
//
//  Created by PINWU KAO on 6/2/14.
//  Copyright (c) 2014 Laird Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ViewController;

@interface DeviceViewController : UIViewController
@property NSInteger selectedRow;

@property (nonatomic, strong) ViewController *rootView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

- (IBAction)clearSelected:(id)sender;

@end
