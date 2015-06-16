//
//  QAppDelegate.m
//  Q
//
//  Created by Abhi Beckert on 26/11/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "QAppDelegate.h"
#import "Q_Launcher-Swift.h"
#import <Carbon/Carbon.h>
#import "QHotKey.h"

@interface QAppDelegate() <QHotKeyTextFieldDelegate> {
  EventHotKeyRef hotkeyRef;
}

@property (strong) NSOperationQueue *updateSearchPathsQueue;
@property NSDictionary *searchMap;
@property QHotKey *hotkey;

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
  
  // register default preferences
  NSDictionary *defaults = @{@"showDockIcon": [NSNumber numberWithBool:YES],
                             @"openAtLogin": [NSNumber numberWithBool:NO],
                             @"hotkey": @{@"modifiers": @[@"control"], @"keycode": @12}, // 12 is "q" in querty
                             @"sortOverrides": @{},
                             @"searchMap": @[
                                 @{@"path": @"/Applications", @"extensions": @"app"},
                                 @{@"path": @"/Applications/Xcode.app/Contents/Applications/", @"extensions": @"app"},
                                 @{@"path": @"/Library/PreferencePanes", @"extensions": @"prefPane"},
                                 @{@"path": @"/System/Library/PreferencePanes", @"extensions": @"prefPane"}
                                 ]};
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
  
  self.updateSearchPathsQueue = [[NSOperationQueue alloc] init];
  self.updateSearchPathsQueue.maxConcurrentOperationCount = 1;
  
  self.searchMap = [defaults objectForKey:@"searchMap"];
  
  // init hot key
  self.hotkey = [[QHotKey alloc] initWithRecord:[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"hotkey"]];
  
  //handler
  hotKeyFunction = NewEventHandlerUPP(hotKeyHandler);
  EventTypeSpec eventType;
  eventType.eventClass = kEventClassKeyboard;
  eventType.eventKind = kEventHotKeyPressed;
  InstallApplicationEventHandler(hotKeyFunction,1,&eventType, (__bridge void*)self,NULL);
  //hotkey
  UInt32 keyCode = self.hotkey.keycode;
  EventHotKeyID keyID;
  keyID.signature = 'QApp';
  keyID.id = 1;
  
  UInt32 modifiers = 0;
  if (self.hotkey.shiftModifier) {
    modifiers |= shiftKey;
  }
  if (self.hotkey.controlModifier) {
    modifiers |= controlKey;
  }
  if (self.hotkey.altModifier) {
    modifiers |= optionKey;
  }
  if (self.hotkey.commandModifier) {
    modifiers |= cmdKey;
  }
  
  RegisterEventHotKey(keyCode,modifiers,keyID,GetApplicationEventTarget(),0,&hotkeyRef);
  
  // wait a long time after launch, then generate our index (we don't want to slow down user login but we would like to be ready by the time the user uses our app)
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(90 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self updateSearchResults];
  });
  
  // show the dock icon?
  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"showDockIcon"]) {
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
  }
  
//  // open at login? http://blog.timschroeder.net/2012/07/03/the-launch-at-login-sandbox-project/
//  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"openAtLogin"]) {
//    NSLog(@"Open at login not yet implemented");
//  }
  
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
    
    for (NSDictionary *mapRecord in self.searchMap) {
      @autoreleasepool {
        NSURL *searchUrl = [NSURL URLWithString:mapRecord[@"path"]];
        NSArray *searchExtensions = [mapRecord[@"extensions"] componentsSeparatedByString:@","];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:searchUrl.path])
          continue;
        
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:searchUrl includingPropertiesForKeys:@[] options:0 errorHandler:nil];
        
        for (NSURL *fileURL in enumerator) {
          @autoreleasepool {
            if (updateSearchPathsBlock.isCancelled)
              return;
            
            if (![searchExtensions containsObject:fileURL.pathExtension])
              continue;
            
            NSDictionary *bundleInfo = [[NSBundle bundleWithURL:fileURL] localizedInfoDictionary];
            NSString *name = [bundleInfo valueForKey:@"CFBundleDisplayName"];
            if (!name) {
              name = [bundleInfo valueForKey:@"CFBundleName"];
            }
            if (!name || name.length == 0) {
              name = fileURL.lastPathComponent.stringByDeletingPathExtension;
            }
            if ([fileURL.pathExtension isEqualToString:@"prefPane"]) {
              name = [name stringByAppendingString:@" Pref Pane"];
            }
            
            NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:fileURL.path];
            
            dispatch_async(dispatch_get_main_queue(), ^{
              [self.findController addFindResult:@{@"name":name, @"url":fileURL, @"icon":icon}];
            });
            
            [enumerator skipDescendents];
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

- (IBAction)showPreferences:(id)sender
{
  self.preferencesHotkeyView.hotkeyValue = [[QHotKey alloc] initWithRecord:[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"hotkey"]];
  self.preferencesHotkeyView.delegate = self;

  
  [self.findController orderOut];
  [self.preferencesWindow makeKeyAndOrderFront:self];
  

  
}

- (void)hotKeyDidChange:(QHotKeyTextField * __nonnull)field newValue:(QHotKey * __nonnull)newValue
{
  self.hotkey = newValue;
  
  [[NSUserDefaults standardUserDefaults] setObject:self.hotkey.record forKey:@"hotkey"];
  
  UnregisterEventHotKey(hotkeyRef);
  
  
  
  //handler
  hotKeyFunction = NewEventHandlerUPP(hotKeyHandler);
  EventTypeSpec eventType;
  eventType.eventClass = kEventClassKeyboard;
  eventType.eventKind = kEventHotKeyPressed;
  InstallApplicationEventHandler(hotKeyFunction,1,&eventType, (__bridge void*)self,NULL);
  //hotkey
  UInt32 keyCode = self.hotkey.keycode;
  EventHotKeyID keyID;
  keyID.signature = 'QApp';
  keyID.id = 1;
  
  UInt32 modifiers = 0;
  if (self.hotkey.shiftModifier) {
    modifiers |= shiftKey;
  }
  if (self.hotkey.controlModifier) {
    modifiers |= controlKey;
  }
  if (self.hotkey.altModifier) {
    modifiers |= optionKey;
  }
  if (self.hotkey.commandModifier) {
    modifiers |= cmdKey;
  }
  
  RegisterEventHotKey(keyCode,modifiers,keyID,GetApplicationEventTarget(),0,&hotkeyRef);
}

@end
