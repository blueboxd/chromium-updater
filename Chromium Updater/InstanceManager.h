//
//  InstanceManager.h
//  Chromium Updater
//
//  Created by bluebox on 2021/12/04.
//  Copyright © 2021 bluebox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString* const InstanceManagerInstanceDictionaryCanaryKey;
extern NSString* const InstanceManagerInstanceDictionaryVersionKey;
extern NSString* const InstanceManagerInstanceDictionaryRevisionKey;
extern NSString* const InstanceManagerInstanceDictionaryURLKey;
extern NSString* const InstanceManagerInstanceDictionaryUpdateCandidateKey;

extern NSString* const InstanceManagerLocalInstancesDictionaryInstanceTypeKey;
extern NSString* const InstanceManagerLocalInstancesDictionaryRunningInstanceKey;
extern NSString* const InstanceManagerLocalInstancesDictionaryInstalledInstanceKey;

extern NSString* const InstanceManagerRemoteInstancesDictionaryCanaryInstanceKey;
extern NSString* const InstanceManagerRemoteInstancesDictionaryStableInstanceKey;

extern NSNotificationName InstanceManagerLocalInstancesRefreshedNotificationKey;
extern NSNotificationName InstanceManagerRemoteInstancesRefreshedNotificationKey;
extern NSNotificationName InstanceManagerUpdatesDidChangeNotificationKey;

@interface InstanceManager : NSObject
+(NSString*)stringFromVersion:(NSString*)ver revision:(NSString*)rev;
+(NSString*)stringWithTypeFromInstanceInfo:(NSDictionary*)info;
+(NSString*)stringFromInstanceInfo:(NSDictionary*)info;
- (void)refreshLocalRevisions;
- (void)refreshRemoteRevisions;
- (void)startTimer;
- (void)stopTimer;
@end

NS_ASSUME_NONNULL_END
