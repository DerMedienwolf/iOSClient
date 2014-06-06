//
//  CameraViewController.m
//  ARIS
//
//  Created by David Gagnon on 3/4/09.
//  Copyright 2009 University of Wisconsin - Madison. All rights reserved.
//

#import "DecoderViewController.h"
#import "StateControllerProtocol.h"
#import "Decoder.h"
#import "ARISAppDelegate.h"
#import "AppModel.h"
#import "AppServices.h"
#import "QRCodeReader.h"
#import "ARISAlertHandler.h"

@interface DecoderViewController() <ZXingDelegate, UITextFieldDelegate>
{
	UITextField *codeTextField;
   	UIButton *scanButton; 
    
    BOOL textEnabled;
    BOOL scanEnabled;
    NSString *prompt;
    
    NSDate *lastError;
    ZXingWidgetController *widController;
    id<DecoderViewControllerDelegate, StateControllerProtocol> __unsafe_unretained delegate;
}
@end

@implementation DecoderViewController

- (id) initWithDelegate:(id<DecoderViewControllerDelegate, StateControllerProtocol>)d inMode:(int)m
{
    if(self = [super initWithDelegate:d])
    {
        self.tabID = @"QR";
        self.tabIconName = @"qr_icon.png";
        
        textEnabled = (m == 0 || m == 1);
        scanEnabled = (m == 0 || m == 2);
        lastError = [NSDate date];
        prompt = @""; 
        
        delegate = d;
        
        self.title = NSLocalizedString(@"QRScannerTitleKey", @"");
    _ARIS_NOTIF_LISTEN_(@"QRCodeObjectReady",self,@selector(finishLoadingResult:),nil);
    }
    return self;
}

- (void) loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor ARISColorBlack];  
    
    if(textEnabled)
    {
        self.view.backgroundColor = [UIColor ARISColorWhite]; 
        codeTextField = [[UITextField alloc] initWithFrame:CGRectMake(20,20+64,self.view.frame.size.width-40,30)];
        codeTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        codeTextField.spellCheckingType = UITextSpellCheckingTypeNo;
        codeTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        codeTextField.textAlignment = NSTextAlignmentCenter;
        codeTextField.placeholder = NSLocalizedString(@"EnterCodeKey",@"");
        codeTextField.delegate = self;
        [self.view addSubview:codeTextField];
    }
    
    if(scanEnabled)
    {
        scanButton = [UIButton buttonWithType:UIButtonTypeCustom];
        scanButton.frame = CGRectMake(20,70+64,self.view.frame.size.width-40,30);
        scanButton.backgroundColor = [UIColor ARISColorDarkGray];
        [scanButton setTitle:NSLocalizedString(@"ScanKey", @"") forState:UIControlStateNormal];
        [scanButton addTarget:self action:@selector(scanButtonTouched) forControlEvents:UIControlEventTouchUpInside];
        if(textEnabled) [self.view addSubview:scanButton]; //else, don't bother adding it to view as it should always be open
    }
}

- (void) viewWillAppearFirstTime:(BOOL)animated
{
    [super viewWillAppearFirstTime:animated];
    
    //overwrite the nav button written by superview so we can listen for touchDOWN events as well (to dismiss camera)
    UIButton *threeLineNavButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 27, 27)];
    [threeLineNavButton setImage:[UIImage imageNamed:@"threelines"] forState:UIControlStateNormal];
    [threeLineNavButton addTarget:self action:@selector(showNav) forControlEvents:UIControlEventTouchUpInside];
    threeLineNavButton.accessibilityLabel = @"In-Game Menu";
    if(textEnabled)
        [threeLineNavButton addTarget:self action:@selector(clearScreenActions) forControlEvents:UIControlEventTouchDown];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:threeLineNavButton];  
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if(!widController && (!textEnabled || ![prompt isEqualToString:@""])) [self launchScanner];
    if(!scanEnabled) [codeTextField becomeFirstResponder];
}

