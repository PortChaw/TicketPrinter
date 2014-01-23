//
//  TicketPrinter.m
//  OposM
//
//  Created by chirgwin on 12/21/12.
//
//

#import "TicketPrinter.h"
#import <Cordova/CDV.h>

@implementation TicketPrinter

@synthesize commandToSend = _commandToSend;
@synthesize sentCommandJavascriptCallback = _sentCommandJavascriptCallback;
@synthesize currentPrinterHost = _currentPrinterHost;
@synthesize currentPrinterPort = _currentPrinterPort;
@synthesize incomingData = _incomingData;
@synthesize localIpAddress = _localIpAddress;

const uint PRINTER_PORT = 9100;
const uint MAX_IP_RANGE = 255;
const uint PRINTER_TIMEOUT_SECS = 5;
const uint PRINTER_CONFIG_HTTP_PORT = 80;
const uint PRINTER_COMMAND_TAG = 0;
const uint PRINTER_CONFIG_TAG = 1;
const char* PRINTER_DEFAULT_USER = "admin";
const char* PRINTER_DEFAULT_PASS = "password";
const char* HTTP_USER_AGENT = "OposM";
const char* WIFI_INTERFACE_NAME = "en0";
const char* PRINT_TYPE_THERMAL = "thermal";
const char* PRINT_TYPE_IMPACT = "impact";
const char* PRINTER_CONFIG_PATH_THERMAL = "/lan/Network_set.cgi";
const char* PRINTER_CONFIG_PATH_IMPACT = "/NETCONFIG.CGI";
const char* COMMAND_DETERMINE_MODEL = "\x1d\x49\x43";


#define CTL_NET         4               /* network, see socket.h */


#define ROUNDUP(a) \
((a) > 0 ? (1 + (((a) - 1) | (sizeof(long) - 1))) : sizeof(long))

-(void)writeToPrinter:(CDVInvokedUrlCommand*)command
{

    [self.commandDelegate runInBackground:^{
        NSString *host = [command.arguments objectAtIndex:0];
        NSUInteger port = [[command.arguments objectAtIndex:1] intValue];
        NSUInteger timeout = [[command.arguments objectAtIndex:2] intValue];
        NSString *stringToWrite = [command.arguments objectAtIndex:3];

        CDVPluginResult* pluginResult = nil;
        CFTimeInterval timeoutSecs = timeout;
        CFSocketRef sock_id = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketNoCallBack, NULL, NULL);
        struct sockaddr_in addr4;
        memset(&addr4, 0, sizeof(addr4));
        addr4.sin_len = sizeof(addr4);
        addr4.sin_family = PF_INET;
        addr4.sin_port = htons(port);

        inet_pton(AF_INET, (const char *)[host cStringUsingEncoding:NSASCIIStringEncoding], &addr4.sin_addr);
        CFDataRef addr = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&addr4, (CFIndex)sizeof(struct sockaddr_in));

        int length = [stringToWrite length];
        uint8_t data[length];

        NSString *charMap = @"ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜø£Ø×ƒáíóúñÑªº¿®¬½¼¡«»░▒▓│┤ÁÂÀ©╣║╗╝¢¥┐└┴┬├─┼ãÃ╚╔╩╦╠═╬¤ðÐÊËÈıÍÎÏ┘┌█▄¦Ì▀ÓßÔÒõÕµþÞÚÛÙýÝ¯´≡±‗¾¶§÷¸°¨·¹³²■";
        NSRange match;

        for(int i = 0; i < length; i++)
        {
            if([stringToWrite characterAtIndex:i] > 127 && [stringToWrite characterAtIndex:i] < 255)
            {

                NSString *compare = [stringToWrite substringWithRange: NSMakeRange (i, 1)];
                match = [charMap rangeOfString: compare];
                data[i] = match.location + 128;
            }
            //replace NBSP with a regular space
            else if([stringToWrite characterAtIndex:i] == 255)
            {
                data[i] = 32;
            }
            else
            {
                data[i] = [stringToWrite characterAtIndex: i];
            }
        }

        CFDataRef cdDataToSend = CFDataCreate(kCFAllocatorDefault, data, length);
        int retVal = CFSocketConnectToAddress(sock_id, addr, timeoutSecs);

        if(retVal != kCFSocketSuccess )
        {
            //couldn't connect, callback with error
            NSLog(@"connection error");
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"%@:%d", host, port]];
        } else // connected OK, so send data
        {
            retVal = CFSocketSendData(sock_id, addr, cdDataToSend, timeoutSecs);
            if(retVal != kCFSocketSuccess )
            {
                //couldn't send, callback with error
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"%@:%d", host, port]];
            } else { //all went well; callback with success
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[NSString stringWithFormat:@"%@:%d", host, port]];
            }
        }

        //close / invalidate socket
        CFSocketInvalidate(sock_id);

        // call back to JavaScript
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    }];

}

