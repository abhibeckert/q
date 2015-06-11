//
//  DuxOpenQuicklyPanelController.m
//  Dux
//
//  Created by Abhi Beckert on 8/09/2013.
//
//

#import "DuxQuickFindPanelController.h"
#import <objc/message.h>
#import "QAppDelegate.h"

@interface DuxQuickFindPanelController()

@property DuxQuickFindPanel *panel;
@property NSTextField *searchField;
@property NSTableView *resultsView;
@property NSPopUpButton *menuButton;

@property (nonatomic) NSMutableArray *contents;
@property (nonatomic) NSMutableArray *oldContentsUrls;
@property (nonatomic) id expressionResult;


@property NSDate *lastReload;

@property NSMutableArray *matchingResultIndexes;

@end

@implementation DuxQuickFindPanelController

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;
  
  // create panel
  self.panel = [[DuxQuickFindPanel alloc] initWithContentRect:NSMakeRect(0, 0, 450, 240)];
  self.panel.backgroundColor = [NSColor whiteColor];
  
  
  // create search field
  self.searchField = [[NSTextField alloc] initWithFrame:NSMakeRect(8, self.panel.frame.size.height - 31, self.panel.frame.size.width - 16, 22)];
  [self.searchField.cell setPlaceholderString:@"What did you expect, an exploding pen?"];
  self.searchField.bordered = NO;
  self.searchField.focusRingType = NSFocusRingTypeNone;
  self.searchField.font = [NSFont systemFontOfSize:18];
  self.searchField.delegate = self;
  self.searchField.backgroundColor = [NSColor clearColor];
  [self.panel.contentView addSubview:self.searchField];
  
  // create menu
  self.menuButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(self.panel.frame.size.width - 30, self.panel.frame.size.height - 33, 25, 25) pullsDown:NO];
  [self.menuButton.menu addItemWithTitle:@"Preferences..." action:@selector(showPreferences:) keyEquivalent:@","];
  [self.menuButton.menu addItem:[NSMenuItem separatorItem]];
  [self.menuButton.menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
  [self.menuButton selectItem:nil];
  [self.panel.contentView addSubview:self.menuButton];
  
  // create search results view
  self.resultsView = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
  self.resultsView.headerView = nil;
  self.resultsView.backgroundColor = [NSColor clearColor];
  self.resultsView.usesAlternatingRowBackgroundColors = NO;
  self.resultsView.rowHeight = 42;
  self.resultsView.dataSource = self;
  self.resultsView.delegate = self;
  self.resultsView.target = self;
  self.resultsView.action = @selector(tableViewRowClicked:);
  
  NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"icon"];
  column.width = 50;
  column.dataCell = [[NSImageCell alloc] init];
  [self.resultsView addTableColumn:column];
  
  column = [[NSTableColumn alloc] initWithIdentifier:@"name"];
  column.width = self.panel.frame.size.width - 42;
  [column.dataCell setFont:[NSFont fontWithName:@"Helvetica Neue Light" size:32]];
  [self.resultsView addTableColumn:column];
  
  NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, self.panel.frame.size.width, self.panel.frame.size.height - 40)];
  scrollView.backgroundColor = self.panel.backgroundColor;
  scrollView.hasVerticalScroller = YES;
  scrollView.documentView = self.resultsView;
  [self.panel.contentView addSubview:scrollView];
  
  self.matchingResultIndexes = nil;
  
  return self;
}

- (NSString *)title
{
  return [self.searchField.cell placeholderString];
}

- (void)setTitle:(NSString *)title
{
  return [self.searchField.cell setPlaceholderString:title];
}

- (void)setContents:(NSArray *)contents
{
  _contents = contents.mutableCopy;
  [self reload];
}

- (void)orderFront
{
  NSRect screenFrame = [[NSScreen mainScreen] frame];
  
  CGFloat x = floor(screenFrame.origin.x + ((screenFrame.size.width - self.panel.frame.size.width) / 2));
  CGFloat y = floor(screenFrame.origin.y + ((screenFrame.size.height - self.panel.frame.size.height) / 1.5));
  
  [self.panel setFrame:NSMakeRect(x, y, self.panel.frame.size.width, self.panel.frame.size.height) display:NO];
  
  [self.panel makeKeyAndOrderFront:self];
  [self.panel makeFirstResponder:self.searchField];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
  NSUInteger expressionResult = self.expressionResult ? 1 : 0;
  
  if (!self.matchingResultIndexes)
    return expressionResult + self.contents.count;
  
  return expressionResult + self.matchingResultIndexes.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  if (self.expressionResult) {
    if (row == 0) {
      if ([tableColumn.identifier isEqualToString:@"icon"]) {
        return [NSApp applicationIconImage];
      } else {
        return self.expressionResult;
      }
    }
    row--;
  }
  
  if (!self.matchingResultIndexes) {
    return self.contents[row][tableColumn.identifier];
  }
  
  row = [self.matchingResultIndexes[row] integerValue];
  
  return self.contents[row][tableColumn.identifier];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
  [self evaluateExpression];
  [self reload];
}

- (void)evaluateExpression
{
  @try {
    NSExpression *expression = [NSExpression expressionWithFormat:self.searchField.stringValue];
    self.expressionResult = [expression expressionValueWithObject:nil context:nil];
  }
  @catch (NSException *exception) {
    self.expressionResult = nil;
  }
}

