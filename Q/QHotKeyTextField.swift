//
//  QHotKeyTextField.swift
//  Q Launcher
//
//  Created by Woody Beckert on 12/06/2015.
//  Copyright (c) 2015 Abhi Beckert. All rights reserved.
//

import Cocoa

class QHotKeyTextField: NSView
{
  weak var delegate:QHotKeyTextFieldDelegate?
  
  var hotkeyValue: QHotKey?
  
  override var acceptsFirstResponder: Bool { get { return true } }
  
  override func keyDown(theEvent: NSEvent)
  {
    // check for mofifiers
    let shiftDown = (theEvent.modifierFlags & .ShiftKeyMask != nil)
    let commandDown = (theEvent.modifierFlags & .CommandKeyMask != nil)
    let controlDown = (theEvent.modifierFlags & .ControlKeyMask != nil)
    let altDown = (theEvent.modifierFlags & .AlternateKeyMask != nil)
    let functionDown = (theEvent.modifierFlags & .FunctionKeyMask != nil)
    
    // if there are no modifiers, reject that hotkey
    if !shiftDown && !commandDown && !controlDown && !altDown && !functionDown {
      return super.keyDown(theEvent)
    }
    
    // save it
    self.hotkeyValue = QHotKey(shift: shiftDown, control: controlDown, alt: altDown, command: commandDown, keycode: theEvent.keyCode)
    self.delegate?.hotKeyDidChange(self, newValue: self.hotkeyValue!)
    
    self.setNeedsDisplayInRect(self.bounds)
  }
  
  override func drawRect(dirtyRect: NSRect)
  {
    // apply focus ring filter
    if self.window?.firstResponder == self {
      NSGraphicsContext.saveGraphicsState()
      NSSetFocusRingStyle(.Above)
    }
    
    // fill the entire view (this will also draw the focus ring)
    NSColor.whiteColor().set()
    NSRectFill(self.bounds)
    
    // clear the focus ring
    if self.window?.firstResponder == self {
      NSGraphicsContext.restoreGraphicsState()
    }
    
    // stroke our border
    let innerBorder = NSBezierPath(rect: NSRect(x: self.bounds.origin.x + 0.5, y: self.bounds.origin.y + 0.5, width: self.bounds.size.width - 1, height: self.bounds.size.height - 1))
    NSColor(white: 0.94, alpha: 1.0).set();
    innerBorder.stroke()
    
    let outerBorder = NSBezierPath(rect: self.bounds)
    NSColor(white: 0.69, alpha: 1.0).set();
    outerBorder.stroke()
    
    // draw hotkey string
    let hotkeyString: String
    if let key = self.hotkeyValue {
      hotkeyString = key.displayString
    } else {
      hotkeyString = "-"
    }
    
    let size = (hotkeyString as NSString).sizeWithAttributes(nil)
    (hotkeyString as NSString).drawAtPoint(NSPoint(x: (self.bounds.size.width / 2) - (size.width / 2), y: (self.bounds.size.height / 2) - (size.height / 2)), withAttributes:nil)

  }
  
  override func becomeFirstResponder() -> Bool {
    self.setNeedsDisplayInRect(self.bounds)
    
    return super.becomeFirstResponder()
  }
  
  override func resignFirstResponder() -> Bool {
    self.setNeedsDisplayInRect(self.bounds)
    
    return super.resignFirstResponder()
  }
}

@objc protocol QHotKeyTextFieldDelegate:class
{
  func hotKeyDidChange(field:QHotKeyTextField, newValue:QHotKey)
}