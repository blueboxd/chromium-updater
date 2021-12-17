//
//  main.m
//  Chromium Updater
//
//  Created by bluebox on 2021/12/03.
//  Copyright © 2021 bluebox. All rights reserved.
//

#import <Cocoa/Cocoa.h>

void uncaughtExceptionHandler(NSException *exception)
{
    NSLog(@"%@", exception.name);
    NSLog(@"%@", exception.reason);
    NSLog(@"%@", exception.callStackSymbols);
}

int main(int argc, const char * argv[]) {
  @autoreleasepool {
      // Setup code that might create autoreleased objects goes here.
  }
  NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
  return NSApplicationMain(argc, argv);
}