- (void)reload
{
  self.lastReload = [NSDate date];
  // no search string? show all possible items
  if (self.searchField.stringValue.length == 0) {
    self.matchingResultIndexes = nil;
    [self.resultsView reloadData];
    if (self.contents.count > 0)
      [self.resultsView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    
    return;
  }
  
  // build a regex pattern from the search string
  NSString *searchString = self.searchField.stringValue;
  NSMutableString *searchPattern = [NSMutableString stringWithString:@""];
  NSString *operatorChars = @"*?+[(){}^$|\\./";
  for (int charPos = 0; charPos < searchString.length; charPos++) {
    NSString *character = [searchString substringWithRange:NSMakeRange(charPos, 1)];
    
    if ([operatorChars rangeOfString:character].location != NSNotFound)
      character = [NSString stringWithFormat:@"\\%@", character];
    
    [searchPattern appendFormat:@"%@.*", character];
  }
  NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:searchPattern options:NSRegularExpressionCaseInsensitive error:NULL];
  
  // perform the search
  self.matchingResultIndexes = @[].mutableCopy;
  NSInteger contentsCount = self.contents.count;
  for (NSUInteger index = 0; index < contentsCount; index++) {
    NSString *name = self.contents[index][@"name"];
    
    if ([expression rangeOfFirstMatchInString:name options:0 range:NSMakeRange(0, name.length)].location == NSNotFound)
      continue;
    
    [self.matchingResultIndexes addObject:[NSNumber numberWithInteger:index]];
  }
  
  // update table view
  [self.resultsView reloadData];
  if (self.matchingResultIndexes.count > 0)
    [self.resultsView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}

- (void)tableViewRowClicked:(id)sender
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  [self.target performSelector:self.action withObject:self];
#pragma clang diagnostic pop
  
  [self.panel orderOut:self];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
  if (control == self.searchField) {
    if (commandSelector == @selector(insertNewline:) || [NSApp currentEvent].keyCode == 36/*return*/) {
      if ([self numberOfRowsInTableView:self.resultsView] > 0) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:self.action withObject:self];
#pragma clang diagnostic pop
      }
      
      [self.panel orderOut:self];
      return YES;
    }
    
    if (commandSelector == @selector(cancelOperation:)) {
      [self.panel orderOut:self];
      return YES;
    }
    
    if (commandSelector == @selector(moveDown:)) {
      NSInteger nextIndex = self.resultsView.selectedRow + 1;
      
      if (nextIndex >= [self numberOfRowsInTableView:self.resultsView])
        nextIndex = 0;
      
      [self.resultsView selectRowIndexes:[NSIndexSet indexSetWithIndex:nextIndex] byExtendingSelection:NO];
      [self.resultsView scrollRowToVisible:nextIndex];
      
      return YES;
    }
    
    if (commandSelector == @selector(moveUp:)) {
      NSInteger nextIndex = self.resultsView.selectedRow - 1;
      
      if (nextIndex < 0)
        nextIndex = [self numberOfRowsInTableView:self.resultsView] - 1;
      
      [self.resultsView selectRowIndexes:[NSIndexSet indexSetWithIndex:nextIndex] byExtendingSelection:NO];
      [self.resultsView scrollRowToVisible:nextIndex];
      
      return YES;
    }
  }
  
  return NO;
}

- (id)selectedResult
{
  if ([self numberOfRowsInTableView:self.resultsView] == 0)
    return nil;
  
  NSInteger row = [self.resultsView selectedRow];
  if (self.expressionResult) {
    if (row == 0)
      return nil;
    
    row--;
  }
  if (row < 0)
    row = 0;
  
  if (!self.matchingResultIndexes)
    return self.contents[row];
  
  row = [self.matchingResultIndexes[row] integerValue];
  return self.contents[row];
}

- (void)beginAddingFindResults
{
  if (!self.contents) {
    self.contents = [NSMutableArray array];
  }
  self.oldContentsUrls = [[self.contents valueForKey:@"url"] mutableCopy];
}

- (void)addFindResult:(NSDictionary *)resultRecord
{
  // check if contents already has this url
  NSURL *url = resultRecord[@"url"];
  if ([self.oldContentsUrls containsObject:url]) {
    [self.oldContentsUrls removeObject:resultRecord[@"url"]];
    return;
  }
  
  
  // insert new item
  NSUInteger index = [self.contents indexOfObject:resultRecord inSortedRange:NSMakeRange(0, self.contents.count) options:NSBinarySearchingInsertionIndex usingComparator:^NSComparisonResult(NSDictionary *leftObj, NSDictionary *rightObj) {
    NSString *leftName = leftObj[@"name"];
    NSUInteger leftLength = leftName.length;
    
    NSString *rightName = rightObj[@"name"];
    NSUInteger rightLength = rightName.length;
    
    if (leftLength < rightLength) {
      return -1;
    } else if (leftLength > rightLength) {
      return 1;
    } else {
      return [leftName compare:rightName];
    }
  }];
  [self.contents insertObject:resultRecord atIndex:index];
  
  if (self.lastReload && self.lastReload.timeIntervalSinceNow < -0.05)
    [self reload];
}

- (void)endAddingFindResults
{
  // delete all urls that weren't found in the new search
  for (NSURL *url in self.oldContentsUrls) {
    NSInteger removeIndex = [self.contents indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
      return [[obj valueForKey:@"url"] isEqual:url];
    }];
    
    
    if (removeIndex == NSNotFound)
      continue;
    
    [self.contents removeObjectAtIndex:removeIndex];
  }
  self.oldContentsUrls = nil;
  
  [self reload];
}

@end
