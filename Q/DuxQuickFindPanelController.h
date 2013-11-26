//
//  DuxOpenQuicklyPanelController.h
//  Dux
//
//  Created by Abhi Beckert on 8/09/2013.
//
//

#import <Foundation/Foundation.h>
#import "DuxQuickFindPanel.h"

@interface DuxQuickFindPanelController : NSObject <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>

// title of the panel
@property (strong,nonatomic) NSString *title;

// target/action when a find result is chosen by the user
@property (assign) id target;
@property SEL action;

// the user's currently selected seacrh result
@property (readonly) id selectedResult;

// show the panel
- (void)orderFront;

/**
 * The find panel assumes you will have a background therad searching for results. To do it, you must:
 *
 * call -beginAddingFindResults. This tells the find panel all previously added find results are probably not valid anymore, but will not actually remove those results from the panel.
 * call -addFindResult: for each result. The dictionary must contain a @"name" property, in addition to any other custom data you want attached to the name.
 * call -endAddingFindResults. This tells the find panel you've finished searching and everything just added is up to date.
 * 
 * begin/end calls do not need to be paired perfectly, just call begin whenever you start searching from scratch, and end whenever you have *finished* searching.
 */
- (void)beginAddingFindResults;
- (void)addFindResult:(NSDictionary *)resultRecord;
- (void)endAddingFindResults;

@end
