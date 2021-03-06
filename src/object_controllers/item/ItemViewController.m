//
//  ItemViewController.m
//  ARIS
//
//  Created by Phil Dougherty on 10/17/13.
//
//

#import "ItemViewController.h"
#import "ARISAlertHandler.h"

#import "ItemActionViewController.h"
#import "InventoryViewController.h"

#import "Item.h"
#import "Instance.h"
#import "ARISWebView.h"
#import "ARISMediaView.h"
#import "ARISCollapseView.h"
#import "AppModel.h"
#import "Game.h"
#import "ItemsModel.h"
#import "MediaModel.h"
#import <Google/Analytics.h>


@interface ItemViewController()  <ARISMediaViewDelegate, ARISWebViewDelegate, ARISCollapseViewDelegate, ItemActionViewControllerDelegate, UITextViewDelegate>
{
    Item *item;
    Instance *instance;
    Tab *tab;

    //Labels as buttons (easier formatting)
    UILabel *dropBtn;
    UILabel *destroyBtn;
    UILabel *pickupBtn;
    UIView *line; //separator between buttons/etc...
    long lastbuttontouched; //dumb

    ARISWebView *webView;
    ARISCollapseView *collapseView;
    ARISWebView *descriptionView;
    UIScrollView *scrollView;
    ARISMediaView *imageView;

    UIActivityIndicatorView *activityIndicator;

    id<ItemViewControllerDelegate> __unsafe_unretained delegate;
}
@end

@implementation ItemViewController

- (id) initWithInstance:(Instance *)i delegate:(id<ItemViewControllerDelegate>)d
{
    if(self = [super init])
    {
        delegate = d;
        instance = i;
        item = [_MODEL_ITEMS_ itemForId:i.object_id];
        lastbuttontouched = 0;
    }
    return self;
}
- (Instance *) instance { return instance; }

- (id) initWithTab:(Tab *)t delegate:(id<ItemViewControllerDelegate>)d
{
    if(self = [super init])
    {
        delegate = d;
        tab = t;
        instance = [_MODEL_INSTANCES_ instanceForId:0]; //get null inst
        instance.object_type = tab.type;
        instance.object_id = tab.content_id;
        item = [_MODEL_ITEMS_ itemForId:instance.object_id];
    }
    return self;
}
- (Tab *) tab { return tab; }

//Helper to cleanly/consistently create bottom buttons
- (UILabel *) createItemButtonWithText:(NSString *)t selector:(SEL)s
{
    UILabel *btn = [[UILabel alloc] init];
    btn.userInteractionEnabled = YES;
    btn.textAlignment = NSTextAlignmentCenter;
    btn.text = t;
    btn.font = [ARISTemplate ARISButtonFont];
    btn.backgroundColor = [ARISTemplate ARISColorTextBackdrop];
    btn.textColor       = [ARISTemplate ARISColorText];
    [btn addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:s]];
    [btn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(passPanToDescription:)]];

    return btn;
}

