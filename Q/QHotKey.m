//
//  QHotKey.m
//  Q Launcher
//
//  Created by Woody Beckert on 16/06/2015.
//  Copyright (c) 2015 Abhi Beckert. All rights reserved.
//

#import "QHotKey.h"

@implementation QHotKey

- (instancetype)initWithShift:(BOOL)shiftModifier Control:(BOOL)controlModifier alt:(BOOL)altModifier command:(BOOL)commandModifier keycode:(UInt16)keycode
{
  if (!(self = [super init])) {
    return nil;
  }
  
  self.controlModifier = controlModifier;
  self.altModifier = altModifier;
  self.commandModifier = commandModifier;
  self.shiftModifier = shiftModifier;
  
  self.keycode = keycode;
  
  return self;
}

- (instancetype)initWithRecord:(NSDictionary *)record
{
  return [self initWithShift:[record[@"modifiers"] containsObject:@"shift"] Control:[record[@"modifiers"] containsObject:@"control"] alt:[record[@"modifiers"] containsObject:@"alt"] command:[record[@"modifiers"] containsObject:@"command"] keycode:[record[@"keycode"] shortValue]];
}

- (NSString *)displayString
{
  NSMutableString *displayString = [[NSMutableString alloc] init];
  
  // modifiers
  if (self.controlModifier) {
    [displayString appendString:@"⌃"];
  }
  if (self.altModifier) {
    [displayString appendString:@"⌥"];
  }
  if (self.shiftModifier) {
    [displayString appendString:@"⇧"];
  }
  if (self.commandModifier) {
    [displayString appendString:@"⌘"];
  }
  
  // key
  [displayString appendString:[[self class] stringFromKeycode:self.keycode]];
  
  return displayString.copy;
}

+ (NSString *)stringFromKeycode:(UInt16)keycode
{
  // special key
  switch (keycode)
  {
    case 36: return @"⏎";
    case 48: return @"⇥";
    case 49: return @"␣";
    case 51: return @"⌫";
    case 52: return @"↵";
    case 53: return @"⎋";
    case 71: return @"Clear";
    case 76: return @"↵";
    case 96: return @"F5";
    case 97: return @"F6";
    case 98: return @"F7";
    case 99: return @"F3";
    case 100: return @"F8";
    case 101: return @"F9";
    case 103: return @"F11";
    case 105: return @"F13";
    case 107: return @"F14";
    case 109: return @"F10";
    case 111: return @"F12";
    case 113: return @"F15";
    case 114: return @"Help";
    case 115: return @"Home";
    case 116: return @"Page Up";
    case 117: return @"⌦";
    case 118: return @"F4";
    case 119: return @"End";
    case 120: return @"F2";
    case 121: return @"Page Down";
    case 122: return @"F1";
    case 123: return @"←";
    case 124: return @"→";
    case 125: return @"↓";
    case 126: return @"↑";
  }
  
  // basic key
  TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
  CFDataRef layoutData =
  TISGetInputSourceProperty(currentKeyboard,
                            kTISPropertyUnicodeKeyLayoutData);
  const UCKeyboardLayout *keyboardLayout =
  (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
  
  UInt32 keysDown = 0;
  UniChar chars[4];
  UniCharCount realLength;
  
  UCKeyTranslate(keyboardLayout,
                 keycode,
                 kUCKeyActionDisplay,
                 0,
                 LMGetKbdType(),
                 kUCKeyTranslateNoDeadKeysBit,
                 &keysDown,
                 sizeof(chars) / sizeof(chars[0]),
                 &realLength,
                 chars);
  CFRelease(currentKeyboard);
  
  NSString *keyString = CFBridgingRelease(CFStringCreateWithCharacters(kCFAllocatorDefault, chars, 1));
  
  return [keyString uppercaseString];
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<QHotKey %@>", self.displayString];
}

- (NSDictionary *)record
{
  NSMutableArray *modifiers = [NSMutableArray array];
  if (self.shiftModifier) {
    [modifiers addObject:@"shift"];
  }
  if (self.controlModifier) {
    [modifiers addObject:@"control"];
  }
  if (self.altModifier) {
    [modifiers addObject:@"alt"];
  }
  if (self.commandModifier) {
    [modifiers addObject:@"command"];
  }
  
  return @{@"modifiers": modifiers.copy, @"keycode": [NSNumber numberWithShort:self.keycode]};
}

@end