-(void)sendCommandToPrinter:(CDVInvokedUrlCommand*) command
{
    NSString *host = [command.arguments objectAtIndex:0];
    NSUInteger port = [[command.arguments objectAtIndex:1] intValue];
    NSUInteger timeout = [[command.arguments objectAtIndex:2] intValue];
    self.commandToSend = [command.arguments objectAtIndex:3];

    NSString *javascriptCallback = [command.arguments objectAtIndex:4];

    //    if ([self.sendCommandJavascriptCallback isEqual:nil])
    //    {
    self.sentCommandJavascriptCallback = javascriptCallback;
    self.currentPrinterHost = host;
    self.currentPrinterPort = [NSString stringWithFormat:@"%d", PRINTER_CONFIG_HTTP_PORT];
    //    }

    NSError *error = nil;
    CDVPluginResult* pluginResult = nil;
    if (![asyncSocket connectToHost:host onPort:port withTimeout:timeout error:&error])
    {
        NSDictionary *jsonDict;
        NSData *jsonData = nil;
        jsonDict = [NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithBool:NO], @"success",
                    "error connecting", @"response",
                    host, @"host",
                    port, @"port",
                    nil];
        jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil];

        NSString *jsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        NSString *jsStatement = [NSString stringWithFormat:@"%@(%@);",
                                 self.sentCommandJavascriptCallback,
                                 jsString];

        [self writeJavascript:jsStatement];
        return;
    }

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[NSString stringWithFormat:@"%@", host]];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Socket Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSData *requestData = [self.commandToSend dataUsingEncoding:NSUTF8StringEncoding];

    if (port == PRINTER_CONFIG_HTTP_PORT) //printer http configuration request
    {
        [asyncSocket writeData:requestData withTimeout:-1.0 tag:PRINTER_CONFIG_TAG];
        NSData *responseTerminatorData = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
        [asyncSocket readDataToData:responseTerminatorData withTimeout:-1.0 tag:PRINTER_CONFIG_TAG];
    }
    else //printer command socket connection
    {

        [sock
         writeData:requestData
         withTimeout:10
         tag:1];

        [self.incomingData setLength:0];

        [sock readDataWithTimeout:2 buffer:self.incomingData
                     bufferOffset:0 tag:PRINTER_COMMAND_TAG];

     //   [sock disconnectAfterReadingAndWriting];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
//    NSLog(@"socket:%p didWriteDataWithTag:%ld", sock, tag);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    NSDictionary *jsonDict;
    NSData *jsonData = nil;

    jsonDict = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithBool:YES], @"success",
                response, @"response",
                [sock connectedHost], @"host",
                [NSString stringWithFormat:@"%hu", [sock connectedPort]], @"port",
                nil];
    jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil];

    NSString *jsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    NSString *jsStatement = [NSString stringWithFormat:@"%@(%@);",
                             self.sentCommandJavascriptCallback,
                             jsString];

    [self writeJavascript:jsStatement];

    // disconnect command socket; TODO: longer reponses, multiple socket reads?
    if ([sock isConnected])
    {
        [sock disconnect];
    }

}


- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    //TODO: handle http response
//    NSLog(@"socketDidDisconnect:%p withError: %@", sock, err);

    if (err)
    {
        NSLog(@"socketDidDisconnect err: %@, host %@", err.description, [sock connectedHost]);
        NSDictionary *jsonDict;
        NSData *jsonData = nil;

        jsonDict = [NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithBool:NO], @"success",
                    err.description, @"response",
                    self.currentPrinterHost, @"host",
                    self.currentPrinterPort, @"port",
                    nil];
        jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil];

        NSString *jsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        NSString *jsStatement = [NSString stringWithFormat:@"%@(%@);",
                                 self.sentCommandJavascriptCallback,
                                 jsString];

        [self writeJavascript:jsStatement];

    }
}

-(void)pingPrinter:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        NSString *host = [command.arguments objectAtIndex:0];
        NSUInteger port = [[command.arguments objectAtIndex:1] intValue];
        NSUInteger timeout = [[command.arguments objectAtIndex:2] intValue];

        CDVPluginResult* pluginResult = nil;
        BOOL success = [self ping:host port:port timeout:timeout];

        if(success)
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[NSString stringWithFormat:@"%@:%d", host, port]];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"%@:%d", host, port]];
        }

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];

}

- (void) discoverPrinters: (CDVInvokedUrlCommand*)command
{
    if (self.localIpAddress == (id)[NSNull null] || self.localIpAddress.length == 0 )
    {
        self.localIpAddress = [self getLocalIp];
    }
    NSString *progressCallback = [command.arguments objectAtIndex:0];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"starting"];
    //return immediately
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    NSArray *octets = [self.localIpAddress componentsSeparatedByString:@"."];

    for (uint i = 0; i <= MAX_IP_RANGE; i++)
    {
        [self.commandDelegate runInBackground:^{
            NSDictionary *jsonDict;
            NSString *jsStatement;
            NSString *host = [NSString stringWithFormat:@"%@.%@.%@.%d", octets[0], octets[1], octets[2], i];
            bool success = [self ping:host port:PRINTER_PORT timeout:PRINTER_TIMEOUT_SECS];
            NSString *progress = [NSString stringWithFormat:@"%u/%u", i, MAX_IP_RANGE];
            NSData *jsonData = nil;
            if (success)
            {
                jsonDict = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:YES], @"success",
                            progress, @"progress",
                            host, @"host",
                            [NSNumber numberWithUnsignedInt: PRINTER_PORT], @"port",
                            @"unknown", @"model",
                            nil];
                jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil];
            }
            else
            {
                jsonDict = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:NO], @"success",
                            progress, @"progress",
                            host, @"host",
                            @"unknown", @"model",
                            nil];
                jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil];
            }

            if (jsonData)
            {
                NSString *jsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                jsStatement = [NSString stringWithFormat:@"%@(%@);",
                               progressCallback,
                               jsString];

                // must dispatch write javascript call to main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self writeJavascript:jsStatement];
                });
            }
        }];
    }
}

- (BOOL) ping: (NSString *)host port:(NSUInteger)port timeout:(NSUInteger)timeout
{
    CFTimeInterval timeoutSecs = 5; //FIXME:
    CFSocketRef sock_id = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketNoCallBack, NULL, NULL);
    struct sockaddr_in addr4;
    memset(&addr4, 0, sizeof(addr4));
    addr4.sin_len = sizeof(addr4);
    addr4.sin_family = PF_INET;
    addr4.sin_port = htons(port);
    inet_pton(AF_INET, (const char *)[host cStringUsingEncoding:NSASCIIStringEncoding], &addr4.sin_addr);
    CFDataRef addr = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&addr4, sizeof(struct sockaddr_in));
    CFSocketError err = CFSocketConnectToAddress(sock_id, addr, timeoutSecs);

    //close / invalidate socket
    CFSocketInvalidate(sock_id);

    if (err != kCFSocketSuccess) {
        return NO;
    }
    else {
        return YES;
    }
}

