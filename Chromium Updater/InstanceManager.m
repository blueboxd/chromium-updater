//
//  InstanceManager.m
//  Chromium Updater
//
//  Created by bluebox on 2021/12/04.
//  Copyright © 2021 bluebox. All rights reserved.
//

#import "InstanceManager.h"
#import "SimpleCURL.h"

NSString* const InstanceManagerInstanceDictionaryCanaryKey = @"canary";
NSString* const InstanceManagerInstanceDictionaryVersionKey = @"version";
NSString* const InstanceManagerInstanceDictionaryRevisionKey = @"revision";
NSString* const InstanceManagerInstanceDictionaryURLKey = @"url";
NSString* const InstanceManagerInstanceDictionaryUpdateCandidateKey = @"update";

NSString* const InstanceManagerLocalInstancesDictionaryInstanceTypeKey = @"type";
NSString* const InstanceManagerLocalInstancesDictionaryRunningInstanceKey = @"running";
NSString* const InstanceManagerLocalInstancesDictionaryInstalledInstanceKey = @"installed";

NSString* const InstanceManagerRemoteInstancesDictionaryCanaryInstanceKey = @"canary";
NSString* const InstanceManagerRemoteInstancesDictionaryStableInstanceKey = @"stable";

NSNotificationName InstanceManagerLocalInstancesRefreshedNotificationKey = @"InstanceManagerLocalInstancesRefreshedNotificationKey";
NSNotificationName InstanceManagerRemoteInstancesRefreshedNotificationKey = @"InstanceManagerRemoteInstancesRefreshedNotificationKey";
NSNotificationName InstanceManagerUpdatesDidChangeNotificationKey = @"InstanceManagerUpdateAvailableNotificationKey";

@implementation InstanceManager {
  NSMutableDictionary    *runningInstance;
  NSMutableDictionary    *installedInstance;

  NSDictionary    *canaryBuild;
  NSDictionary    *stableBuild;

  NSTimer         *refreshLocalTimer;
  NSTimer         *refreshRemoteTimer;

  NSMutableDictionary *updatesAvailable;
}

+(NSString*)stringFromVersion:(NSString*)ver revision:(NSString*)rev {
  return [NSString stringWithFormat:@"%@ [#%@]", ver, rev];
}

+(NSString*)stringWithTypeFromInstanceInfo:(NSDictionary*)info {
  return [NSString stringWithFormat:@"%@ [#%@] (%@)", info[InstanceManagerInstanceDictionaryVersionKey], info[InstanceManagerInstanceDictionaryRevisionKey], [info[InstanceManagerInstanceDictionaryCanaryKey] intValue]?@"Canary":@"Stable"];
}

+(NSString*)stringFromInstanceInfo:(NSDictionary*)info {
  return [NSString stringWithFormat:@"%@ [#%@]", info[InstanceManagerInstanceDictionaryVersionKey], info[InstanceManagerInstanceDictionaryRevisionKey]];
}

- (void)awakeFromNib {
  updatesAvailable = [NSMutableDictionary new];
}

- (void)startTimer {
  refreshLocalTimer = [NSTimer timerWithTimeInterval:5 target:self selector:@selector(refreshLocalRevisions) userInfo:nil repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:refreshLocalTimer forMode:NSDefaultRunLoopMode];

  refreshRemoteTimer = [NSTimer timerWithTimeInterval:3600 target:self selector:@selector(refreshRemoteRevisions) userInfo:nil repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:refreshRemoteTimer forMode:NSDefaultRunLoopMode];
}

- (void)stopTimer {
  [refreshLocalTimer invalidate];
  [refreshRemoteTimer invalidate];
}

- (void)queueUpdateForInstance:(NSMutableDictionary*)current{
//  NSLog(@"update %@ (#%@) available for %@", new[InstanceManagerInstanceDictionaryVersionKey], new[InstanceManagerInstanceDictionaryRevisionKey], current[InstanceManagerInstanceDictionaryURLKey]);

  updatesAvailable[current[InstanceManagerLocalInstancesDictionaryInstanceTypeKey]] = current;
  [[NSNotificationCenter defaultCenter] postNotificationName:InstanceManagerUpdatesDidChangeNotificationKey object:self userInfo:updatesAvailable];
}

- (void)dequeueUpdateForInstance:(NSMutableDictionary*)current{
//  NSLog(@"no update available for %@", current[InstanceManagerInstanceDictionaryURLKey]);

  NSInteger prevCount = [updatesAvailable count];
  [updatesAvailable removeObjectForKey:current[InstanceManagerLocalInstancesDictionaryInstanceTypeKey]];

  if(prevCount!=[updatesAvailable count]) {
    [[NSNotificationCenter defaultCenter] postNotificationName:InstanceManagerUpdatesDidChangeNotificationKey object:self userInfo:updatesAvailable];
  }
}