- (void) loadView
{
    [super loadView];
    self.view.backgroundColor = [ARISTemplate ARISColorContentBackdrop];

    long numButtons = 0;
    if(instance.owner_id == _MODEL_PLAYER_.user_id && item.destroyable)       { destroyBtn = [self createItemButtonWithText:NSLocalizedString(@"ItemDeleteKey", @"") selector:@selector(destroyButtonTouched)]; numButtons++; }
    if(instance.owner_id == _MODEL_PLAYER_.user_id && item.droppable)         { dropBtn    = [self createItemButtonWithText:NSLocalizedString(@"ItemDropKey", @"")   selector:@selector(dropButtonTouched)];    numButtons++; }
    if(instance.owner_id == 0 && (instance.qty > 0 || instance.infinite_qty)) { pickupBtn  = [self createItemButtonWithText:NSLocalizedString(@"ItemPickupKey", @"") selector:@selector(pickupButtonTouched)];  numButtons++; }

    line = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height-44, self.view.bounds.size.width, 1)];
    line.backgroundColor = [UIColor ARISColorLightGray];

    //Web Item
    if([item.type isEqualToString:@"URL"] &&
       item.url                                &&
       ![item.url isEqualToString:@"0"]        &&
       ![item.url isEqualToString:@""]         )
    {
        webView = [[ARISWebView alloc] initWithFrame:CGRectMake(0,0,self.view.frame.size.width,self.view.frame.size.height) delegate:self];
        if(numButtons > 0) webView.scrollView.contentInset = UIEdgeInsetsMake(64,0,54,0);
        else               webView.scrollView.contentInset = UIEdgeInsetsMake(64,0,10,0);

        webView.hidden                          = YES;
        webView.scalesPageToFit                 = YES;
        webView.allowsInlineMediaPlayback       = YES;
        webView.mediaPlaybackRequiresUserAction = NO;

        [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:item.url]] withAppendation:[NSString stringWithFormat:@"&item_id=%ld",item.item_id]];
    }
    //Normal Item
    else
    {
        scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        if(numButtons > 0) scrollView.contentInset = UIEdgeInsetsMake(64,0,54,0);
        else               scrollView.contentInset = UIEdgeInsetsMake(64,0,10,0);
        scrollView.clipsToBounds    = NO;
        scrollView.maximumZoomScale = 20;
        scrollView.minimumZoomScale = 1;
        scrollView.delegate = self;

        Media *media;
        if(item.media_id) media = [_MODEL_MEDIA_ mediaForId:item.media_id];
        else                  media = [_MODEL_MEDIA_ mediaForId:item.icon_media_id];

        if(media)
        {
            imageView = [[ARISMediaView alloc] initWithFrame:CGRectMake(0,0,scrollView.frame.size.width,scrollView.frame.size.height-64) delegate:self];
            [imageView setMedia:media];
            [imageView setDisplayMode:ARISMediaDisplayModeAspectFit];
            [scrollView addSubview:imageView];
            [scrollView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(passTapToDescription:)]];
        }
    }

    if(![item.desc isEqualToString:@""])
    {
        descriptionView = [[ARISWebView alloc] initWithFrame:CGRectMake(0,0,self.view.frame.size.width,10) delegate:self];
        descriptionView.userInteractionEnabled   = NO;
        descriptionView.scrollView.scrollEnabled = NO;
        descriptionView.scrollView.bounces       = NO;
        descriptionView.opaque                   = NO;
        descriptionView.backgroundColor = [UIColor clearColor];
        [descriptionView loadHTMLString:[NSString stringWithFormat:[ARISTemplate ARISHtmlTemplate], item.desc] baseURL:nil];
        collapseView = [[ARISCollapseView alloc] initWithContentView:descriptionView frame:CGRectMake(0,self.view.bounds.size.height-(10+((numButtons > 0)*44)),self.view.frame.size.width,10) open:YES showHandle:YES draggable:YES tappable:YES delegate:self];
    }

    //nil subviews should be ignored
    [self.view addSubview:webView];
    [self.view addSubview:scrollView];
    [self.view addSubview:collapseView];
    [self updateViewButtons];
    [self.view addSubview:line];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:@"Item"];
    [tracker send:[[GAIDictionaryBuilder createScreenView] build]];

    [self updateViewButtons];
    [self refreshTitle];

    if(tab)
    {
        UIButton *threeLineNavButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 27, 27)];
        [threeLineNavButton setImage:[UIImage imageNamed:@"threelines"] forState:UIControlStateNormal];
        [threeLineNavButton addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
        threeLineNavButton.accessibilityLabel = @"In-Game Menu";
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:threeLineNavButton];
        // newly required in iOS 11: https://stackoverflow.com/a/44456952
        if ([threeLineNavButton respondsToSelector:@selector(widthAnchor)] && [threeLineNavButton respondsToSelector:@selector(heightAnchor)]) {
            [[threeLineNavButton.widthAnchor constraintEqualToConstant:27.0] setActive:true];
            [[threeLineNavButton.heightAnchor constraintEqualToConstant:27.0] setActive:true];
        }
    }
    else
    {
        UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
        backButton.frame = CGRectMake(0, 0, 19, 19);
        [backButton setImage:[UIImage imageNamed:@"arrowBack"] forState:UIControlStateNormal];
        [backButton addTarget:self action:@selector(backButtonTouched) forControlEvents:UIControlEventTouchUpInside];
        backButton.accessibilityLabel = @"Back Button";
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    }
}

- (void) refreshTitle
{
    if(instance.qty < 2 || instance.infinite_qty) self.title = self.tabTitle;
    else self.title = [NSString stringWithFormat:@"%@ x%ld",self.tabTitle,instance.qty];
}

