//
//  StatusMenuManager.m
//  Chromium Updater
//
//  Created by bluebox on 2021/12/04.
//  Copyright © 2021 bluebox. All rights reserved.
//

#import "StatusMenuManager.h"
#import "InstanceManager.h"
#import "AppDelegate.h"
#import "SimpleCURL.h"

#define kStateNone      @"updater"
#define kStateUpdateAvailable    @"updater-c"

@interface StatusMenuManager()
@property BOOL isRunningDetected;
@property BOOL isInstalledDetected;

@property NSString *runningVersionStr;
@property NSString *installedVersionStr;

@property BOOL isCanaryDetected;
@property BOOL isStableDetected;

@property NSString *remoteCanaryVersionStr;
@property NSString *remoteStableVersionStr;

@property NSString *remoteRefreshedDateStr;

@property BOOL isUpdateAvailable;
@end

@implementation StatusMenuManager {
  IBOutlet NSMenu *statusMenu;
  IBOutlet NSMenu *progressMenu;

  IBOutlet NSMenuItem *runningInstanceItem;
  IBOutlet NSMenuItem *runningInstanceUpdateItem;

  IBOutlet NSMenuItem *installedInstanceItem;
  IBOutlet NSMenuItem *installedInstanceUpdateItem;

  IBOutlet NSMenuItem *canaryInstanceItem;
  IBOutlet NSMenuItem *stableInstanceItem;

  IBOutlet NSMenuItem *remoteRefreshedDateItem;

  IBOutlet NSProgressIndicator *progressIndicator;

  NSStatusItem    *statusItem;

  NSDictionary<NSString*,NSImage*> *statusIcons;
}

-(void) awakeFromNib {
  self.isRunningDetected = self.isInstalledDetected = self.isCanaryDetected = self.isStableDetected = NO;
  self.isUpdateAvailable = NO;

  statusIcons = @{
    kStateNone               :  [NSImage imageNamed:kStateNone],
    kStateUpdateAvailable    :  [NSImage imageNamed:kStateUpdateAvailable],
  };

  statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
  statusItem.menu = statusMenu;
  statusItem.highlightMode = YES;

  [statusItem bind:NSImageBinding toObject:self withKeyPath:@"self.menuIcon" options:nil];
  self.menuIcon = statusIcons[kStateNone];

  [self addObserver:self forKeyPath:@"isUpdateAvailable" options:NSKeyValueObservingOptionNew context:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localRevisionsRefreshed:) name:InstanceManagerLocalInstancesRefreshedNotificationKey object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(remoteRevisionsRefreshed:) name:InstanceManagerRemoteInstancesRefreshedNotificationKey object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatesDidChange:) name:InstanceManagerUpdatesDidChangeNotificationKey object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDidStart:) name:AppDelegateUpdateProgressDidStartNotificationKey object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDidEnd:) name:AppDelegateUpdateProgressDidEndNotificationKey object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(xferDidStart:) name:SimpleCURLDownloadDidStartNotificationKey object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(xferProgressDidChange:) name:SimpleCURLDownloadProgressDidChangeNotificationKey object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(xferDidEnd:) name:SimpleCURLDownloadDidEndNotificationKey object:nil];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
  if(self.isUpdateAvailable) {
    self.menuIcon = statusIcons[kStateUpdateAvailable];
  } else {
    self.menuIcon = statusIcons[kStateNone];
  }
}

-(void) localRevisionsRefreshed:(NSNotification*)notification {
  NSDictionary *localInstances = notification.userInfo;
  NSDictionary *runningInfo = localInstances[InstanceManagerLocalInstancesDictionaryRunningInstanceKey];
  NSDictionary *installedInfo = localInstances[InstanceManagerLocalInstancesDictionaryInstalledInstanceKey];

//  NSLog(@"localRevisionsRefreshed:%@",localInstances);

  NSArray *runningInstanceMenuItems = [[runningInstanceItem submenu] itemArray];
  for(NSMenuItem *item in runningInstanceMenuItems) {
    item.tag = (NSInteger)runningInfo;
  }
  if(runningInfo) {
    self.isRunningDetected = YES;
    self.runningVersionStr = [InstanceManager stringWithTypeFromInstanceInfo:runningInfo];
  } else {
    self.isRunningDetected = NO;
    self.runningVersionStr = @"n/a";
  }

  NSArray *installedInstanceMenuItems = [[installedInstanceItem submenu] itemArray];
  for(NSMenuItem *item in installedInstanceMenuItems) {
    item.tag = (NSInteger)installedInfo;
  }
  if(installedInfo) {
    self.isInstalledDetected = YES;
    self.installedVersionStr = [InstanceManager stringWithTypeFromInstanceInfo:installedInfo];
  } else {
    self.isInstalledDetected = NO;
    self.installedVersionStr = @"n/a";
  }
}

