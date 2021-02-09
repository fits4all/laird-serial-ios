//
//  DeviceCellDetail.h
//  LT Serial
//
//  Created by PINWU KAO on 6/2/14.
//  Copyright (c) 2014 Laird Technologies. All rights reserved.
//

#import "DeviceTableViewCell.h"

@interface DeviceCellDetail : DeviceTableViewCell
+(UITableViewCell *) cellFromNibNamed:(NSString *)nibName;

@property (weak, nonatomic) IBOutlet UILabel *deviceName;
@property (weak, nonatomic) IBOutlet UILabel *deviceRSSI;

@end