- (void) updateViewButtons
{
    if(destroyBtn) [destroyBtn removeFromSuperview];
    if(dropBtn)    [dropBtn    removeFromSuperview];
    if(pickupBtn)  [pickupBtn  removeFromSuperview];
    if(line)       [line       removeFromSuperview];

    if(instance.qty < 1 && !instance.infinite_qty)
    {
        destroyBtn = nil;
        dropBtn    = nil;
        pickupBtn  = nil;
    }
  
    if(lastbuttontouched == 2) //just picked up an item
      pickupBtn = nil;

    long numButtons = (destroyBtn != nil) + (dropBtn != nil) + (pickupBtn != nil);
    long numPlacedButtons = 0;
    if(destroyBtn) { destroyBtn.frame = CGRectMake(numPlacedButtons*(self.view.bounds.size.width/numButtons),self.view.bounds.size.height-44,self.view.bounds.size.width/numButtons,44); numPlacedButtons++; }
    if(dropBtn)    { dropBtn.frame    = CGRectMake(numPlacedButtons*(self.view.bounds.size.width/numButtons),self.view.bounds.size.height-44,self.view.bounds.size.width/numButtons,44); numPlacedButtons++; }
    if(pickupBtn)  { pickupBtn.frame  = CGRectMake(numPlacedButtons*(self.view.bounds.size.width/numButtons),self.view.bounds.size.height-44,self.view.bounds.size.width/numButtons,44); numPlacedButtons++; }

    [self.view addSubview:destroyBtn];
    [self.view addSubview:dropBtn];
    [self.view addSubview:pickupBtn];
    if(numButtons > 0)[self.view addSubview:line];

    if(collapseView) [collapseView setFrame:CGRectMake(0,self.view.bounds.size.height-((descriptionView.frame.size.height+10)+((numButtons > 0) ? 44 : 0)),self.view.frame.size.width,descriptionView.frame.size.height+10)];
}

- (void) passTapToDescription:(UITapGestureRecognizer *)r
{
    [collapseView handleTapped:r];
}

- (void) passPanToDescription:(UIPanGestureRecognizer *)g
{
    [collapseView handlePanned:g];
}

- (void) dropButtonTouched
{
    lastbuttontouched = 0;
    long amtCanDrop = [_MODEL_PLAYER_INSTANCES_ qtyOwnedForItem:item.item_id];

    if(amtCanDrop > 1)
    {
        ItemActionViewController *itemActionVC = [[ItemActionViewController alloc] initWithPrompt:NSLocalizedString(@"ItemDropKey", @"") maxqty:instance.qty delegate:self];

        [[self navigationController] pushViewController:itemActionVC animated:YES];
    }
    else if(amtCanDrop > 0)
        [self dropItemQty:1];
}

- (void) dropItemQty:(long)q
{
    if([_MODEL_PLAYER_INSTANCES_ dropItemFromPlayer:item.item_id qtyToRemove:q] == 0)
    {
        [self dismissSelf];
    }
    else
    {
        [self updateViewButtons];
        [self refreshTitle];
    }
}

- (void) destroyButtonTouched
{
    lastbuttontouched = 1;
    long amtCanDestroy = [_MODEL_PLAYER_INSTANCES_ qtyOwnedForItem:item.item_id];

    if(amtCanDestroy > 1)
    {
        ItemActionViewController *itemActionVC = [[ItemActionViewController alloc] initWithPrompt:NSLocalizedString(@"ItemDeleteKey", @"") maxqty:instance.qty delegate:self];

        [[self navigationController] pushViewController:itemActionVC animated:YES];
    }
    else if(amtCanDestroy > 0)
        [self destroyItemQty:1];
}

- (void) destroyItemQty:(long)q
{
    if([_MODEL_PLAYER_INSTANCES_ takeItemFromPlayer:item.item_id qtyToRemove:q] == 0) [self dismissSelf];
    else
    {
        [self updateViewButtons];
        [self refreshTitle];
    }
}

- (void) pickupButtonTouched
{
    lastbuttontouched = 2;
    long amtMoreCanHold = [_MODEL_PLAYER_INSTANCES_ qtyAllowedToGiveForItem:item.item_id];
    long allowablePickupAmt = instance.infinite_qty ? 99999999 : instance.qty;
    if(amtMoreCanHold < allowablePickupAmt) allowablePickupAmt = amtMoreCanHold;

    if(allowablePickupAmt == 0)
    {
      [[ARISAlertHandler sharedAlertHandler] showAlertWithTitle:@"Unable to Pick Up" message:@"Max qty already owned."];
        return;
    }
    else if(allowablePickupAmt > 1 && !instance.infinite_qty)
    {
        ItemActionViewController *itemActionVC = [[ItemActionViewController alloc] initWithPrompt:NSLocalizedString(@"ItemPickupKey", @"") maxqty:allowablePickupAmt delegate:self];
        [[self navigationController] pushViewController:itemActionVC animated:YES];
    }
    else [self pickupItemQty:1];
}

