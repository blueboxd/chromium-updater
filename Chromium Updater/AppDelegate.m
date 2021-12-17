//
//  AppDelegate.m
//  Chromium Updater
//
//  Created by bluebox on 2021/12/03.
//  Copyright © 2021 bluebox. All rights reserved.
//

#import "AppDelegate.h"
#import "InstanceManager.h"
#import "StatusMenuManager.h"
#import "SimpleCURL.h"

NSNotificationName AppDelegateUpdateProgressDidStartNotificationKey = @"AppDelegateUpdateProgressDidStartNotificationKey";
NSNotificationName AppDelegateUpdateProgressDidEndNotificationKey = @"AppDelegateUpdateProgressDidEndNotificationKey";

@implementation AppDelegate {
IBOutlet InstanceManager *instanceManager;
}

- (IBAction)downloadAction:(NSMenuItem*)sender {
  NSDictionary *instance = ((__bridge NSDictionary*)((void*)sender.tag));
//  NSLog(@"downloadAction:%@",instance);

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:AppDelegateUpdateProgressDidStartNotificationKey object:self userInfo:instance];
    NSString *downloadedApp = [self downloadAndExpand:instance];
    [[NSNotificationCenter defaultCenter] postNotificationName:AppDelegateUpdateProgressDidEndNotificationKey object:self userInfo:instance];
    if(downloadedApp)
      [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:downloadedApp]]];
  });
}

- (IBAction)showInFinderAction:(NSMenuItem*)sender {
  NSDictionary *instance = ((__bridge NSDictionary*)((void*)sender.tag));
//  NSLog(@"showInFinderAction:%@",instance);
  [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[instance[InstanceManagerInstanceDictionaryURLKey]]];
}

- (NSRunningApplication*)getRunningAppByBundlePath:(NSString*)path {
  //NSString *targetPath = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
  NSArray *apps = [[NSWorkspace sharedWorkspace] runningApplications];
  for(NSRunningApplication* app in apps) {
    NSURL *curURL = [app bundleURL];
    //NSLog(@"%@",[curURL path]);
    if ([[curURL path] isEqualToString:path]) {
      return app;
    }
  }
  return nil;
}

- (IBAction)updateAction:(NSMenuItem*)sender {
  NSDictionary *instanceInfo = ((__bridge NSDictionary*)((void*)sender.tag));
//  NSLog(@"updateAction:%@",instanceInfo);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:AppDelegateUpdateProgressDidStartNotificationKey object:self userInfo:instanceInfo];
    [self->instanceManager stopTimer];
    [self updateInstance:instanceInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:AppDelegateUpdateProgressDidEndNotificationKey object:self userInfo:instanceInfo];
    [self->instanceManager startTimer];
  });
}

- (IBAction)checkNowAction:(NSMenuItem*)sender {
  [instanceManager refreshLocalRevisions];
  [instanceManager refreshRemoteRevisions];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [instanceManager refreshLocalRevisions];
  [instanceManager refreshRemoteRevisions];
  [instanceManager startTimer];
}

- (void)updateInstance:(NSDictionary*)instanceInfo {

  NSString *downloadedAppPath = [self downloadAndExpand:instanceInfo[InstanceManagerInstanceDictionaryUpdateCandidateKey]];
  if(!downloadedAppPath) {
    return;
  }

  NSURL *currentAppURL = instanceInfo[InstanceManagerInstanceDictionaryURLKey];

  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
  [[NSWorkspace sharedWorkspace] recycleURLs:@[currentAppURL] completionHandler:^(NSDictionary *newURLs, NSError *error) {
    dispatch_semaphore_signal(sema);
  }];
  });
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

  NSError *err;
  [[NSFileManager defaultManager] moveItemAtPath:downloadedAppPath toPath:[currentAppURL path] error:&err];

  NSRunningApplication *instance = [self getRunningAppByBundlePath:[currentAppURL path]];
  if(instance) {
    if([instance terminate]) {
      int tries=0;
      while (![instance isTerminated]) {
        sleep(1);
        tries++;
        if(tries>10)break;
      }
      [[NSWorkspace sharedWorkspace] launchApplicationAtURL:currentAppURL options:NSWorkspaceLaunchDefault configuration:nil error:&err];
    }
  }
}

- (NSString*)downloadAndExpand:(NSDictionary*)build {
  NSData *archive = [SimpleCURL curlFor:build[InstanceManagerInstanceDictionaryURLKey]];
  if(archive){
    NSString *workingPath = NSTemporaryDirectory();
    NSURL *archivePath = [NSURL fileURLWithPath:[workingPath stringByAppendingString:[build[InstanceManagerInstanceDictionaryURLKey] lastPathComponent]]];
    [archive writeToURL:archivePath atomically:NO];

    NSString *stdoutStr, *stderrStr;
    int32_t status = [self execSystemCmd:@"/bin/sh"
      withArgs:@[@"-c",[NSString stringWithFormat:@"cd %@;\"%@\"/xzdec %@|/usr/bin/tar xvf - 2>&1|grep app|head",workingPath,[[NSBundle mainBundle] builtInPlugInsPath],[archivePath path]]]
      withStdIn:@[]
      withStdOut:&stdoutStr
      withStdErr:&stderrStr
    ];
    NSArray *extracted = [stdoutStr componentsSeparatedByString:@"\n"];
    NSString *appPath = [extracted[0] componentsSeparatedByString:@" "][1];

    if(!status)
      return [workingPath stringByAppendingString:appPath];
  }
  return nil;
}

- (int32_t)execSystemCmd:(NSString*)cmd withArgs:(NSArray*)args withStdIn:(NSArray*)stdinArgs withStdOut:(NSString**)stdoutStr withStdErr:(NSString**)stderrStr {
  NSPipe *stdoutPipe = [NSPipe pipe];
  NSFileHandle *stdoutFile = stdoutPipe.fileHandleForReading;
  NSPipe *stderrPipe = [NSPipe pipe];
  NSFileHandle *stderrFile = stderrPipe.fileHandleForReading;
  NSPipe *stdinPipe = [NSPipe pipe];
  NSFileHandle *stdinFile = stdinPipe.fileHandleForWriting;

  NSTask *task = [NSTask new];
  task.launchPath = cmd;
  task.arguments = args;
  task.standardOutput = stdoutPipe;
  task.standardError = stderrPipe;
  task.standardInput = stdinPipe;

  [task launch];
  [stdinArgs enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop){
    [stdinFile writeData:[obj dataUsingEncoding:NSUTF8StringEncoding]];
  }];
  [task waitUntilExit];

  NSData *stdoutData = [stdoutFile readDataToEndOfFile];
  [stdoutFile closeFile];
  *stdoutStr = [[NSString alloc] initWithData: stdoutData encoding: NSUTF8StringEncoding];

  NSData *stderrData = [stderrFile readDataToEndOfFile];
  [stderrFile closeFile];
  *stderrStr = [[NSString alloc] initWithData: stderrData encoding: NSUTF8StringEncoding];
//  NSLog(@"execSystemCmd(%@):terminationStatus: %d\nstdout: %@\nstderr: %@",cmd,task.terminationStatus,*stdoutStr,*stderrStr);
  return task.terminationStatus;
}

@end
