//
//  DialogScriptViewController.h
//  ARIS
//
//  Created by Phil Dougherty on 8/5/13.
//
//

#import <UIKit/UIKit.h>
#import "ARISViewController.h"

@class Dialog;
@class DialogScript;

@protocol DialogScriptViewControllerDelegate
- (void) dialogScriptChosen:(DialogScript *)s;
@end

@interface DialogScriptViewController : ARISViewController
- (id) initWithDialog:(Dialog *)n frame:(CGRect)f delegate:(id<DialogScriptViewControllerDelegate>)d;
- (void) loadScript:(DialogScript *)s;
@end
