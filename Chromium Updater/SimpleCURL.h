//
//  SimleCURL.h
//  Chromium Updater
//
//  Created by bluebox on 2021/12/04.
//  Copyright © 2021 bluebox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName SimpleCURLDownloadDidStartNotificationKey;
extern NSNotificationName SimpleCURLDownloadProgressDidChangeNotificationKey;
extern NSString* const SimpleCURLDownloadProgressDictionaryURLKey;
extern NSString* const SimpleCURLDownloadProgressDictionaryULProgressKey;
extern NSString* const SimpleCURLDownloadProgressDictionaryDLProgressKey;

extern NSNotificationName SimpleCURLDownloadDidEndNotificationKey;

@interface SimpleCURL : NSObject
+ (NSData*)curlFor:(NSString*)url;
@end

NS_ASSUME_NONNULL_END
