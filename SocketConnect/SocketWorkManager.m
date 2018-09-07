
//
//  SocketWorkManager.m
//  AutoTransaction
//
//  Created by llt on 2018/5/7.
//  Copyright © 2018年 ZQJ. All rights reserved.
//

#import "SocketWorkManager.h"
#import "GCDAsyncSocket.h"
#import "MJExtension.h"

@interface SocketWorkManager ()<GCDAsyncSocketDelegate>

@property (nonatomic, assign) BOOL connected;
@property (nonatomic, strong) GCDAsyncSocket *clientSocket; // 客户端socket
@property (nonatomic, strong) NSTimer *connectTimer; // 计时器
@property (nonatomic, copy) NSString *Type;
@property (nonatomic, strong) NSMutableData *readBuf;

@property (nonatomic, strong) NSMutableDictionary *mdict;

@end

@implementation SocketWorkManager

static SocketWorkManager *socketManager;

// 添加计时器
- (void)addTimer {
    // 长连接定时器
    self.connectTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(longConnectToSocket) userInfo:nil repeats:YES];
    // 把定时器添加到当前运行循环,并且调为通用模式
    [[NSRunLoop currentRunLoop] addTimer:self.connectTimer forMode:NSRunLoopCommonModes];
    [self.connectTimer fire];
}

// 心跳连接(根据后台参数要求传参就可以了)
- (void)longConnectToSocket {
    _mdict = [NSMutableDictionary new];
    _mdict[@"Type"] = _Type;
    _mdict[@"types"] = @"APP";
    _mdict[@"UserGuId"] = self.uId;
    NSData *jsdata = [_mdict mj_JSONData];
    [self.clientSocket writeData:jsdata withTimeout:- 1 tag:0];
}

+ (SocketWorkManager *)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        socketManager = [[self alloc] init];
    });
    return socketManager;
}

- (instancetype)init {
    if (self = [super init]) {
        _hostString = @"192.168.1.100";//后台给的ip
        _port = 8888;//后台给的端口
    }
    return self;
}

- (void)disconnectAction {
    [self.clientSocket disconnect];
    self.clientSocket.delegate = nil;
    self.clientSocket = nil;
    self.connected = NO;
}

- (void)connectAction {
    // 链接服务器
    if (!self.connected) {
        self.clientSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        NSLog(@"开始连接%@",self.clientSocket);
        
        NSError *error = nil;
        self.connected = [self.clientSocket connectToHost:_hostString onPort:_port viaInterface:nil withTimeout:-1 error:&error];
        
        if (self.connected) {
            [self showMessageWithStr:@"客户端尝试连接"];
        } else {
            self.connected = NO;
            [self showMessageWithStr:@"客户端未创建连接"];
        }
    } else {
        [self showMessageWithStr:@"与服务器连接已建立"];
    }
}

- (void)showMessageWithStr:(NSString *)str {
    NSLog(@"%@\n", str);
}

#pragma mark - GCDAsyncSocketDelegate
/**
 连接主机对应端口号
 
 @param sock 客户端socket
 @param host 主机
 @param port 端口号
 */
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    self.readBuf = [[NSMutableData alloc] init];
    
    [self showMessageWithStr:@"链接成功"];
    [self showMessageWithStr:[NSString stringWithFormat:@"服务器IP: %@-------端口: %d", host,port]];
    
    self.connected = YES;
    _Type = @"LOGIN";
    [self addTimer];
    // 连接后,可读取服务器端的数据
    [self.clientSocket readDataWithTimeout:- 1 tag:0];
}

/**
 读取数据
 
 @param sock 客户端socket
 @param data 读取到的数据
 @param tag 当前读取的标记
 */
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
     //将数据存入缓存区
     [self.readBuf appendData:data];
     while (self.readBuf.length > 0) {
         //将消息转化成byte，计算总长度 = 数据的内容长度 + 前面4个字节的头长度
         Byte *bytes = (Byte *)[self.readBuf bytes];
         NSUInteger allLength = (bytes[0]<<24) + (bytes[1]<<16) + (bytes[2]<<8) + bytes[3];
         
         //缓存区的长度大于总长度，证明有完整的数据包在缓存区，然后进行处理
         /*
          <0000004a 7b22436f 6465223a 3530302c 224d7367 223a22e5 aea2e688 b7e7abaf 55736572 47754964 e7bc93e5 86b2e987 8ce99da2 e4b88de5 ad98e59c a8222c22 54797065 223a224c 4f47494e 227d>
          上面是socket返回的数据，0000004a代表着返回有用数据的长度4*16 + 10 = 74个字节（1字节为2^8, 所以 7b22436f 代表四个字节），不包括0000004a.
          */
         if (self.readBuf.length >= allLength + 4) {
             NSMutableData *msgData = [[self.readBuf subdataWithRange:NSMakeRange(0, allLength + 4)] mutableCopy];
             //提取出前面4个字节的头内容，之所以提取出来，是因为在处理数据问题的时候，比如data转json的时候，头内容里面包含非法字符，会导致转化出来的json内容为空，所以要先去掉再处理数据问题
             [msgData replaceBytesInRange:NSMakeRange(0, 4) withBytes:NULL length:0];
             
             NSString *text = [[NSString alloc]initWithData:msgData encoding:NSUTF8StringEncoding];
             [self showMessageWithStr:text];
             //开始处理数据问题
             [self.clientSocket readDataWithTimeout:-1 tag:0];

             NSDictionary *dict = [msgData mj_JSONObject];
                 NSLog(@"0000 --- %@", dict);
             
             if ([[NSString stringWithFormat:@"%@", dict[@"Code"]] isEqualToString:@"0"]) {
                 _Type = @"PING";

             }
             //处理完数据后将处理过的数据移出缓存区
             _readBuf = [NSMutableData dataWithData:[_readBuf subdataWithRange:NSMakeRange(allLength + 4, _readBuf.length - (allLength + 4))]];
         } else {
             //缓存区内数据包不是完整的，再次从服务器获取数据，中断while循环
             [self.clientSocket readDataWithTimeout:-1 tag:0];
             break;//中断本次循环，继续从后台获取数据。
            }
     }
//    [self.clientSocket readDataWithTimeout:-1 tag:0];
//    [self.clientSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
//    [self.clientSocket readDataToData:[NSData dataWithBytes:"\x7D" length:1] withTimeout:-1 tag:0];
}


- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    
}

/**
 客户端socket断开
 
 @param sock 客户端socket
 @param err 错误描述
 */
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    [self showMessageWithStr:@"断开连接"];
    self.clientSocket.delegate = nil;
    self.clientSocket = nil;
    self.connected = NO;
    [self.connectTimer invalidate];
    self.connectTimer = nil;
}

@end
