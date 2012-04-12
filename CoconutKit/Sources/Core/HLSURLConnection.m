//
//  HLSURLConnection.m
//  CoconutKit
//
//  Created by Samuel Défago on 10.04.12.
//  Copyright (c) 2012 Hortis. All rights reserved.
//

#import "HLSURLConnection.h"

#import "HLSAssert.h"
#import "HLSLogger.h"
#import "HLSNotifications.h"
#import "HLSZeroingWeakRef.h"

float HLSURLConnectionProgressUnavailable = -1.f;

@interface HLSURLConnection ()

@property (nonatomic, retain) NSURLRequest *request;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *internalData;
@property (nonatomic, assign) HLSURLConnectionStatus status;
@property (nonatomic, retain) HLSZeroingWeakRef *delegateZeroingWeakRef;

- (void)reset;
- (BOOL)prepareForDownload;

@end

@implementation HLSURLConnection

#pragma mark Class methods

+ (HLSURLConnection *)connectionWithRequest:(NSURLRequest *)request
{
    return [[[[self class] alloc] initWithRequest:request] autorelease];
}

#pragma mark Object creation and destruction

- (id)initWithRequest:(NSURLRequest *)request
{
    if ((self = [super init])) {
        self.request = request;
        self.internalData = [[[NSMutableData alloc] init] autorelease];
        [self reset];
    }
    return self;
}

- (id)init
{
    HLSForbiddenInheritedMethod();
    return nil;
}

- (void)dealloc
{
    self.request = nil;
    self.connection = nil;
    self.tag = nil;
    self.downloadFilePath = nil;
    self.userInfo = nil;
    self.internalData = nil;
    self.delegateZeroingWeakRef = nil;
    
    [super dealloc];
}

#pragma mark Accessors and mutators

@synthesize request = m_request;

@synthesize connection = m_connection;

@synthesize tag = m_tag;

@synthesize downloadFilePath = m_downloadFilePath;

- (void)setDownloadFilePath:(NSString *)downloadFilePath
{
    if (self.status == HLSURLConnectionStatusStarting || self.status == HLSURLConnectionStatusStarted) {
        HLSLoggerWarn(@"The download file path cannot be changed when a connection is started");
        return;
    }
    
    if (m_downloadFilePath == downloadFilePath) {
        return;
    }
    
    [m_downloadFilePath release];
    m_downloadFilePath = [downloadFilePath retain];
}

@synthesize userInfo = m_userInfo;

@synthesize internalData = m_internalData;

@synthesize status = m_status;

@dynamic progress;

- (float)progress
{
    if (m_expectedContentLength == NSURLResponseUnknownLength) {
        return HLSURLConnectionProgressUnavailable;
    }
    else {
        return [self.internalData length] / m_expectedContentLength;
    }
}

@synthesize delegateZeroingWeakRef = m_delegateZeroingWeakRef;

@dynamic delegate;

- (id<HLSURLConnectionDelegate>)delegate
{
    return self.delegateZeroingWeakRef.object;
}

- (void)setDelegate:(id<HLSURLConnectionDelegate>)delegate
{
    self.delegateZeroingWeakRef = [[[HLSZeroingWeakRef alloc] initWithObject:delegate] autorelease];
    [self.delegateZeroingWeakRef addCleanupAction:@selector(cancel) onTarget:self];
}

- (NSData *)data
{
    if (self.downloadFilePath) {
        return [NSData dataWithContentsOfFile:self.downloadFilePath];
    }
    else {
        return self.internalData;
    }
}

#pragma mark Managing the connection

- (void)start
{
    if (self.status == HLSURLConnectionStatusStarting || self.status == HLSURLConnectionStatusStarted) {
        HLSLoggerDebug(@"The connection has already been started");
        return;
    }
    
    if (! [self prepareForDownload]) {
        return;
    }
    
    [self reset];
        
    // Note that NSURLConnection retains its delegate. This is why we use a zeroing weak reference
    // for HLSURLConnection delegate
    self.connection = [[[NSURLConnection alloc] initWithRequest:self.request delegate:self] autorelease];
    if (! self.connection) {
        HLSLoggerError(@"Unable to open connection");
        return;
    }
    
    [[HLSNotificationManager sharedNotificationManager] notifyBeginNetworkActivity];
    self.status = HLSURLConnectionStatusStarting;
}

- (void)cancel
{
    if (self.status != HLSURLConnectionStatusStarting && self.status != HLSURLConnectionStatusStarted) {
        HLSLoggerDebug(@"The connection has not been started");
        return;
    }
    
    [[HLSNotificationManager sharedNotificationManager] notifyEndNetworkActivity];
    
    [self.connection cancel];
    [self reset];
}