-(void) remoteRevisionsRefreshed:(NSNotification*)notification {
  NSDate *now = [NSDate date];
  NSDateFormatter *formatter = [NSDateFormatter new];
  formatter.dateStyle = NSDateFormatterNoStyle;
  formatter.timeStyle = NSDateFormatterMediumStyle;
  remoteRefreshedDateItem.title = [NSString stringWithFormat:@"GitHub at %@",[formatter stringFromDate:now]];

  NSDictionary *remoteInstances = notification.userInfo;
  NSDictionary *canaryInfo = remoteInstances[InstanceManagerRemoteInstancesDictionaryCanaryInstanceKey];
  NSDictionary *stableInfo = remoteInstances[InstanceManagerRemoteInstancesDictionaryStableInstanceKey];

  NSArray *canaryInstanceMenuItems = [[canaryInstanceItem submenu] itemArray];
  for(NSMenuItem *item in canaryInstanceMenuItems) {
    item.tag = (NSInteger)canaryInfo;
  }
  if(canaryInfo) {
    self.remoteCanaryVersionStr = [NSString stringWithFormat:@"Canary: %@", [InstanceManager stringFromVersion:canaryInfo[InstanceManagerInstanceDictionaryVersionKey] revision:canaryInfo[InstanceManagerInstanceDictionaryRevisionKey]]];
    self.isCanaryDetected = YES;
  } else {
    self.remoteCanaryVersionStr = @"n/a";
    self.isCanaryDetected = NO;
  }

  NSArray *stableInstanceMenuItems = [[stableInstanceItem submenu] itemArray];
  for(NSMenuItem *item in stableInstanceMenuItems) {
    item.tag = (NSInteger)stableInfo;
  }
  if(stableInfo) {
    self.remoteStableVersionStr = [NSString stringWithFormat:@"Stable: %@", [InstanceManager stringFromVersion:stableInfo[InstanceManagerInstanceDictionaryVersionKey] revision:stableInfo[InstanceManagerInstanceDictionaryRevisionKey]]];
    self.isStableDetected = YES;
  } else {
    self.remoteStableVersionStr = @"n/a";
    self.isStableDetected = NO;
  }
}

-(void) updatesDidChange:(NSNotification*)notification {
//NSLog(@"updatesDidChange:%@",notification);
  NSDictionary *updates = notification.userInfo;

  self.isUpdateAvailable = ([updates count]!=0);

  NSDictionary *updateForRunning = updates[InstanceManagerLocalInstancesDictionaryRunningInstanceKey];
  if(updateForRunning) {
    runningInstanceUpdateItem.title = [NSString stringWithFormat:@"Update to %@",[InstanceManager stringFromInstanceInfo:updateForRunning[InstanceManagerInstanceDictionaryUpdateCandidateKey]]];
    runningInstanceUpdateItem.enabled = YES;
  } else {
    runningInstanceUpdateItem.title = @"No updates";
    runningInstanceUpdateItem.enabled = NO;
  }

  NSDictionary *updateForInstalled = updates[InstanceManagerLocalInstancesDictionaryInstalledInstanceKey];
  if(updateForInstalled) {
    installedInstanceUpdateItem.title = [NSString stringWithFormat:@"Update to %@",[InstanceManager stringFromInstanceInfo:updateForInstalled[InstanceManagerInstanceDictionaryUpdateCandidateKey]]];
    installedInstanceUpdateItem.enabled = YES;
  } else {
    installedInstanceUpdateItem.title = @"No updates";
    installedInstanceUpdateItem.enabled = NO;
  }
}

-(void)updateDidStart:(NSNotification*)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
  self->statusItem.menu = self->progressMenu;
  });
}

-(void)updateDidEnd:(NSNotification*)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
  self->statusItem.menu = self->statusMenu;
  });
}

-(void)xferDidStart:(NSNotification*)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
  self->progressIndicator.doubleValue = 0.0;
  self.menuIcon = [self imageOfView:self->progressIndicator];
  });
}

-(void)xferDidEnd:(NSNotification*)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
  if(self.isUpdateAvailable) {
    self.menuIcon = self->statusIcons[kStateUpdateAvailable];
  } else {
    self.menuIcon = self->statusIcons[kStateNone];
  }
  });
}

-(void)xferProgressDidChange:(NSNotification*)notification {
  dispatch_async(dispatch_get_main_queue(), ^{
  NSDictionary *progressInfo = notification.userInfo;
  double progress = [progressInfo[SimpleCURLDownloadProgressDictionaryDLProgressKey] doubleValue]*100.0;
  self->progressIndicator.doubleValue = progress;
  self.menuIcon = [self imageOfView:self->progressIndicator];
  });
}

- (NSImage *)imageOfView:(NSView*)view
{
  NSRect viewRect = view.bounds;
  NSSize viewSize = viewRect.size;

  NSBitmapImageRep *imageRep = [view bitmapImageRepForCachingDisplayInRect:viewRect];
  imageRep.size = viewSize;
  [view cacheDisplayInRect:viewRect toBitmapImageRep:imageRep];

  NSImage* image = [[NSImage alloc] initWithSize:viewSize];
  [image addRepresentation:imageRep];

  return image;
}

@end