- (void) configurePrinter: (CDVInvokedUrlCommand*)command
{
    if (self.localIpAddress == (id)[NSNull null] || self.localIpAddress.length == 0 )
    {
        self.localIpAddress = [self getLocalIp];
    }
    NSString *printerHost = [command.arguments objectAtIndex:0];
    self.currentPrinterHost = printerHost;
    self.currentPrinterPort = [NSString stringWithFormat:@"%d", PRINTER_CONFIG_HTTP_PORT];;
    NSString *printType = [command.arguments objectAtIndex:1];

    NSString *javascriptCallback = [command.arguments objectAtIndex:2];

    //    if ([self.sendCommandJavascriptCallback isEqual:nil])
    //    {
    self.sentCommandJavascriptCallback = javascriptCallback;


    NSString *subnetMask = [self getSubnetMask];
    NSString *gateway = [self getDefaultGateway];
    NSArray *printerOctets = [printerHost componentsSeparatedByString:@"."];
    NSArray *subnetOctets = [subnetMask componentsSeparatedByString:@"."];
    NSArray *gatewayOctets = [gateway componentsSeparatedByString:@"."];
    NSMutableArray *dns = [self getDNSServers];
    NSString *dnsServer = [dns firstObject];
    NSArray *DNSOctets = [dnsServer componentsSeparatedByString:@"."];

	NSMutableString *requestStr;

    //impact printer
    if (strcmp([printType UTF8String], PRINT_TYPE_IMPACT) == 0)
    {
//        NSLog(@"Configuring impact printer...");
        requestStr = [NSMutableString stringWithFormat:@"POST %s HTTP/1.0\r\nOrigin: http://%@\r\nUser-Agent: %s\r\nContent-Type: application/x-www-form-urlencoded\r\nReferer:http://%@\r\n", PRINTER_CONFIG_PATH_IMPACT, printerHost, HTTP_USER_AGENT, printerHost];

        NSString *post = [NSString stringWithFormat:@"sip=%@&sn=%@&gwip=%@&lport=%u&i_time=0&dhcp=off\r\n\r\n",
                          printerHost, subnetMask, gateway, PRINTER_PORT];
        [requestStr appendString:post];

//        NSLog(@"%@", requestStr);

    }
    else //default ; thermal printer
    {
        requestStr = [NSMutableString stringWithFormat:@"POST %s HTTP/1.0\r\nOrigin: http://%@\r\nUser-Agent: %s\r\nContent-Type: application/x-www-form-urlencoded\r\nReferer:http://%@\r\n", PRINTER_CONFIG_PATH_THERMAL, printerHost, HTTP_USER_AGENT, printerHost];
        NSString *basicAuth = [NSString stringWithFormat:@"%s:%s", PRINTER_DEFAULT_USER, PRINTER_DEFAULT_PASS];
//TODO: iOS7 way        NSString *basicAuthEncoded = [[basicAuth dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];

        NSData *basicAuthData = [basicAuth dataUsingEncoding:NSUTF8StringEncoding];
        NSString *basicAuthEncoded = [basicAuthData base64EncodedString];

        NSString *basicAuthHeader = [NSString stringWithFormat:@"Authorization: Basic %@\r\n\r\n", basicAuthEncoded];

        [requestStr appendString:basicAuthHeader];

        //PORT?

        NSString *post = [NSString stringWithFormat:@"nInactive=0&nIPconfigMode=30&nIP1=%@&nIP2=%@&nIP3=%@&nIP4=%@&nSubnet1=%@&nSubnet2=%@&nSubnet3=%@&nSubnet4=%@&nGateway1=%@&nGateway2=%@&nGateway3=%@&nGateway4=%@&nDNS1=%@&nDNS2=%@&nDNS3=%@&nDNS4=%@\r\n\r\n",
                          printerOctets[0], printerOctets[1], printerOctets[2], printerOctets[3],
                          subnetOctets[0], subnetOctets[1], subnetOctets[2], subnetOctets[3],
                          gatewayOctets[0], gatewayOctets[1], gatewayOctets[2], gatewayOctets[3],
                          DNSOctets[0], DNSOctets[1], DNSOctets[2], DNSOctets[3]];

        [requestStr appendString:post];
    }

    self.commandToSend = requestStr;

    NSError *error = nil;
    CDVPluginResult* pluginResult = nil;

    if (![asyncSocket connectToHost:printerHost onPort:PRINTER_CONFIG_HTTP_PORT error:&error])
    {
        NSDictionary *jsonDict;
        NSData *jsonData = nil;
        jsonDict = [NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithBool:NO], @"success",
                    "error connecting", @"response",
                    printerHost, @"host",
                    PRINTER_CONFIG_HTTP_PORT, @"port",
                    nil];
        jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:nil];

        NSString *jsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        NSString *jsStatement = [NSString stringWithFormat:@"%@(%@);",
                                 self.sentCommandJavascriptCallback,
                                 jsString];

        [self writeJavascript:jsStatement];
    }

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[NSString stringWithFormat:@"%@", printerHost]];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}