- (void)startSynchronous
{
    if (self.status == HLSURLConnectionStatusStarting || self.status == HLSURLConnectionStatusStarted) {
        HLSLoggerDebug(@"The connection has already been started");
        return;
    }
    
    if (! [self prepareForDownload]) {
        return;
    }
    
    [self reset];
    
    self.status = HLSURLConnectionStatusStarting;
    [[HLSNotificationManager sharedNotificationManager] notifyBeginNetworkActivity];
    
    // As for an asynchronous connection, the connection status is handled by the NSURLConnection callbacks
    NSError *error = nil;
    if (! [NSURLConnection sendSynchronousRequest:self.request returningResponse:NULL error:&error]) {
        HLSLoggerError(@"The connection failed. Reason: %@", error);
    }
}

- (void)reset
{
    [self.internalData setLength:0];
    self.status = HLSURLConnectionStatusIdle;
    self.connection = nil;
    m_expectedContentLength = NSURLResponseUnknownLength;
}

- (BOOL)prepareForDownload
{
    if (self.downloadFilePath) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        if ([fileManager fileExistsAtPath:self.downloadFilePath]) {
            NSError *fileDeletionError = nil;
            if ([fileManager removeItemAtPath:self.downloadFilePath error:&fileDeletionError]) {
                HLSLoggerInfo(@"A file already existed at %@ and has been deleted", self.downloadFilePath);
            }
            else {
                HLSLoggerError(@"The file existing at %@ could not be deleted. Aborting. Reason: %@", self.downloadFilePath, fileDeletionError);
                return NO;
            }    
        }
                
        NSString *downloadFileDirectoryPath = [self.downloadFilePath stringByDeletingLastPathComponent];
        NSError *directoryCreationError = nil;
        if (! [fileManager createDirectoryAtPath:downloadFileDirectoryPath
                     withIntermediateDirectories:YES 
                                      attributes:nil 
                                           error:&directoryCreationError]) {
            HLSLoggerError(@"Could not create directory %@. Aborting. Reason: %@", downloadFileDirectoryPath, directoryCreationError);
            return NO;
        }
        
        NSError *fileCreationError = nil;
        if (! [fileManager createFileAtPath:self.downloadFilePath contents:nil attributes:nil]) {
            HLSLoggerError(@"Could not create file at path %@. Aborting. Reason: %@", self.downloadFilePath, fileCreationError);
            return NO;
        }
    }
    
    return YES;
}

#pragma mark NSURLConnection events

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // Each time a response is received we must discard any previously accumulated data
    // (refer to NSURLConnection documentation for more information)
    m_expectedContentLength = [response expectedContentLength];
        
    self.status = HLSURLConnectionStatusStarted;
    if ([self.delegate respondsToSelector:@selector(connectionDidStart:)]) {
        [self.delegate connectionDidStart:self];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (self.downloadFilePath) {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:self.downloadFilePath];
        if (! fileHandle) {
            HLSLoggerError(@"The file at %@ could not be found. Aborting");
            [self cancel];
            return;
        }
        
        @try {
            [fileHandle seekToEndOfFile];
            [fileHandle writeData:data];
        }
        @catch (NSException *exception) {
            HLSLoggerError(@"The file at %@ could not be written. Aborting. Reason: %@", exception);
            [self cancel];
            return;
        }
    }
    else {
        [self.internalData appendData:data];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    HLSLoggerDebug(@"Connection failed with error: %@", error);
    
    // Remove file on failure
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:self.downloadFilePath]) {
        NSError *fileDeletionError = nil;
        if (! [fileManager removeItemAtPath:self.downloadFilePath error:&fileDeletionError]) {
            HLSLoggerError(@"The file at %@ could not be deleted. Reason: %@", fileDeletionError);
        }
    }
    
    [self reset];
    [[HLSNotificationManager sharedNotificationManager] notifyEndNetworkActivity];
    
    if ([self.delegate respondsToSelector:@selector(connection:didFailWithError:)]) {
        [self.delegate connection:self didFailWithError:error];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.connection = nil;
    
    self.status = HLSURLConnectionStatusIdle;
    [[HLSNotificationManager sharedNotificationManager] notifyEndNetworkActivity];
    
    if ([self.delegate respondsToSelector:@selector(connectionDidFinish:)]) {
        [self.delegate connectionDidFinish:self];
    }
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; request: %@; tag: %@; downloadFilePath: %@; progress: %.2f>", 
            [self class],
            self,
            self.request,
            self.tag,
            self.downloadFilePath,
            self.progress];
}

@end