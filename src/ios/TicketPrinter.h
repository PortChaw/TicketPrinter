//
//  TicketPrinter.h
//  OposM
//
//  Created by chirgwin on 12/21/12.
//
//


#import <Foundation/Foundation.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
#import <Cordova/CDV.h>
#import "GCDAsyncSocket.h"
#include <ifaddrs.h>
#include <stdio.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#include "route.h"
#include <net/if.h>
#include <string.h>
#import "NSData+Base64.h"

#define BIND_8_COMPAT
#include <arpa/nameser.h>
#include <resolv.h>

@interface TicketPrinter : CDVPlugin <GCDAsyncSocketDelegate>
{
    GCDAsyncSocket *asyncSocket;
}

// open connection to printer, send a string to it, close connection
- (void)writeToPrinter: (CDVInvokedUrlCommand*)command;

// ping a printer
- (void)pingPrinter: (CDVInvokedUrlCommand*)command;

// scans local network for available printers
- (void)discoverPrinters: (CDVInvokedUrlCommand*)command;
- (void)sendCommandToPrinter: (CDVInvokedUrlCommand*)command;
- (void)configurePrinter: (CDVInvokedUrlCommand*)command;

- (NSString *) getLocalIp;
- (NSString *) getSubnetMask;
- (NSString *) getBroadcastAddress;
- (struct ifaddrs *) getLocalAddress;
- (NSString *) getDefaultGateway;
- (NSMutableArray *) getDNSServers;


@property (nonatomic, strong) NSString *commandToSend;
@property (nonatomic, strong) NSString *sentCommandJavascriptCallback;
@property (nonatomic, strong) NSMutableData *incomingData;
@property (nonatomic, strong) NSString *localIpAddress;
@property (nonatomic, strong) NSString *currentPrinterHost;
@property (nonatomic, strong) NSString *currentPrinterPort;


@end