- (BOOL)isVersion:(NSString*)version1 greaterThan:(NSString*)version2 {
  NSArray *v1components = [version1 componentsSeparatedByString:@"."];
  NSArray *v2components = [version2 componentsSeparatedByString:@"."];

  if([v1components[0] intValue] > [v2components[0] intValue])
    return YES;

  if([v1components[2] intValue] > [v2components[2] intValue])
    return YES;

  if([v1components[3] intValue] > [v2components[3] intValue])
    return YES;

  return NO;
}

- (void)compareRevisions{
  if(!canaryBuild || !stableBuild)
    return;

  if(runningInstance) {
    if([runningInstance[InstanceManagerInstanceDictionaryCanaryKey] intValue]) {
      if([canaryBuild[InstanceManagerInstanceDictionaryRevisionKey] intValue] > [runningInstance[InstanceManagerInstanceDictionaryRevisionKey] intValue]) {
        runningInstance[InstanceManagerInstanceDictionaryUpdateCandidateKey] = canaryBuild;
        [self queueUpdateForInstance:runningInstance];
      } else {
        [runningInstance removeObjectForKey:InstanceManagerInstanceDictionaryUpdateCandidateKey];
        [self dequeueUpdateForInstance:runningInstance];
      }
    } else {
      if([self isVersion:stableBuild[InstanceManagerInstanceDictionaryVersionKey] greaterThan:runningInstance[InstanceManagerInstanceDictionaryVersionKey]]) {
        runningInstance[InstanceManagerInstanceDictionaryUpdateCandidateKey] = stableBuild;
        [self queueUpdateForInstance:runningInstance];
      } else {
        [runningInstance removeObjectForKey:InstanceManagerInstanceDictionaryUpdateCandidateKey];
        [self dequeueUpdateForInstance:runningInstance];
      }
    }
  }

  if(installedInstance){
    if([installedInstance[InstanceManagerInstanceDictionaryCanaryKey] intValue]) {
      if([canaryBuild[InstanceManagerInstanceDictionaryRevisionKey] intValue] > [installedInstance[InstanceManagerInstanceDictionaryRevisionKey] intValue]) {
        installedInstance[InstanceManagerInstanceDictionaryUpdateCandidateKey] = canaryBuild;
        [self queueUpdateForInstance:installedInstance];
      } else {
        [installedInstance removeObjectForKey:InstanceManagerInstanceDictionaryUpdateCandidateKey];
        [self dequeueUpdateForInstance:installedInstance];
      }
    } else {
      if([self isVersion:stableBuild[InstanceManagerInstanceDictionaryVersionKey] greaterThan:installedInstance[InstanceManagerInstanceDictionaryVersionKey]]) {
        installedInstance[InstanceManagerInstanceDictionaryUpdateCandidateKey] = stableBuild;
        [self queueUpdateForInstance:installedInstance];
      } else {
        [installedInstance removeObjectForKey:InstanceManagerInstanceDictionaryUpdateCandidateKey];
        [self dequeueUpdateForInstance:installedInstance];
      }
    }
  }
}

- (void)refreshLocalRevisions{
  NSMutableDictionary *instances = [NSMutableDictionary new];
  NSURL* runningPath = [self getRunningInstance];
  if(runningPath) {
    NSDictionary *runningInfo = [self instanceInfoForURL:runningPath];
//    NSLog(@"running:%@", runningInfo);

    runningInstance = [runningInfo mutableCopy];
    runningInstance[InstanceManagerLocalInstancesDictionaryInstanceTypeKey] = InstanceManagerLocalInstancesDictionaryRunningInstanceKey;
    instances[InstanceManagerLocalInstancesDictionaryRunningInstanceKey] = runningInstance;
  } else {
    if(runningInstance)
      [self dequeueUpdateForInstance:runningInstance];
    runningInstance = nil;
  }

  NSURL* installedPath = [self getInstalledInstance];
  if(installedPath) {
    NSDictionary *installedInfo = [self instanceInfoForURL:installedPath];
//    NSLog(@"installed:%@", installedInfo);

    installedInstance = [installedInfo mutableCopy];
    installedInstance[InstanceManagerLocalInstancesDictionaryInstanceTypeKey] = InstanceManagerLocalInstancesDictionaryInstalledInstanceKey;
    instances[InstanceManagerLocalInstancesDictionaryInstalledInstanceKey] = installedInstance;
  } else {
    if(installedInstance)
      [self dequeueUpdateForInstance:installedInstance];
    installedInstance = nil;
  }

  [self compareRevisions];

  [[NSNotificationCenter defaultCenter] postNotificationName:InstanceManagerLocalInstancesRefreshedNotificationKey object:self userInfo:instances];
}

