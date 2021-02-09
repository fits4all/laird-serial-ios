//
//  DeviceCellDetail.m
//  LT Serial
//
//  Created by PINWU KAO on 6/2/14.
//  Copyright (c) 2014 Laird Technologies. All rights reserved.
//

#import "DeviceCellDetail.h"

@implementation DeviceCellDetail

@synthesize deviceName = _deviceName;
@synthesize deviceRSSI = _deviceRSSI;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

+ (DeviceTableViewCell *)cellFromNibNamed:(NSString *)nibName {
    
    NSArray *nibContents = [[NSBundle mainBundle] loadNibNamed:nibName owner:self options:NULL];
    NSEnumerator *nibEnumerator = [nibContents objectEnumerator];
    DeviceTableViewCell *xibBasedCell = nil;
    NSObject* nibItem = nil;
    
    while ((nibItem = [nibEnumerator nextObject]) != nil) {
        if ([nibItem isKindOfClass:[DeviceTableViewCell class]]) {
            xibBasedCell = (DeviceTableViewCell *)nibItem;
            break; // we have a winner
        }
    }
    
    return xibBasedCell;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
