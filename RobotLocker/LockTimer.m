//
//  LockTimer.m
//  AVTest
//
//  Created by shen on 2017/12/22.
//  Copyright © 2017年 EncircleCloud. All rights reserved.
//

#import "LockTimer.h"

@implementation LockTimer

NSTimeInterval timeInterval = 10.0;

//构造方法
-(id)initWithGap:(float)gap block:(void (^)(NSTimer *timer))block{
    if(self=[super init]){
        timeInterval = gap;
        NSLog(@"time%f",gap);
        
        
        // 定时器
        self._timer = [NSTimer scheduledTimerWithTimeInterval:gap repeats:true block:block];
    
    }
    
    return self;
    
}

//selector:@selector(handleTimer:)
// 触发事件
- (void)handleTimer:(NSTimer *)theTimer
{
    NSDateFormatter *dateFormator = [[NSDateFormatter alloc] init];
    dateFormator.dateFormat = @"yyyy-MM-dd  HH:mm:ss";
    NSString *date = [dateFormator stringFromDate:[NSDate date]];
    NSLog(@"handleTimer %@", date);
    
    [self sleepMac];
}
-(void)startTimer{
    // 停止timer
    NSLog(@"startTimer");
//    [self._timer fire];
}
-(void)stopTimer{
    // 停止timer
    NSLog(@"stopTimer");
    if ([self._timer isValid])
    {
        [self._timer invalidate];
    }
}

-(void) runSystemCommand:(NSString*) cmd
{
    [[NSTask launchedTaskWithLaunchPath:@"/bin/sh"
                              arguments:@[@"-c", cmd]]
     waitUntilExit];
}
-(void) sleepMac{
    [self runSystemCommand:@"echo 123"];
    
    NSString* cmd = @"/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend";
    [self runSystemCommand:cmd];

    [self stopTimer];
}


@end
