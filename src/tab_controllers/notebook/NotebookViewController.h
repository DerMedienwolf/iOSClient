//
//  NotebookViewController.h
//  ARIS
//
//  Created by Phil Dougherty on 11/4/13.
//
//

#import "ARISGamePlayTabBarViewController.h"

@protocol NotebookViewControllerDelegate <GamePlayTabBarViewControllerDelegate>
@end

@interface NotebookViewController : ARISGamePlayTabBarViewController

- (id) initWithDelegate:(id<NotebookViewControllerDelegate>)d;

@end
