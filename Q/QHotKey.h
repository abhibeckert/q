//
//  QHotKey.h
//  Q Launcher
//
//  Created by Woody Beckert on 16/06/2015.
//  Copyright (c) 2015 Abhi Beckert. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Carbon/Carbon.h> /* For kVK_ constants, and TIS functions. */

@interface QHotKey : NSObject

- (instancetype)initWithShift:(BOOL)shiftModifier Control:(BOOL)controlModifier alt:(BOOL)altModifier command:(BOOL)commandModifier keycode:(UInt16)keycode;
- (instancetype)initWithRecord:(NSDictionary *)record;

@property BOOL shiftModifier;
@property BOOL controlModifier;
@property BOOL altModifier;
@property BOOL commandModifier;
@property UInt16 keycode;

@property (readonly) NSString *displayString;

@property (readonly) NSDictionary *record;

@end
