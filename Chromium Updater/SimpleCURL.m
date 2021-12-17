//
//  SimleCURL.m
//  Chromium Updater
//
//  Created by bluebox on 2021/12/04.
//  Copyright © 2021 bluebox. All rights reserved.
//

#import "SimpleCURL.h"
#include "curl/curl.h"

NSNotificationName SimpleCURLDownloadDidStartNotificationKey = @"SimpleCURLDownloadDidStartNotificationKey";
NSNotificationName SimpleCURLDownloadDidEndNotificationKey = @"SimpleCURLDownloadDidEndNotificationKey";

NSNotificationName SimpleCURLDownloadProgressDidChangeNotificationKey = @"SimpleCURLDownloadProgressDidChangeNotificationKey";
NSString* const SimpleCURLDownloadProgressDictionaryURLKey = @"url";
NSString* const SimpleCURLDownloadProgressDictionaryULProgressKey = @"ulprogress";
NSString* const SimpleCURLDownloadProgressDictionaryDLProgressKey = @"dlprogress";


size_t curl_read_cb(void* ptr, size_t size, size_t nmemb, void* stream) {
  NSMutableData *data = (__bridge NSMutableData*)stream;
  [data appendBytes:ptr length:size*nmemb];
  return size*nmemb;
}

int curl_progress_cb(void *clientp,
                      double dltotal,
                      double dlnow,
                      double ultotal,
                      double ulnow) {

  NSString *url = (__bridge NSString*)clientp;
  double dlprogress = dltotal?(dlnow/dltotal):0;
  double ulprogress = ultotal?(ulnow/ultotal):0;

  [[NSNotificationCenter defaultCenter] postNotificationName:SimpleCURLDownloadProgressDidChangeNotificationKey object:nil userInfo:@{
    SimpleCURLDownloadProgressDictionaryURLKey:url,
    SimpleCURLDownloadProgressDictionaryULProgressKey:[NSNumber numberWithDouble:ulprogress],
    SimpleCURLDownloadProgressDictionaryDLProgressKey:[NSNumber numberWithDouble:dlprogress]
  }];
  return 0;
}

@implementation SimpleCURL
+ (NSData*)retrieveFor:(NSString*)url{
  NSMutableData *result = [NSMutableData new];

  CURL *curl = curl_easy_init();
  if(!curl) {
    NSLog(@"curl_easy_init failed");
    return nil;
  }

  curl_easy_setopt(curl, CURLOPT_URL, [url cStringUsingEncoding:NSUTF8StringEncoding]);
  curl_easy_setopt(curl, CURLOPT_USERAGENT, "Chromium Updater");
  curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, true);
  curl_easy_setopt(curl, CURLOPT_FAILONERROR, true);

  curl_easy_setopt(curl, CURLOPT_CAINFO, ([[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"cacert.pem"] cStringUsingEncoding:NSUTF8StringEncoding]) );

  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_read_cb);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, result);
  curl_easy_setopt(curl, CURLOPT_PROGRESSFUNCTION, curl_progress_cb);
  curl_easy_setopt(curl, CURLOPT_PROGRESSDATA, url);
  curl_easy_setopt(curl, CURLOPT_NOPROGRESS, false);

  CURLcode res;
  res = curl_easy_perform(curl);
  curl_easy_cleanup(curl);

  if(res != CURLE_OK) {
    NSLog(@"curl_easy_perform error:%u",res);
    return nil;
  }
  return result;
}

+ (NSData*)curlFor:(NSString*)url{
  [[NSNotificationCenter defaultCenter] postNotificationName:SimpleCURLDownloadDidStartNotificationKey object:self userInfo:@{
    SimpleCURLDownloadProgressDictionaryURLKey:url,
  }];

  NSData *result = [self retrieveFor:url];

  [[NSNotificationCenter defaultCenter] postNotificationName:SimpleCURLDownloadDidEndNotificationKey object:self userInfo:@{
    SimpleCURLDownloadProgressDictionaryURLKey:url,
  }];

  return result;
}
@end
