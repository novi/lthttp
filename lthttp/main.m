//
//  main.m
//  lthttp
//
//  Created by ito on 2012/10/20.
//  Copyright (c) 2012年 novi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LTHTTP.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        LTHTTP* http = [LTHTTP httpWithPort:2000];
        [http start];
        
        if (http.isRunning) {
            dispatch_main();
        }
        
    }
    return 0;
}

