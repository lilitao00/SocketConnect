//
//  ViewController.m
//  SocketConnect
//
//  Created by llt on 2018/9/6.
//  Copyright © 2018年 LLT. All rights reserved.
//

#import "ViewController.h"
#import "SocketWorkManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [SocketWorkManager sharedInstance].uId = @"test";
    [[SocketWorkManager sharedInstance] connectAction];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
