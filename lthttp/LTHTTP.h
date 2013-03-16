//
//  LTHTTP.h
//  lthttp
//
//  Created by ito on 2012/10/20.
//  Copyright (c) 2012年 novi. All rights reserved.
//

#import <netinet/ip.h>
#import <Foundation/Foundation.h>

@interface LTHTTP : NSObject

@property (nonatomic) NSUInteger port;
@property (nonatomic, readonly) BOOL isRunning;

- (void)start;

+ (LTHTTP*)httpWithPort:(NSUInteger)port;

@end
