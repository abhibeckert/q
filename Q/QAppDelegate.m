//
//  QAppDelegate.m
//  Q
//
//  Created by Abhi Beckert on 26/11/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "QAppDelegate.h"

#import <Carbon/Carbon.h>

@interface QAppDelegate()

@property (strong) NSOperationQueue *updateSearchPathsQueue;
@property (strong) NSArray *searchUrls;
@property (strong) NSArray *searchExtensions;

- (void)showPanel;

@end

EventHandlerUPP hotKeyFunction;

pascal OSStatus hotKeyHandler(EventHandlerCallRef nextHandler,EventRef theEvent, void *userData)
{
  [NSApp activateIgnoringOtherApps:YES];
  
  QAppDelegate *appDelegate = (__bridge QAppDelegate *)(userData);
  [appDelegate showPanel];
  return noErr;
}

@implementation QAppDelegate

- (id)init
{
  if (![super init])
    return nil;
  
  self.updateSearchPathsQueue = [[NSOperationQueue alloc] init];
  self.updateSearchPathsQueue.maxConcurrentOperationCount = 1;
  
  self.searchUrls = @[[NSURL fileURLWithPath:@"/Applications"],
                      [NSURL fileURLWithPath:@"/Applications/Xcode.app/Contents/Applications/"],
                      [NSURL fileURLWithPath:@"~/Applications".stringByStandardizingPath],
                      [NSURL fileURLWithPath:@"/Library/PreferencePanes"],
                      [NSURL fileURLWithPath:@"~/Library/PreferencePanes".stringByStandardizingPath],
                      [NSURL fileURLWithPath:@"/System/Library/PreferencePanes"]];
  
  self.searchExtensions = @[@"app",
                            @"prefPane"];
  
  // init hot key
  //handler
  hotKeyFunction = NewEventHandlerUPP(hotKeyHandler);
  EventTypeSpec eventType;
  eventType.eventClass = kEventClassKeyboard;
  eventType.eventKind = kEventHotKeyReleased;
  InstallApplicationEventHandler(hotKeyFunction,1,&eventType, (__bridge void*)self,NULL);
  //hotkey
//  UInt32 keyCode = 0x31; //space
  UInt32 keyCode = 12; // q in qwerty
  EventHotKeyRef theRef = NULL;
  EventHotKeyID keyID;
  keyID.signature = 'QApp';
  keyID.id = 1;
  RegisterEventHotKey(keyCode,controlKey,keyID,GetApplicationEventTarget(),0,&theRef);
  
  return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  self.findController.target = self;
  self.findController.action = @selector(openFindResult:);
}

- (void)showPanel
{
  // update if we haven't in the last few seconds
  static NSDate *lastUpdate = nil;
  if (!lastUpdate || lastUpdate.timeIntervalSinceNow < -3) {
    [self updateSearchResults]; // we kind of suck while updating, so don't do it everytime we show the panel
    lastUpdate = [NSDate date];
  }
  
  [self.findController orderFront];
}

- (void)updateSearchResults
{
  // cancel all operation queues
  [self.updateSearchPathsQueue cancelAllOperations];
  __block NSBlockOperation *updateSearchPathsBlock = [NSBlockOperation blockOperationWithBlock:^{
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.findController beginAddingFindResults];
    });
    
    for (NSURL *searchUrl in self.searchUrls) {
      @autoreleasepool {
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:searchUrl.path])
          continue;
        
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:searchUrl includingPropertiesForKeys:@[] options:0 errorHandler:nil];
        
        for (NSURL *fileURL in enumerator) {
          @autoreleasepool {
            if (updateSearchPathsBlock.isCancelled)
              return;
            
            if ([self.searchExtensions containsObject:fileURL.pathExtension]) {
              dispatch_async(dispatch_get_main_queue(), ^{
                [self.findController addFindResult:@{@"name":fileURL.lastPathComponent.stringByDeletingPathExtension, @"url":fileURL, @"icon":[[NSWorkspace sharedWorkspace] iconForFile:fileURL.path]}];
              });
              
              [enumerator skipDescendents];
            }
          }
        }
      }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.findController endAddingFindResults];
    });
  }];
  
  [self.updateSearchPathsQueue addOperation:updateSearchPathsBlock];
}

- (void)openFindResult:(DuxQuickFindPanelController *)sender
{
  NSDictionary *result = [sender selectedResult];
  NSURL *url = result[@"url"];
  
  if ([NSApp currentEvent].modifierFlags & NSCommandKeyMask) {
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[url]];
  } else {
    [[NSWorkspace sharedWorkspace] openURL:url];
  }
  return;
  
  
}

@end
