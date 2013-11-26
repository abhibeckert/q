//
//  DuxQuickFindPanel.m
//  Dux
//
//  Created by Abhi Beckert on 8/09/2013.
//
//

#import "DuxQuickFindPanel.h"

@implementation DuxQuickFindPanel

- (instancetype)initWithContentRect:(NSRect)contentRect
{
  if (!(self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES]))
    return nil;
  
  return self;
}

- (BOOL)hasShadow
{
  return YES;
}

- (BOOL)canBecomeMainWindow
{
  return NO;
}

- (BOOL)canBecomeKeyWindow
{
  return YES;
}

@end
