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
@property (strong) NSURL *searchUrl;

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
  
  self.searchUrl = [NSURL fileURLWithPath:@"/Applications"];
  
  // init hot key
  //handler
  hotKeyFunction = NewEventHandlerUPP(hotKeyHandler);
  EventTypeSpec eventType;
  eventType.eventClass = kEventClassKeyboard;
  eventType.eventKind = kEventHotKeyReleased;
  InstallApplicationEventHandler(hotKeyFunction,1,&eventType, (__bridge void*)self,NULL);
  //hotkey
  UInt32 keyCode = 0x31; //space
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
  
  [self updateSearchResults];
}

- (void)showPanel
{
//  [self updateSearchResults]; // we kind of suck while updating, so don't do it everytime we show the panel
  
  [self.findController orderFront];
}

- (void)updateSearchResults
{
  // cancel all operation queues
  [self.updateSearchPathsQueue cancelAllOperations];
  
  // enumerate all the files in the path
  NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:self.searchUrl includingPropertiesForKeys:@[] options:0 errorHandler:nil];
  
  __block NSBlockOperation *updateSearchPathsBlock = [NSBlockOperation blockOperationWithBlock:^{
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.findController beginAddingFindResults];
    });
    
    for (NSURL *fileURL in enumerator) {
      if (updateSearchPathsBlock.isCancelled)
        return;
      
      if ([fileURL.pathExtension isEqualToString:@"app"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self.findController addFindResult:@{@"name":fileURL.lastPathComponent.stringByDeletingPathExtension, @"url":fileURL, @"icon":[[NSWorkspace sharedWorkspace] iconForFile:fileURL.path]}];
        });
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
  
  [[NSWorkspace sharedWorkspace] openURL:result[@"url"]];
}

@end