- (NSString*)getRevisionFromSCMRevision:(NSString*)scmRevision{
  NSArray *components = [scmRevision componentsSeparatedByString:@"/"];
  NSString *rev = components[components.count-1];
  NSString *revtmp = [rev componentsSeparatedByString:@"@"][1];
  NSString *revision = [revtmp substringWithRange:NSMakeRange(2, revtmp.length-3)];
  return revision;
}

extern void _CFBundleFlushBundleCaches(CFBundleRef bundle) __attribute__((weak_import));
void FlushBundleCache(NSBundle *bundle) {
  if (_CFBundleFlushBundleCaches != NULL) {
    CFBundleRef cfBundle =
    CFBundleCreate(nil, (CFURLRef)[bundle bundleURL]);
    _CFBundleFlushBundleCaches(cfBundle);
    CFRelease(cfBundle);
  }
}

- (NSDictionary*)instanceInfoForURL:(NSURL*)path {
//NSLog(@"instanceInfoForURL:%@",path);
  NSBundle *bundle = [NSBundle bundleWithURL:path];
  FlushBundleCache(bundle);
  NSString *revStr = [bundle objectForInfoDictionaryKey:@"SCMRevision"];
  NSString *version = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  if(revStr&&version)
    return @{InstanceManagerInstanceDictionaryURLKey:path,InstanceManagerInstanceDictionaryVersionKey:version,InstanceManagerInstanceDictionaryRevisionKey:[self getRevisionFromSCMRevision:revStr],InstanceManagerInstanceDictionaryCanaryKey:([revStr rangeOfString:@"main"].location!=NSNotFound)?@YES:@NO};
  else
    return nil;
}

- (NSURL*)getRunningInstance{
  NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"org.chromium.Chromium"];
//  NSLog(@"getRunningInstance:%@",apps);
  if([apps count]==0)return nil;
  return [apps[0] bundleURL];
}

-(NSURL*)getInstalledInstance{
  NSURL *url = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"org.chromium.Chromium"];
//  NSLog(@"getInstalledInstance:%@",url);
  if(url==nil)return nil;
  return url;
}


- (void)refreshRemoteRevisions{
  NSMutableDictionary *instances = [NSMutableDictionary new];

  NSDictionary *revCanary = [self getRemoteRevisionFor:@"https://api.github.com/repos/blueboxd/chromium-legacy/releases/latest"];
  NSDictionary *revStable = [self getRemoteRevisionFor:@"https://api.github.com/repos/blueboxd/chromium-legacy/releases/tags/stable"];

  NSLog(@"canary:%@, stable:%@", revCanary, revStable);

  if(revCanary) {
    canaryBuild = revCanary;
    instances[InstanceManagerRemoteInstancesDictionaryCanaryInstanceKey] = canaryBuild;
  } else {
    canaryBuild = nil;
  }

  if(revStable) {
    stableBuild = revStable;
    instances[InstanceManagerRemoteInstancesDictionaryStableInstanceKey] = stableBuild;
  } else {
    stableBuild = nil;
  }

  [self compareRevisions];

  [[NSNotificationCenter defaultCenter] postNotificationName:InstanceManagerRemoteInstancesRefreshedNotificationKey object:self userInfo:instances];
}

- (NSDictionary*)getRemoteRevisionFor:(NSString*)url {
  NSData *result = [SimpleCURL curlFor:url];
//  NSLog(@"getRemoteRevisionFor:%@",result);
  if(!result)
    return nil;

  NSError *err;
  NSDictionary *json = [NSJSONSerialization JSONObjectWithData:result options:0 error:&err];
  NSString *body = json[@"body"];
  NSArray *bodyComponents = [body componentsSeparatedByString:@"\n"];
  NSString *scmRevision = [bodyComponents[1] componentsSeparatedByString:@" "][1];
  NSString *revision = [self getRevisionFromSCMRevision:scmRevision];
  NSString *version = [bodyComponents[0] componentsSeparatedByString:@" "][1];
  BOOL isCanary = [scmRevision rangeOfString:@"main"].location != NSNotFound;
  __block NSString *downloadURL;
  [json[@"assets"] enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop){
    if([obj[@"browser_download_url"] rangeOfString:@".tar.xz"].location != NSNotFound)
      downloadURL = obj[@"browser_download_url"];
  }];

  return @{InstanceManagerInstanceDictionaryCanaryKey:isCanary?@YES:@NO, InstanceManagerInstanceDictionaryRevisionKey:revision, InstanceManagerInstanceDictionaryVersionKey:version, InstanceManagerInstanceDictionaryURLKey:downloadURL};
}
@end