- (void) pickupItemQty:(long)q
{
    [_MODEL_PLAYER_INSTANCES_ giveItemToPlayer:item.item_id qtyToAdd:q];
    long nq = instance.qty - q;
    [_MODEL_INSTANCES_ setQtyForInstanceId:instance.instance_id qty:nq];
    instance.qty = nq; //should get set in above call- but if bogus instance, can't hurt to force it
    [self updateViewButtons];
    [self refreshTitle];
}

- (void) amtChosen:(long)amt
{
    [[self navigationController] popToViewController:self animated:YES];
         if(lastbuttontouched == 0) [self dropItemQty:amt];
    else if(lastbuttontouched == 1) [self destroyItemQty:amt];
    else if(lastbuttontouched == 2) [self pickupItemQty:amt];
}

- (void) movieFinishedCallback:(NSNotification*) aNotification
{
    //[self dismissMoviePlayerViewControllerAnimated];
}

- (UIView *) viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return imageView;
}

- (void) ARISWebViewRequestsDismissal:(ARISWebView *)awv
{
    [delegate instantiableViewControllerRequestsDismissal:self];
}

- (void) ARISWebViewRequestsRefresh:(ARISWebView *)awv
{
    //ignore
}

- (BOOL) ARISWebView:(ARISWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)r navigationType:(UIWebViewNavigationType)nt
{
    if(wv == webView) return YES;

    WebPage *nullWebPage = [_MODEL_WEB_PAGES_ webPageForId:0];
    nullWebPage.url = [r.URL absoluteString];
    //[delegate displayObjectType:@"WEB_PAGE" id:0];

    return NO;
}

- (void) ARISWebViewDidFinishLoad:(ARISWebView *)wv
{
    if(wv == webView)
    {
        webView.hidden = NO;
        [self dismissWaitingIndicator];
    }
    if(wv == descriptionView)
    {
        float newHeight = [[descriptionView stringByEvaluatingJavaScriptFromString:@"document.body.offsetHeight;"] floatValue];
        if(_MODEL_GAME_.ipad_two_x && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) //2x
          newHeight *= 2;
        if (newHeight > (self.view.bounds.size.height - 64) * (2.0f/3.0f)) {
            descriptionView.userInteractionEnabled = YES;
            descriptionView.scrollView.scrollEnabled = YES;
            newHeight = (self.view.bounds.size.height - 64) * (2.0f/3.0f);
        }
        [collapseView setContentFrameHeight:newHeight];

        if(newHeight+10 < self.view.bounds.size.height-44-64)
            [collapseView setFrameHeight:newHeight+10];
        else
            [collapseView setFrameHeight:self.view.bounds.size.height-44-64];

        [collapseView open];
    }
}

- (void) ARISWebViewDidStartLoad:(ARISWebView *)wv
{
    if(wv == webView) [self showWaitingIndicator];
}

- (void) showWaitingIndicator
{
    if(!activityIndicator)
        activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:scrollView.bounds];
    [activityIndicator startAnimating];
    [scrollView addSubview:activityIndicator];
}

- (void) dismissWaitingIndicator
{
    [activityIndicator stopAnimating];
    [activityIndicator removeFromSuperview];
}

- (void) backButtonTouched
{
    [self dismissSelf];
}

- (void) dismissSelf
{
    [delegate instantiableViewControllerRequestsDismissal:self];
    if(tab) [self showNav];
}

- (void) showNav
{
    [delegate gamePlayTabBarViewControllerRequestsNav];
}

//implement gameplaytabbarviewcontrollerprotocol junk
- (NSString *) tabId { return @"ITEM"; }
- (NSString *) tabTitle { if(tab.name && ![tab.name isEqualToString:@""]) return tab.name; if(item.name && ![item.name isEqualToString:@""]) return item.name; return @"Item"; }
- (ARISMediaView *) tabIcon
{
    ARISMediaView *amv = [[ARISMediaView alloc] init];
    if(tab.icon_media_id)
        [amv setMedia:[_MODEL_MEDIA_ mediaForId:tab.icon_media_id]];
    else if(item.icon_media_id)
        [amv setMedia:[_MODEL_MEDIA_ mediaForId:item.icon_media_id]];
    else
        [amv setImage:[UIImage imageNamed:@"logo_icon"]];
    return amv;
}

- (void) dealloc
{
    _ARIS_NOTIF_IGNORE_ALL_(self);
}

@end
