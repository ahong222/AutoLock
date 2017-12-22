//
//  LockTimer.h
//  AVTest
//
//  Created by shen on 2017/12/22.
//  Copyright © 2017年 EncircleCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LockTimer : NSObject

@property NSTimer* _timer;

-(id)initWithGap:(float)gap block:(void (^)(NSTimer *timer))block;
-(void)startTimer;
@end
