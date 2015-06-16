//
//  QAppDelegate.h
//  Q
//
//  Created by Abhi Beckert on 26/11/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DuxQuickFindPanelController.h"
#import "DuxQuickFindPanel.h"

@class QHotKeyTextField;

@interface QAppDelegate : NSObject <NSApplicationDelegate>

@property (strong) IBOutlet DuxQuickFindPanelController *findController;
@property (strong) IBOutlet NSWindow *preferencesWindow;
@property (strong) IBOutlet QHotKeyTextField *preferencesHotkeyView;

- (IBAction)showPreferences:(id)sender;

@end
