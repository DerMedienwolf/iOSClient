//
//  QuestDetailsViewController.m
//  ARIS
//
//  Created by Jacob Hanshaw on 10/11/12.
//
//

#import "QuestDetailsViewController.h"
#import "ARISAppDelegate.h"
#import "AppModel.h"
#import "MediaModel.h"
#import "Quest.h"
#import "ARISWebView.h"
#import "ARISMediaView.h"
#import <Google/Analytics.h>


@interface QuestDetailsViewController() <UIScrollViewDelegate, ARISWebViewDelegate, ARISMediaViewDelegate, QuestDetailsViewControllerDelegate>
{
    UIScrollView *scrollView;
    ARISMediaView  *mediaView;
    ARISWebView *webView;
    UIView *goButton;
    UILabel *goLbl;
    UIImageView *arrow;
    UIView *line;

    Quest *quest;
    NSString *mode;
    NSArray *activeQuests;
    NSArray *completeQuests;
    id<QuestDetailsViewControllerDelegate> __unsafe_unretained delegate;
}

@end

@implementation QuestDetailsViewController

- (id) initWithQuest:(Quest *)q mode:(NSString *)m activeQuests:(NSArray *)a completeQuests:(NSArray *)c delegate:(id<QuestDetailsViewControllerDelegate>)d
{
    if(self = [super init])
    {
        quest = q;
        mode = m;
        activeQuests = a;
        completeQuests = c;
        delegate = d;
        self.title = quest.name;
    }
    return self;
}

- (void) loadView
{
    [super loadView];

    self.view.backgroundColor = [ARISTemplate ARISColorContentBackdrop];
    self.navigationItem.title = quest.name;

    scrollView = [[UIScrollView alloc] init];
    scrollView.contentInset = UIEdgeInsetsMake(64, 0, 0, 0);
    scrollView.backgroundColor = [ARISTemplate ARISColorContentBackdrop];
    scrollView.clipsToBounds = NO;

    webView = [[ARISWebView alloc] initWithDelegate:self];
    webView.backgroundColor = [UIColor clearColor];
    webView.scrollView.bounces = NO;
    webView.scrollView.scrollEnabled = NO;
    webView.alpha = 0.0; //The webView will resore alpha once it's loaded to avoid the ugly white blob

    mediaView = [[ARISMediaView alloc] initWithDelegate:self];
    [mediaView setDisplayMode:ARISMediaDisplayModeTopAlignAspectFitWidthAutoResizeHeight];

    goButton = [[UIView alloc] init];
    goButton.backgroundColor = [ARISTemplate ARISColorTextBackdrop];
    goButton.userInteractionEnabled = YES;
    goButton.accessibilityLabel = @"BeginQuest";
    goLbl = [[UILabel alloc] init];
    goLbl.textColor = [ARISTemplate ARISColorText];
    goLbl.textAlignment = NSTextAlignmentRight;
    goLbl.text = NSLocalizedString(@"QuestViewBeginQuestKey", @"");
    goLbl.font = [ARISTemplate ARISButtonFont];
    [goButton addSubview:goLbl];
    [goButton addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(goButtonTouched)]];

    arrow = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"arrowForward"]];
    line = [[UIView alloc] init];
    line.backgroundColor = [UIColor ARISColorLightGray];

    [self.view addSubview:scrollView];

    [self loadQuest];
}

- (void) viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    scrollView.frame = self.view.bounds;

    goButton.frame = CGRectMake(0, self.view.bounds.size.height-44, self.view.bounds.size.width, 44);
    goLbl.frame = CGRectMake(0,0,self.view.bounds.size.width-30,44);
    arrow.frame = CGRectMake(self.view.bounds.size.width-25, self.view.bounds.size.height-30, 19, 19);
    line.frame = CGRectMake(0, self.view.bounds.size.height-44, self.view.bounds.size.width, 1);
}

