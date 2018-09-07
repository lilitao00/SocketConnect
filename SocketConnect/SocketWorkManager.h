//
//  SocketWorkManager.h
//  AutoTransaction
//
//  Created by llt on 2018/5/7.
//  Copyright © 2018年 ZQJ. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SocketWorkManager : NSObject

@property (nonatomic, copy) NSString *uId;

@property (nonatomic, copy) NSString *hostString;
@property (nonatomic, assign) NSInteger port;


+ (SocketWorkManager *)sharedInstance;

- (void)connectAction;

- (void)disconnectAction;

@end