- (NSString *) getLocalIp
{
    NSString *address = @"error";
    struct ifaddrs *localAddress = [self getLocalAddress];

    if (localAddress != NULL)
    {
        address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)localAddress->ifa_addr)->sin_addr)];
    }

    return address;
}

- (NSString *) getSubnetMask
{
    NSString *address = @"error";
    struct ifaddrs *localAddress = [self getLocalAddress];
    if (localAddress != NULL)
    {
        address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)localAddress->ifa_netmask)->sin_addr)];
    }

    return address;
}

- (NSString *) getBroadcastAddress
{
    NSString *address = @"error";
    struct ifaddrs *localAddress = [self getLocalAddress];
    if (localAddress != NULL)
    {
        address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)localAddress->ifa_dstaddr)->sin_addr)];
    }

    return address;
}

- (struct ifaddrs *) getLocalAddress
{
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;

    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if( temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if (strcmp(temp_addr->ifa_name, WIFI_INTERFACE_NAME) == 0) {
                    return temp_addr;
                }
            }

            temp_addr = temp_addr->ifa_next;
        }
    }

    // Free memory
    freeifaddrs(interfaces);
    return NULL;
}


// get router address
- (NSString *) getDefaultGateway {
    int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET,
        NET_RT_FLAGS, RTF_GATEWAY};
    size_t l;
    char * buf, * p;
    struct rt_msghdr * rt;
    struct sockaddr * sa;
    struct sockaddr * sa_tab[RTAX_MAX];
    int i;

    if(sysctl(mib, sizeof(mib)/sizeof(int), 0, &l, 0, 0) < 0) {
        return NULL;
    }
    if(l>0) {
        buf = malloc(l);
        if(sysctl(mib, sizeof(mib)/sizeof(int), buf, &l, 0, 0) < 0) {
            return NULL;
        }
        for(p=buf; p<buf+l; p+=rt->rtm_msglen) {
            rt = (struct rt_msghdr *)p;
            sa = (struct sockaddr *)(rt + 1);
            for(i=0; i<RTAX_MAX; i++) {
                if(rt->rtm_addrs & (1 << i)) {
                    sa_tab[i] = sa;
                    sa = (struct sockaddr *)((char *)sa + ROUNDUP(sa->sa_len));
                } else {
                    sa_tab[i] = NULL;
                }
            }

            if( ((rt->rtm_addrs & (RTA_DST|RTA_GATEWAY)) == (RTA_DST|RTA_GATEWAY))
               && sa_tab[RTAX_DST]->sa_family == AF_INET
               && sa_tab[RTAX_GATEWAY]->sa_family == AF_INET) {


                if(((struct sockaddr_in *)sa_tab[RTAX_DST])->sin_addr.s_addr == 0) {
                    char ifName[128];
                    if_indextoname(rt->rtm_index,ifName);

                    if (strcmp(ifName, WIFI_INTERFACE_NAME) == 0) {
                        return [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)(sa_tab[RTAX_GATEWAY]))->sin_addr)];

                    }
                }
            }
        }
        free(buf);
    }
    return NULL;
}

- (NSMutableArray *) getDNSServers
{
    NSMutableArray *addresses = [[NSMutableArray alloc] init];

    res_state res = malloc(sizeof(struct __res_state));

    int result = res_ninit(res);

    if ( result == 0 )
    {
        for ( int i = 0; i < res->nscount; i++ )
        {
            [addresses addObject:[NSString stringWithUTF8String:  inet_ntoa(res->nsaddr_list[i].sin_addr)]];
        }
    }

    // use router address if no DNS server is available yet
    if ([addresses count] <= 0)
    {
        [addresses addObject:[self getDefaultGateway]];
    }

    return addresses;
}

-(void) pluginInitialize
{
    asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
}

@end
