//
//  TabsModel.h
//  ARIS
//
//  Created by Phil Dougherty on 2/13/13.
//
//

#import <Foundation/Foundation.h>
#import "ARISModel.h"
#import "Tab.h"

@interface TabsModel : ARISModel

- (Tab *) tabForId:(long)tab_id;
- (Tab *) tabForType:(NSString *)t;
- (NSArray *) playerTabs;
- (void) requestTabs;
- (void) requestPlayerTabs;

@end