- (void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self clearScreenActions];
}

- (void) showNav
{
    if(textEnabled) [self clearScreenActions];
    [super showNav];
}

- (void) clearScreenActions
{
    if(codeTextField) [codeTextField resignFirstResponder];
    if(widController) [self hideWidController];
}

- (BOOL) textFieldShouldReturn:(UITextField*)textField
{	
	[textField resignFirstResponder]; 
	
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate date]]; //Let the keyboard go away before loading the object
	
	[self loadResult:codeTextField.text];
	return YES;
}

- (BOOL) textFieldShouldBeginEditing:(UITextField *)textField
{    
    return YES;
}

-  (void) setPrompt:(NSString *)p
{
    prompt = p;
    if(self.view) [self launchScanner]; //hack to ensure view is loaded
}

- (void) launchScanner
{
    [self clearScreenActions];
    widController = [[ZXingWidgetController alloc] initWithDelegate:self oneDMode:NO showLicense:NO withPrompt:prompt];
    widController.readers = [[NSMutableSet  alloc] initWithObjects:[[QRCodeReader alloc] init], nil];
    prompt = @"";
    [self performSelector:@selector(addWidSubview) withObject:Nil afterDelay:0.1];
}

- (void) addWidSubview
{
    [self.view addSubview:widController.view];
}

- (void) scanButtonTouched
{
    [self launchScanner];
}

- (void) zxingController:(ZXingWidgetController*)controller didScanResult:(NSString *)result
{
    [self hideWidController];
    [self loadResult:result];
}

- (void) zxingControllerDidCancel:(ZXingWidgetController*)controller
{
    [self hideWidController];
}

- (void) hideWidController
{
    [widController.view removeFromSuperview];
    widController = nil;
}

- (void) loadResult:(NSString *)code
{
    if([code isEqualToString:@"log-out"])
    {
        [_MODEL_ logOut];
        return;
    }
    
    [[ARISAlertHandler sharedAlertHandler] showWaitingIndicator:NSLocalizedString(@"LoadingKey",@"")];
	[[AppServices sharedAppServices] fetchQRCode:code];
}

- (void) finishLoadingResult:(NSNotification*) notification
{	
	NSObject *qrCodeObject = notification.object;
	ARISAppDelegate* appDelegate = (ARISAppDelegate *)[[UIApplication sharedApplication] delegate];
    [[ARISAlertHandler sharedAlertHandler] removeWaitingIndicator];
    
	if(!qrCodeObject)
    {
        if([lastError timeIntervalSinceNow] < -3.0f)
        { 
            lastError = [NSDate date];
            [appDelegate playAudioAlert:@"error" shouldVibrate:NO];
            [[ARISAlertHandler sharedAlertHandler] showAlertWithTitle:NSLocalizedString(@"QRScannerErrorTitleKey", @"") message:NSLocalizedString(@"QRScannerErrorMessageKey", @"")];
        }
        if(!textEnabled) [self performSelector:@selector(scanButtonTouched) withObject:nil afterDelay:1]; 
	}
	else if([qrCodeObject isKindOfClass:[NSString class]])
    {
        if([lastError timeIntervalSinceNow] < -3.0f)
        {
            lastError = [NSDate date]; 
            [appDelegate playAudioAlert:@"error" shouldVibrate:NO];
            [[ARISAlertHandler sharedAlertHandler] showAlertWithTitle:NSLocalizedString(@"QRScannerErrorTitleKey", @"") message:(NSString *)qrCodeObject];
        }
        if(!textEnabled) [self performSelector:@selector(scanButtonTouched) withObject:nil afterDelay:1];  
    }
    else
    {
		[appDelegate playAudioAlert:@"swish" shouldVibrate:NO];
		//[delegate displayGameObject:(((Location *)qrCodeObject).gameObject) fromSource:(Location *)qrCodeObject];
	}
}

- (void) dealloc
{
    _ARIS_NOTIF_IGNORE_ALL_(self); 
}

@end
