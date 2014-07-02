//
//  InstantiableViewController.h
//  ARIS
//
//  Created by Phil Dougherty on 4/29/13.
//
//

#import <UIKit/UIKit.h>
#import "ARISViewController.h"

@class InstantiableViewController;
@protocol InstantiableViewControllerDelegate
- (void) instantiableViewControllerRequestsDismissal:(InstantiableViewController *)ivc;
@end

@interface InstantiableViewController : ARISViewController
@end
