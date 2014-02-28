//
//  NodeViewController.m
//  ARIS
//
//  Created by Kevin Harris on 5/11/09.
//  Copyright 2009 University of Wisconsin - Madison. All rights reserved.
//

#import "NodeViewController.h"
#import "StateControllerProtocol.h"
#import "AppModel.h"
#import "AppServices.h"
#import "ARISAppDelegate.h"
#import "Media.h"
#import "ARISMediaView.h"
#import "ARISWebView.h"
#import "WebPageViewController.h"
#import "WebPage.h"
#import "UIImage+Scale.h"
#import "Node.h"
#import "ARISTemplate.h"

#import <MediaPlayer/MediaPlayer.h>

static NSString * const OPTION_CELL = @"option";

@interface NodeViewController() <UIScrollViewDelegate, ARISWebViewDelegate, ARISMediaViewDelegate, StateControllerProtocol>
{
    UIScrollView *scrollView;
    ARISMediaView  *mediaView;
    ARISWebView *webView;
    UIView *continueButton;
    UILabel *continueLbl; 
    UIImageView *arrow;
    UIView *line;
    id <GameObjectViewControllerDelegate, StateControllerProtocol> __unsafe_unretained delegate;
}

@end

@implementation NodeViewController

- (id) initWithNode:(Node *)n delegate:(id<GameObjectViewControllerDelegate, StateControllerProtocol>)d
{
    if((self = [super init]))
    {
        delegate = d;
    
        node = n;
        self.title = node.name;
    }
    
    return self;
}

- (void) loadView
{
    [super loadView];
    
    self.view.backgroundColor = [ARISTemplate ARISColorContentBackdrop];
    
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
    
    continueButton = [[UIView alloc] init];
    continueButton.backgroundColor = [ARISTemplate ARISColorTextBackdrop];
    continueButton.userInteractionEnabled = YES;
    continueButton.accessibilityLabel = @"Continue";
    continueLbl = [[UILabel alloc] init];
    continueLbl.textColor = [ARISTemplate ARISColorText];
    continueLbl.textAlignment = NSTextAlignmentRight;
    continueLbl.text = NSLocalizedString(@"ContinueKey", @"");
    continueLbl.font = [ARISTemplate ARISButtonFont];
    [continueButton addSubview:continueLbl];
    [continueButton addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(continueButtonTouched)]];
    
    arrow = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"arrowForward"]];
    line = [[UIView alloc] init];
    line.backgroundColor = [UIColor ARISColorLightGray];
    
    [self.view addSubview:scrollView];
    [self.view addSubview:continueButton];
    [self.view addSubview:arrow];
    [self.view addSubview:line];
    
    [self loadNode];
}

- (void) viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    scrollView.frame = self.view.bounds;
    scrollView.contentInset = UIEdgeInsetsMake(64, 0, 44, 0);
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width,self.view.bounds.size.height-64-44);  
    
    webView.frame = CGRectMake(0, 0, self.view.bounds.size.width, 1);
    
    continueButton.frame = CGRectMake(0, self.view.bounds.size.height-44, self.view.bounds.size.width, 44);
    continueLbl.frame = CGRectMake(0,0,self.view.bounds.size.width-30,44);
    arrow.frame = CGRectMake(self.view.bounds.size.width-25, self.view.bounds.size.height-30, 19, 19); 
    line.frame = CGRectMake(0, self.view.bounds.size.height-44, self.view.bounds.size.width, 1);
}

- (void) loadNode
{
    if(![node.text isEqualToString:@""])
    {
        [scrollView addSubview:webView]; 
        webView.frame = CGRectMake(0, 0, self.view.bounds.size.width, 10);//Needs correct width to calc height
        [webView loadHTMLString:[NSString stringWithFormat:[ARISTemplate ARISHtmlTemplate], node.text] baseURL:nil]; 
    }
    
    Media *media = [[AppModel sharedAppModel] mediaForMediaId:node.mediaId];  
    if(media)
    {
        [scrollView addSubview:mediaView];   
        [mediaView setFrame:CGRectMake(0,0,self.view.bounds.size.width,20) withMode:ARISMediaDisplayModeTopAlignAspectFitWidthAutoResizeHeight]; //Nees correct width to calc height
        [mediaView setMedia:media];
    } 
}

- (void) ARISMediaViewUpdated:(ARISMediaView *)amv
{
    if(![node.text isEqualToString:@""])
    {
        webView.frame = CGRectMake(0, mediaView.frame.size.height, self.view.bounds.size.width, webView.frame.size.height);
        scrollView.contentSize = CGSizeMake(self.view.bounds.size.width,webView.frame.origin.y+webView.frame.size.height+10);
    }
    else
        scrollView.contentSize = CGSizeMake(self.view.bounds.size.width,mediaView.frame.size.height);
}

- (BOOL) ARISMediaViewShouldPlayButtonTouched:(ARISMediaView *)amv
{
    Media *media = [[AppModel sharedAppModel] mediaForMediaId:node.mediaId];   
    MPMoviePlayerViewController *movieViewController = [[MPMoviePlayerViewController alloc] initWithContentURL:media.localURL];
    //error message that is logged after this line is possibly an ios 7 simulator bug...
    [self presentMoviePlayerViewControllerAnimated:movieViewController];
    return NO;
}

- (BOOL) webView:(ARISWebView*)wv shouldStartLoadWithRequest:(NSURLRequest*)r navigationType:(UIWebViewNavigationType)nt
{
    [delegate gameObjectViewControllerRequestsDismissal:self];
    WebPage *w = [[WebPage alloc] init];
    w.webPageId = node.nodeId;
    w.url = [r.URL absoluteString];
    [(id<StateControllerProtocol>)delegate displayGameObject:w fromSource:self];

    return NO;
}

- (void) ARISWebViewDidFinishLoad:(ARISWebView *)wv
{
    webView.alpha = 1.00;
    
    //Calculate the height of the web content
    float newHeight = [[webView stringByEvaluatingJavaScriptFromString:@"document.body.offsetHeight;"] floatValue];
    [webView setFrame:CGRectMake(webView.frame.origin.x,
                                      webView.frame.origin.y,
                                      webView.frame.size.width,
                                      newHeight)];
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width,webView.frame.origin.y+webView.frame.size.height+10);
}

- (void) displayTab:(NSString *)t
{
    [delegate displayTab:t];
}

- (void) displayScannerWithPrompt:(NSString *)p
{
    [delegate displayScannerWithPrompt:p]; 
}

- (BOOL) displayGameObject:(id<GameObjectProtocol>)g fromSource:(id)s
{
    return [delegate displayGameObject:g fromSource:s];  
}

- (void) continueButtonTouched
{
	[[AppServices sharedAppServices] updateServerNodeViewed:node.nodeId fromLocation:0];
    [delegate gameObjectViewControllerRequestsDismissal:self];
}

- (void)dealloc
{
    webView.delegate = nil;
    [webView stopLoading];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