- (void) loadQuest
{
    CGFloat y = 66.0;
    for (Quest *q in [activeQuests arrayByAddingObjectsFromArray:completeQuests]) {
        if (q.parent_quest_id == quest.quest_id) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.backgroundColor = [UIColor blueColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [button addTarget:self action:@selector(launchSubquest:) forControlEvents:UIControlEventTouchUpInside];
            button.tag = q.quest_id;
            [button setTitle:q.name forState:UIControlStateNormal];
            button.frame = CGRectMake(0.0, y, self.view.bounds.size.width, 40.0);
            y += 40.0;
            [self.view addSubview:button];
        }
    }

    [scrollView addSubview:webView];
    webView.frame = CGRectMake(0, 0, self.view.bounds.size.width, 10);//Needs correct width to calc height
    [webView loadHTMLString:[NSString stringWithFormat:[ARISTemplate ARISHtmlTemplate], ([mode isEqualToString:@"ACTIVE"] ? quest.active_desc : quest.complete_desc)] baseURL:nil];

    Media *media = [_MODEL_MEDIA_ mediaForId:([mode isEqualToString:@"ACTIVE"] ? quest.active_media_id : quest.complete_media_id)];
    if(media)
    {
        [scrollView addSubview:mediaView];
        [mediaView setFrame:CGRectMake(0,0,self.view.bounds.size.width,20)];
        [mediaView setMedia:media];
    }

    if(![([mode isEqualToString:@"ACTIVE"] ? quest.active_function : quest.complete_function) isEqualToString:@"NONE"])
    {
        scrollView.contentInset = UIEdgeInsetsMake(64, 0, 44, 0);
        [self.view addSubview:goButton];
        [self.view addSubview:arrow];
        [self.view addSubview:line];
    }
    else
        scrollView.contentInset = UIEdgeInsetsMake(64, 0, 0, 0);
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.frame = CGRectMake(0, 0, 19, 19);
    [backButton setImage:[UIImage imageNamed:@"arrowBack"] forState:UIControlStateNormal];
    backButton.accessibilityLabel = @"Back Button";
    [backButton addTarget:self action:@selector(backButtonTouched) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:@"Quest Details"];
    [tracker send:[[GAIDictionaryBuilder createScreenView] build]];
}

- (void) ARISMediaViewFrameUpdated:(ARISMediaView *)amv
{
    if(![([mode isEqualToString:@"ACTIVE"] ? quest.active_desc : quest.complete_desc) isEqualToString:@""])
    {
        webView.frame = CGRectMake(0, mediaView.frame.size.height, self.view.bounds.size.width, webView.frame.size.height);
        scrollView.contentSize = CGSizeMake(self.view.bounds.size.width,webView.frame.origin.y+webView.frame.size.height+10);
    }
    else
        scrollView.contentSize = CGSizeMake(self.view.bounds.size.width,mediaView.frame.size.height);
}

- (BOOL) webView:(ARISWebView*)wv shouldStartLoadWithRequest:(NSURLRequest*)r navigationType:(UIWebViewNavigationType)nt
{
    WebPage *w = [_MODEL_WEB_PAGES_ webPageForId:0];
    w.url = [r.URL absoluteString];
    //[delegate displayGameObject:w fromSource:self];

    return NO;
}

- (void) ARISWebViewDidFinishLoad:(ARISWebView *)wv
{
    webView.alpha = 1.00;

    float newHeight = [[webView stringByEvaluatingJavaScriptFromString:@"document.body.offsetHeight;"] floatValue];
    if(_MODEL_GAME_.ipad_two_x && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) //2x
      newHeight *= 2;
    [webView setFrame:CGRectMake(webView.frame.origin.x,
                                      webView.frame.origin.y,
                                      webView.frame.size.width,
                                      newHeight)];
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width,webView.frame.origin.y+webView.frame.size.height+10);
}

- (void) ARISWebViewRequestsDismissal:(ARISWebView *)awv
{
    [delegate questDetailsRequestsDismissal];
}

- (void) backButtonTouched
{
    [delegate questDetailsRequestsDismissal];
}

- (void) dismissQuestDetails
{
  [delegate questDetailsRequestsDismissal];
}

- (void) goButtonTouched
{
    if([([mode isEqualToString:@"ACTIVE"] ? quest.active_function : quest.complete_function) isEqualToString:@"JAVASCRIPT"]) [webView hookWithParams:@""];
    else if([([mode isEqualToString:@"ACTIVE"] ? quest.active_function : quest.complete_function) isEqualToString:@"NONE"]) return;
    else if([([mode isEqualToString:@"ACTIVE"] ? quest.active_function : quest.complete_function) isEqualToString:@"PICKGAME"]) [_MODEL_ leaveGame];
    else [_MODEL_DISPLAY_QUEUE_ enqueueTab:[_MODEL_TABS_ tabForType:([mode isEqualToString:@"ACTIVE"] ? quest.active_function : quest.complete_function)]];
}

- (void) launchSubquest:(UIButton *)button
{
    for (Quest *q in [activeQuests arrayByAddingObjectsFromArray:completeQuests]) {
        if (q.quest_id == button.tag) {
            [[self navigationController] pushViewController:[[QuestDetailsViewController alloc] initWithQuest:q mode:mode activeQuests:nil completeQuests:nil delegate:self] animated:YES];
            return;
        }
    }
}

// this is when a subquest of this (compound) quest requests dismissal
- (void) questDetailsRequestsDismissal
{
    [self.navigationController popToViewController:self animated:YES];
}

- (void) dealloc
{
    webView.delegate = nil;
    [webView stopLoading];
    _ARIS_NOTIF_IGNORE_ALL_(self);
}

@end
