//
//  GamePlayViewController.m
//  ARIS
//
//  Created by Phil Dougherty on 5/2/13.
//
//

#import "GamePlayViewController.h"

#import "ARISAlertHandler.h"
#import "ARISNavigationController.h"

#import "GameNotificationViewController.h"
#import "DisplayQueueModel.h"
#import "AppModel.h"

#import "StateControllerProtocol.h"

#import "GamePlayTabSelectorViewController.h"
#import "PKRevealController.h"

#import "QuestsViewController.h"
#import "IconQuestsViewController.h"
#import "InventoryViewController.h"
#import "MapViewController.h"
#import "AttributesViewController.h"
#import "NotebookViewController.h"
#import "DecoderViewController.h"

#import "PlaqueViewController.h"
#import "ItemViewController.h"
#import "DialogViewController.h"
#import "WebPageViewController.h"
#import "NoteViewController.h"

//needed for orientation hack
#import "AudioVisualizerViewController.h"

@interface GamePlayViewController() <UINavigationControllerDelegate, GamePlayTabSelectorViewControllerDelegate, StateControllerProtocol, InstantiableViewControllerDelegate, GamePlayTabBarViewControllerDelegate, QuestsViewControllerDelegate, MapViewControllerDelegate, InventoryViewControllerDelegate, AttributesViewControllerDelegate, NotebookViewControllerDelegate, DecoderViewControllerDelegate, GameNotificationViewControllerDelegate, DisplayQueueModelDelegate>
{
    PKRevealController *gamePlayRevealController;
    GamePlayTabSelectorViewController *gamePlayTabSelectorController;
    
    GameNotificationViewController *gameNotificationViewController;
    DisplayQueueModel *displayQueue;
    
    id<GamePlayViewControllerDelegate> __unsafe_unretained delegate;
}

@end

@implementation GamePlayViewController

- (id) initWithDelegate:(id<GamePlayViewControllerDelegate>)d
{
    if(self = [super init])
    {
        delegate = d;
        
        //odd that a model is stored here- but it needs to communicate with the state of the display 
        //(is the display available for dequeue?)
        //One caveat is that it didn't exist to listen to the initial set of triggers to populate,
        //so on init (now), we need to manually flush the set of all available triggers through the queue
        displayQueue = [[DisplayQueueModel alloc] initWithDelegate:self];
        _ARIS_NOTIF_SEND_(@"MODEL_TRIGGERS_NEW_AVAILABLE",nil,@{@"added":@[]});
        //admittedly a bit hacky, but should be safe
        
        gameNotificationViewController = [[GameNotificationViewController alloc] initWithDelegate:self]; 
        gamePlayTabSelectorController = [[GamePlayTabSelectorViewController alloc] initWithDelegate:self];  
        gamePlayRevealController = [PKRevealController revealControllerWithFrontViewController:gamePlayTabSelectorController.firstViewController leftViewController:gamePlayTabSelectorController options:nil];
    }
    return self;
}

- (void) loadView
{
    [super loadView];
    
    gameNotificationViewController.view.frame = CGRectMake(0,0,0,0);
    [self.view addSubview:gameNotificationViewController.view]; 
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if(!currentChildViewController)
        [self displayContentController:gamePlayRevealController];
}

- (void) viewDidAppear:(BOOL)animated
{
    [displayQueue dequeueTrigger];
}

- (void) gamePlayTabBarViewControllerRequestsNav
{
    [self showNav];
}

- (void) showNav
{
    [gamePlayRevealController showViewController:gamePlayTabSelectorController];
}

- (void) viewControllerRequestedDisplay:(ARISNavigationController *)avc
{
    [gamePlayRevealController setFrontViewController:avc];
    [gamePlayRevealController showViewController:avc];
}

- (BOOL) displayTrigger:(Trigger *)t
{
    Instance *i = [_MODEL_INSTANCES_ instanceForId:t.instance_id];
    if(![self displayInstance:i]) return NO;
    [_MODEL_LOGS_ playerTriggeredTriggerId:t.trigger_id]; 
    return YES;   
}

