//
//  LTHTTP.m
//  lthttp
//
//  Created by ito on 2012/10/20.
//  Copyright (c) 2012年 novi. All rights reserved.
//

#import "LTHTTP.h"

@interface LTHTTPConnection : NSObject

- (id)initWithSocket:(int)socket ioQueue:(dispatch_queue_t)queue;
- (void)close;

@end

@interface LTHTTPConnection ()
{
    int _socket;
    BOOL _isOpend;
    dispatch_queue_t _ioQueue;
    dispatch_io_t _io;
    dispatch_source_t _source;
}
@end

@implementation LTHTTPConnection

-(id)initWithSocket:(int)socket ioQueue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self) {
        _socket = socket;
        _isOpend = YES;
        _ioQueue = queue;
        
        _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, _socket, 0, _ioQueue);
        dispatch_source_set_event_handler(_source, ^{
            unsigned long size = dispatch_source_get_data(_source);
            //NSLog(@"read size %zd", size);
            if (size == 0) {
                dispatch_source_cancel(_source);
                return;
            }
            uint8_t* bytes = malloc(sizeof(uint8_t)*size);
            ssize_t readsize = read(_socket, bytes, size);
            if (0 < readsize) {
                if (readsize == size) {
                    // EOF
                    NSData* data = [NSData dataWithBytesNoCopy:bytes length:readsize freeWhenDone:YES];
                    //NSLog(@"1 %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                    //dispatch_source_cancel(_source);
                    
                    NSString* message = @"Hello World";
                    NSString* out = [NSString stringWithFormat:@"HTTP/1.0 200 OK\r\n" \
                                     "Content-Type: text/html\r\n" \
                                     "Content-Length: %ld\r\n" \
                                     "\r\n%@", message.length, message];
                    NSData* outData = [out dataUsingEncoding:NSUTF8StringEncoding];
                    write(_socket, [outData bytes], [outData length]);
                    
                } else {
                    
                }
            } else {
                // error
                dispatch_source_cancel(_source);
            }
        });
        
        dispatch_source_set_cancel_handler(_source, ^{
            [self close];
        });
        
        dispatch_resume(_source);
        /*_io = dispatch_io_create(DISPATCH_IO_STREAM, _socket, _ioQueue, ^(int error) {
            NSLog(@"io error, %d", error);
            [self close];
        });
        dispatch_io_set_low_water(_io, SIZE_MAX);
        dispatch_io_read(_io, 0, SIZE_MAX, _ioQueue, ^(bool done, dispatch_data_t data, int error) {
            NSLog(@"done %d, %@, %d", done, data, error);
            if (dispatch_data_get_size(data) > 0) {
                dispatch_data_apply(data, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
                    NSData* data = [NSData dataWithBytes:buffer length:size];
                    NSLog(@"2 %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                    return true;
                });
            }
        });*/
         
    }
    return self;
}

-(void)close
{
    if (_isOpend) {
        //NSLog(@"closed %d", _socket);
        close(_socket);
    }
}

-(void)dealloc
{
    [self close];
    NSLog(@"dealloc %@", self);
    //dispatch_release(_io);
}

@end

#pragma mark -

@interface LTHTTP ()
{
    int _listenSocket;
    NSMutableArray* _connections;
    dispatch_queue_t _acceptQueue;
    dispatch_queue_t _ioQueue;
}

@end

@implementation LTHTTP


+(LTHTTP *)httpWithPort:(NSUInteger)port
{
    LTHTTP* http = [[self alloc] init];
    http.port = port;
    return http;
}

- (id)init
{
    self = [super init];
    if (self) {
        _ioQueue = dispatch_queue_create("io queue", 0);
        _acceptQueue = dispatch_queue_create("listen queue", 0);
    }
    return self;
}

- (void)waitForAccept
{
    dispatch_async(_acceptQueue, ^{
        struct sockaddr_in client;
        socklen_t len = sizeof(client);
        int sock = accept(_listenSocket, (struct sockaddr *)&client, &len);
        int result = fcntl(sock, F_SETFL, O_NONBLOCK);
        if (result < 0) {
            NSLog(@"error fcntl(sock, F_SETFL, O_NONBLOCK ");
            close(sock);
            [self waitForAccept];
            return;
        }
        int nosigpipe = 1;
        setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, sizeof(nosigpipe));
        
        //NSLog(@"accepted %d", sock);
        LTHTTPConnection* conn = [[LTHTTPConnection alloc] initWithSocket:sock ioQueue:_ioQueue];
        [_connections addObject:conn];
        [self waitForAccept];
    });
}

-(void)start
{
    if (_isRunning) {
        return;
    }
    _isRunning = YES;
    [_connections makeObjectsPerformSelector:@selector(close)];
    _connections = [NSMutableArray array];
    
    _listenSocket = socket(AF_INET, SOCK_STREAM, 0);
    if (_listenSocket < 0) {
        NSLog(@"socket error, %d", _listenSocket);
        goto fail;
    }
    
    struct sockaddr_in saddr;
    bzero(&saddr, sizeof(saddr));
    saddr.sin_family = PF_INET;
    saddr.sin_addr.s_addr = INADDR_ANY;
    saddr.sin_port = htons(_port);
    saddr.sin_len = sizeof(saddr);
    
    int result = bind(_listenSocket, (struct sockaddr *)&saddr, sizeof(struct sockaddr_in));
    if (result < 0) {
        NSLog(@"bind error, %d", result);
        goto fail;
    }
    
    result = listen(_listenSocket, SOMAXCONN);
    if (result < 0) {
        NSLog(@"listen error, %d", result);
        goto fail;
    }
    NSLog(@"listening ...");
    
    [self waitForAccept];
    
    return;
    
fail:
    _isRunning = NO;

}

@end