- (BOOL) displayInstance:(Instance *)i
{
    if(!self.isViewLoaded || !self.view.window) return NO; //Doesn't currently have the view-heirarchy authority to display. Return that it failed to those who care
    
    ARISViewController *vc;
    if([i.object_type isEqualToString:@"PLAQUE"])
    {
        Plaque *p = [_MODEL_PLAQUES_ plaqueForId:i.object_id];
        [_MODEL_EVENTS_ runEventPackageId:p.event_package_id];
        vc = [[PlaqueViewController alloc] initWithInstance:i delegate:self];
    }
    if([i.object_type isEqualToString:@"ITEM"])
        vc = [[ItemViewController alloc] initWithInstance:i delegate:self];
    if([i.object_type isEqualToString:@"DIALOG"])
        vc = [[DialogViewController alloc] initWithInstance:i delegate:self];
    if([i.object_type isEqualToString:@"WEB_PAGE"])
        vc = [[WebPageViewController alloc] initWithInstance:i delegate:self];
    //if([i.object_type isEqualToString:@"NOTE"])
        //vc = [[NoteViewController alloc] initWithInstance:i delegate:self];
    
	ARISNavigationController *nav = [[ARISNavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:NO completion:nil];
    
    //Phil hates that the frame changes depending on what view you add it to...
    gameNotificationViewController.view.frame = CGRectMake(gameNotificationViewController.view.frame.origin.x,
                                                           gameNotificationViewController.view.frame.origin.y+20,
                                                           gameNotificationViewController.view.frame.size.width,
                                                           gameNotificationViewController.view.frame.size.height);
    [nav.view addSubview:gameNotificationViewController.view];//always put notifs on top //Phil doesn't LOVE this, but can't think of anything better...
    
    [_MODEL_LOGS_ playerViewedInstanceId:i.instance_id]; 
    [_MODEL_LOGS_ playerViewedContent:i.object_type id:i.object_id];    
    return YES;   
}

- (void) instantiableViewControllerRequestsDismissal:(InstantiableViewController *)govc
{
    [govc.navigationController dismissViewControllerAnimated:NO completion:nil];
    
    //Phil hates that the frame changes depending on what view you add it to...
    gameNotificationViewController.view.frame = CGRectMake(gameNotificationViewController.view.frame.origin.x,
                                                                gameNotificationViewController.view.frame.origin.y-20,
                                                                gameNotificationViewController.view.frame.size.width,
                                                                gameNotificationViewController.view.frame.size.height);
    [self.view addSubview:gameNotificationViewController.view];//always put notifs on top //Phil doesn't LOVE this, but can't think of anything better...
    
    [displayQueue dequeueTrigger];
}

//PHIL REALLY UNAPPROVED FROM THIS POINT ON

/*
- (void) displayTab:(NSString *)t
{
    NSString *localized = [t lowercaseString];
    ARISNavigationController *tab;
    if([localized isEqualToString:@"map"]       || [localized isEqualToString:[NSLocalizedString(@"MapViewTitleKey",       @"") lowercaseString]])
        tab = mapNavigationController;
    else if([localized isEqualToString:@"quests"]    || [localized isEqualToString:[NSLocalizedString(@"QuestViewTitleKey",     @"") lowercaseString]])
        tab = questsNavigationController;
    else if([localized isEqualToString:@"notebook"]  || [localized isEqualToString:[NSLocalizedString(@"NotebookTitleKey",      @"") lowercaseString]])
        tab = notesNavigationController;
    else if([localized isEqualToString:@"inventory"] || [localized isEqualToString:[NSLocalizedString(@"InventoryViewTitleKey", @"") lowercaseString]])
        tab = inventoryNavigationController;
    else if([localized isEqualToString:@"scanner"]   || [localized isEqualToString:[NSLocalizedString(@"QRScannerTitleKey",     @"") lowercaseString]])
        tab = scannerNavigationController;
    else if([localized isEqualToString:@"decoder"]   || [localized isEqualToString:[NSLocalizedString(@"QRScannerTitleKey",     @"") lowercaseString]])
        tab = decoderNavigationController; 
    else if([localized isEqualToString:@"player"]    || [localized isEqualToString:[NSLocalizedString(@"PlayerTitleKey",        @"") lowercaseString]])
        tab = attributesNavigationController;
    if(tab) [self viewControllerRequestedDisplay:tab]; 
}
 */

- (NSUInteger) supportedInterfaceOrientations
{
    //BAD BAD HACK
    //if ([[notesNavigationController topViewController] isKindOfClass:[AudioVisualizerViewController class]]) {
        //return UIInterfaceOrientationMaskLandscape;
    //}
    //else{
        return UIInterfaceOrientationMaskPortrait;
    //}
}

- (void) dealloc
{
    _ARIS_NOTIF_IGNORE_ALL_(self);            
}

@end
