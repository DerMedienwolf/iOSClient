//
//  AugmentedViewController.mm
//  ARIS
//
//  Created by Michael Tolly on 11/23/16.
//
//

#if !TARGET_OS_SIMULATOR

#import "AugmentedViewController.h"
#import "ARISAppDelegate.h"
#import "AppModel.h"
#import "ARISAlertHandler.h"
#import <Google/Analytics.h>

#import <Vuforia/Vuforia.h>
#import <Vuforia/TrackerManager.h>
#import <Vuforia/ObjectTracker.h>
#import <Vuforia/Trackable.h>
#import <Vuforia/DataSet.h>
#import <Vuforia/CameraDevice.h>

@interface AugmentedViewController() <AVCaptureMetadataOutputObjectsDelegate, UITextFieldDelegate>
{
    Tab *tab;
    UIBarButtonItem *leftNavButton;
    NSString *prompt;
    NSString *caption;
    ARISMediaView *overlay;
    Media *overlayMedia;
    UILabel *promptLabel;
    UILabel *captionLabel;
    UIButton *continueButton;
    NSDate *lastQRTrigger;
    BOOL unrecognizedQRPopup;
    id<AugmentedViewControllerDelegate> __unsafe_unretained delegate;
}

@property (weak, nonatomic) IBOutlet UIImageView *ARViewPlaceholder;

@end

@implementation AugmentedViewController

@synthesize tapGestureRecognizer, vapp, eaglView;

- (id) initWithTab:(Tab *)t delegate:(id<AugmentedViewControllerDelegate>)d
{
    if(self = [super init])
    {
        tab = t;
        self.title = self.tabTitle;
        overlayMedia = nil;
        
        lastQRTrigger = [NSDate date];
        unrecognizedQRPopup = NO;
        
        delegate = d;
        
        prompt = nil;
    }
    return self;
}

-  (void) setCaption:(NSString *)cap
{
    if (caption && [cap isEqualToString:caption]) return;
    caption = cap;
    captionLabel.text = caption;
    captionLabel.hidden = [caption isEqualToString:@""];
}

-  (void) setPrompt:(NSString *)pmt
{
    prompt = pmt;
    if (prompt) {
        promptLabel.text = prompt;
        promptLabel.hidden = [prompt isEqualToString:@""];
    } else {
        promptLabel.text = @"";
        promptLabel.hidden = YES;
    }
}

- (void) setOverlay:(Media *)media
{
    overlayMedia = media;
    if (media) {
        [overlay setHidden:NO];
        [overlay setMedia:overlayMedia];
    } else {
        [overlay setHidden:YES];
    }
}

- (void) loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor ARISColorBlack];
    
    UIButton *threeLineNavButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 27, 27)];
    [threeLineNavButton setImage:[UIImage imageNamed:@"threelines"] forState:UIControlStateNormal];
    [threeLineNavButton addTarget:self action:@selector(showNav) forControlEvents:UIControlEventTouchUpInside];
    threeLineNavButton.accessibilityLabel = @"In-Game Menu";
    leftNavButton = [[UIBarButtonItem alloc] initWithCustomView:threeLineNavButton];
    // newly required in iOS 11: https://stackoverflow.com/a/44456952
    if ([threeLineNavButton respondsToSelector:@selector(widthAnchor)] && [threeLineNavButton respondsToSelector:@selector(heightAnchor)]) {
        [[threeLineNavButton.widthAnchor constraintEqualToConstant:27.0] setActive:true];
        [[threeLineNavButton.heightAnchor constraintEqualToConstant:27.0] setActive:true];
    }

    // following is from ImageTargetsViewController
    
    if (self.ARViewPlaceholder != nil) {
        [self.ARViewPlaceholder removeFromSuperview];
        self.ARViewPlaceholder = nil;
    }
    
    continuousAutofocusEnabled = YES;
    
    vapp = [[SampleApplicationSession alloc] initWithDelegate:self];
    
    CGRect viewFrame = [self getCurrentARViewFrame];
    
    eaglView = [[AugmentedEAGLView alloc] initWithFrame:viewFrame appSession:vapp];
    [self setView:eaglView];
    ARISAppDelegate *appDelegate = _DELEGATE_;
    appDelegate.glResourceHandler = eaglView;
    
    // a single tap will run a trigger if a target is being recognized
    tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selectTrigger:)];
    [self.view addGestureRecognizer:tapGestureRecognizer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dismissARViewController)
                                                 name:@"kDismissARViewController"
                                               object:nil];
    
    // we use the iOS notification to pause/resume the AR when the application goes (or come back from) background
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(pauseAR)
     name:UIApplicationWillResignActiveNotification
     object:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(resumeAR)
     name:UIApplicationDidBecomeActiveNotification
     object:nil];
    
    // initialize AR
    [vapp initAR:Vuforia::GL_20 orientation:self.interfaceOrientation];

    // show loading animation while AR is being initialized
    [self showLoadingAnimation];
    
    CGFloat scale = [UIScreen mainScreen].scale;
    
    overlay = [[ARISMediaView alloc] init];
    overlay.frame = CGRectMake(0, 64, self.view.bounds.size.width / scale, self.view.bounds.size.height / scale - 64);
    overlay.displayMode = ARISMediaDisplayModeAspectFill;
    [self setOverlay:overlayMedia];
    [self.view addSubview:overlay];
    
    // caption text box
    captionLabel = [[UILabel alloc] init];
    captionLabel.frame = CGRectMake(0, (self.view.bounds.size.height-155) / scale, self.view.bounds.size.width / scale, 75 / scale);
    captionLabel.numberOfLines = 0;
    captionLabel.lineBreakMode = NSLineBreakByWordWrapping;
    captionLabel.textAlignment = NSTextAlignmentCenter;
    captionLabel.textColor       = [UIColor ARISColorLightGray];
    captionLabel.backgroundColor = [UIColor ARISColorTranslucentBlack];
    [self setCaption:@""];
    [self.view addSubview:captionLabel];
    
    // prompt text box
    promptLabel = [[UILabel alloc] init];
    promptLabel.frame = CGRectMake(0, 150 / scale, self.view.bounds.size.width / scale, 75 / scale);
    promptLabel.numberOfLines = 0;
    promptLabel.lineBreakMode = NSLineBreakByWordWrapping;
    promptLabel.textAlignment = NSTextAlignmentCenter;
    promptLabel.textColor       = [UIColor ARISColorLightGray];
    promptLabel.backgroundColor = [UIColor ARISColorTranslucentBlack];
    [self setPrompt:prompt];
    [self.view addSubview:promptLabel];
    
    continueButton = [[UIButton alloc] init];
    continueButton.frame = CGRectMake(0 / scale, (self.view.bounds.size.height-80) / scale,self.view.bounds.size.width / scale,80 / scale);
    [continueButton setTitle:@"Continue" forState:UIControlStateNormal];
    [continueButton setBackgroundColor:[UIColor ARISColorWhite]];
    [continueButton.titleLabel setFont:[UIFont systemFontOfSize:20]];
    [continueButton setTitleColor:[UIColor colorWithRed:0.0 green:0.0 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    continueButton.clipsToBounds = YES;
    continueButton.userInteractionEnabled = NO;
    continueButton.hidden = YES;
    [self.view addSubview:continueButton];
}


- (void) viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = leftNavButton;
}

- (void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self setOverlay:nil];
    [self setPrompt:@""];
}

- (void) showNav
{
    [delegate gamePlayTabBarViewControllerRequestsNav];
}

//implement gameplaytabbarviewcontrollerprotocol junk
- (NSString *) tabId { return @"AUGMENTED"; }
- (NSString *) tabTitle { if(tab.name && ![tab.name isEqualToString:@""]) return tab.name; return @"Scanner"; }
- (ARISMediaView *) tabIcon
{
    ARISMediaView *amv = [[ARISMediaView alloc] init];
    if(tab.icon_media_id)
        [amv setMedia:[_MODEL_MEDIA_ mediaForId:tab.icon_media_id]];
    else
        [amv setImage:[UIImage imageNamed:@"qr_icon"]];
    return amv;
}

- (CGRect)getCurrentARViewFrame
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGRect viewFrame = screenBounds;
    
    // If this device has a retina display, scale the view bounds
    // for the AR (OpenGL) view
    if (true) { // TODO: YES == vapp.isRetinaDisplay
        viewFrame.size.width *= [UIScreen mainScreen].nativeScale;
        viewFrame.size.height *= [UIScreen mainScreen].nativeScale;
    }
    return viewFrame;
}

- (void) pauseAR {
    NSError * error = nil;
    if (![vapp pauseAR:&error]) {
        NSLog(@"ARIS Vuforia: Error pausing AR:%@", [error description]);
    }
    [eaglView stopAudio];
}

- (void) resumeAR {
    NSError * error = nil;
    if(! [vapp resumeAR:&error]) {
        NSLog(@"ARIS Vuforia: Error resuming AR:%@", [error description]);
    }
    [eaglView updateRenderingPrimitives];
    // on resume, we reset the flash
    Vuforia::CameraDevice::getInstance().setFlashTorchMode(false);
}

- (void)viewDidAppear:(BOOL)animated
{
    lastQRTrigger = [NSDate date];
    [super viewDidAppear:animated];
    [self resumeAR];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pauseAR];
}

- (void)finishOpenGLESCommands
{
    // Called in response to applicationWillResignActive.  Inform the EAGLView
    [eaglView finishOpenGLESCommands];
}

- (void)freeOpenGLESResources
{
    // Called in response to applicationDidEnterBackground.  Inform the EAGLView
    [eaglView freeOpenGLESResources];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - loading animation

- (void) showLoadingAnimation {
    CGRect indicatorBounds;
    CGRect mainBounds = [[UIScreen mainScreen] bounds];
    int smallerBoundsSize = MIN(mainBounds.size.width, mainBounds.size.height);
    int largerBoundsSize = MAX(mainBounds.size.width, mainBounds.size.height);
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown ) {
        indicatorBounds = CGRectMake(smallerBoundsSize / 2 - 12,
                                     largerBoundsSize / 2 - 12, 24, 24);
    }
    else {
        indicatorBounds = CGRectMake(largerBoundsSize / 2 - 12,
                                     smallerBoundsSize / 2 - 12, 24, 24);
    }
    
    UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc]
                                                 initWithFrame:indicatorBounds];
    
    loadingIndicator.tag  = 1;
    loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    [eaglView addSubview:loadingIndicator];
    [loadingIndicator startAnimating];
}

- (void) hideLoadingAnimation {
    UIActivityIndicatorView *loadingIndicator = (UIActivityIndicatorView *)[eaglView viewWithTag:1];
    [loadingIndicator removeFromSuperview];
}


#pragma mark - SampleApplicationControl

// Initialize the application trackers
- (bool) doInitTrackers {
    // Initialize the object tracker
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::Tracker* trackerBase = trackerManager.initTracker(Vuforia::ObjectTracker::getClassType());
    if (trackerBase == NULL)
    {
        NSLog(@"ARIS Vuforia: Failed to initialize ObjectTracker.");
        return false;
    }
    return true;
}

// load the data associated to the trackers
- (bool) doLoadTrackersData {
    NSURL *url = _MODEL_AR_TARGETS_.xmlURL;
    if (!url) {
        NSString *g = [NSString stringWithFormat:@"%ld",_MODEL_GAME_.game_id];
        NSString *partial_url = [NSString stringWithFormat:@"%@/vuforiadb.xml",g];
        url = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@",_ARIS_LOCAL_URL_FROM_PARTIAL_PATH_(partial_url)]];
    }
    if ([[_MODEL_AR_TARGETS_ ar_targets] count] > 0) {
        dataSet = [self loadObjectTrackerDataSet:[url path]];
        if (dataSet == NULL) {
            NSLog(@"ARIS Vuforia: Failed to load datasets");
            return NO;
        }
        if (! [self activateDataSet:dataSet]) {
            NSLog(@"ARIS Vuforia: Failed to activate dataset");
            return NO;
        }
    }

    return YES;
}

// start the application trackers
- (bool) doStartTrackers {
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::Tracker* tracker = trackerManager.getTracker(Vuforia::ObjectTracker::getClassType());
    if(tracker == 0) {
        return false;
    }
    tracker->start();
    return true;
}

// callback called when the initailization of the AR is done
- (void) onInitARDone:(NSError *)initError {
    UIActivityIndicatorView *loadingIndicator = (UIActivityIndicatorView *)[eaglView viewWithTag:1];
    [loadingIndicator removeFromSuperview];
    
    if (initError == nil) {
        NSError * error = nil;
        [vapp startAR:Vuforia::CameraDevice::CAMERA_DIRECTION_BACK error:&error];
        
        [eaglView updateRenderingPrimitives];
        
        // by default, we try to set the continuous auto focus mode
        continuousAutofocusEnabled = Vuforia::CameraDevice::getInstance().setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO);
        
        //[eaglView configureBackground];
        
    } else {
        NSLog(@"ARIS Vuforia: Error initializing AR:%@", [initError description]);
        dispatch_async( dispatch_get_main_queue(), ^{
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:[initError localizedDescription]
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        });
    }
}

- (void)dismissARViewController
{
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self.navigationController popToRootViewControllerAnimated:NO];
}

- (void)configureVideoBackgroundWithViewWidth:(float)viewWidth andHeight:(float)viewHeight
{
    [eaglView configureVideoBackgroundWithViewWidth:(float)viewWidth andHeight:(float)viewHeight];
}

- (void) onVuforiaUpdate: (Vuforia::State *) state
{
    long trigger_id = [eaglView cur_trigger_id];
    NSString *cap = [eaglView caption];
    
    // hiding/unhiding the labels needs to happen on main thread
    dispatch_async(dispatch_get_main_queue(),^{
        continueButton.hidden = (trigger_id ? NO : YES);
        [self setCaption:cap];
    });
    
    if ( !unrecognizedQRPopup
        && [lastQRTrigger timeIntervalSinceNow] < -1.0 // if last qr scan was 1s ago or more
    ) {
        NSString *qr = [eaglView processQRString];
        if (qr) {
            lastQRTrigger = [NSDate date];
            if ([qr isEqualToString:@"log-out"]) {
                dispatch_async(dispatch_get_main_queue(),^{
                    [_MODEL_ logOut];
                });
            } else {
                Trigger *t = [_MODEL_TRIGGERS_ triggerForQRCode:qr];
                if (t) {
                    dispatch_async(dispatch_get_main_queue(),^{
                        [_MODEL_DISPLAY_QUEUE_ enqueueTrigger:t];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(),^{
                        unrecognizedQRPopup = YES;
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"QRScannerErrorTitleKey", nil) message:NSLocalizedString(@"QRScannerErrorMessageKey", nil) delegate:self cancelButtonTitle:NSLocalizedString(@"OkKey", @"") otherButtonTitles:nil];
                        [alert show];
                    });
                }
            }
        }
    }
}

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    lastQRTrigger = [NSDate date];
    unrecognizedQRPopup = NO;
}

// Load the image tracker data set
- (Vuforia::DataSet *)loadObjectTrackerDataSet:(NSString*)dataFile
{
    NSLog(@"ARIS Vuforia: loadObjectTrackerDataSet (%@)", dataFile);
    Vuforia::DataSet * tDataSet = NULL;
    
    // Get the Vuforia tracker manager image tracker
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    if(NULL == objectTracker)
    {
        NSLog(@"ARIS Vuforia: ERROR: failed to get the ObjectTracker from the tracker manager");
        return NULL;
    }
    else
    {
        tDataSet = objectTracker->createDataSet();
        
        if(NULL != tDataSet)
        {
            NSLog(@"ARIS Vuforia: INFO: successfully loaded data set");
            
            // Load the data set from the app's resources location
            if(dataFile && ![dataFile isEqualToString:@""])
            {
              if(!tDataSet->load([dataFile cStringUsingEncoding:NSASCIIStringEncoding], Vuforia::STORAGE_ABSOLUTE))
              {
                NSLog(@"ARIS Vuforia: ERROR: failed to load custom data set");
                objectTracker->destroyDataSet(tDataSet);
                tDataSet = NULL;
              }
            }
        }
        else
        {
            NSLog(@"ARIS Vuforia: ERROR: failed to create data set");
        }
    }
    
    return tDataSet;
}


- (bool) doStopTrackers {
    // Stop the tracker
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::Tracker* tracker = trackerManager.getTracker(Vuforia::ObjectTracker::getClassType());
    
    if (NULL != tracker) {
        tracker->stop();
        NSLog(@"INFO: successfully stopped tracker");
        return YES;
    }
    else {
        NSLog(@"ERROR: failed to get the tracker from the tracker manager");
        return NO;
    }
}

- (bool) doUnloadTrackersData {
    [self deactivateDataSet: dataSetCurrent];
    dataSetCurrent = nil;
    
    // Get the image tracker:
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    // Destroy the data sets:
    if (!objectTracker->destroyDataSet(dataSet))
    {
      NSLog(@"Failed to destroy data set");
    }
    
    NSLog(@"datasets destroyed");
    return YES;
}

- (BOOL)activateDataSet:(Vuforia::DataSet *)theDataSet
{
    // if we've previously recorded an activation, deactivate it
    if (dataSetCurrent != nil)
    {
        [self deactivateDataSet:dataSetCurrent];
    }
    BOOL success = NO;
    
    // Get the image tracker:
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    if (objectTracker == NULL) {
        NSLog(@"Failed to load tracking data set because the ObjectTracker has not been initialized.");
    }
    else
    {
        // Activate the data set:
        if (!objectTracker->activateDataSet(theDataSet))
        {
            NSLog(@"Failed to activate data set.");
        }
        else
        {
            NSLog(@"Successfully activated data set.");
            dataSetCurrent = theDataSet;
            success = YES;
        }
    }
    
    // we set the off target tracking mode to the current state
    if (success) {
        [self setExtendedTrackingForDataSet:dataSetCurrent start:NO];
    }
    
    return success;
}

- (BOOL)deactivateDataSet:(Vuforia::DataSet *)theDataSet
{
    if ((dataSetCurrent == nil) || (theDataSet != dataSetCurrent))
    {
        NSLog(@"Invalid request to deactivate data set.");
        return NO;
    }
    
    BOOL success = NO;
    
    // we deactivate the enhanced tracking
    [self setExtendedTrackingForDataSet:theDataSet start:NO];
    
    // Get the image tracker:
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    Vuforia::ObjectTracker* objectTracker = static_cast<Vuforia::ObjectTracker*>(trackerManager.getTracker(Vuforia::ObjectTracker::getClassType()));
    
    if (objectTracker == NULL)
    {
        NSLog(@"Failed to unload tracking data set because the ObjectTracker has not been initialized.");
    }
    else
    {
        // Activate the data set:
        if (!objectTracker->deactivateDataSet(theDataSet))
        {
            NSLog(@"Failed to deactivate data set.");
        }
        else
        {
            success = YES;
        }
    }
    
    dataSetCurrent = nil;
    
    return success;
}

- (BOOL) setExtendedTrackingForDataSet:(Vuforia::DataSet *)theDataSet start:(BOOL) start {
    BOOL result = YES;
    for (int tIdx = 0; tIdx < theDataSet->getNumTrackables(); tIdx++) {
        Vuforia::Trackable* trackable = theDataSet->getTrackable(tIdx);
        if (start) {
            if (!trackable->startExtendedTracking())
            {
                NSLog(@"Failed to start extended tracking on: %s", trackable->getName());
                result = false;
            }
        } else {
            if (!trackable->stopExtendedTracking())
            {
                NSLog(@"Failed to stop extended tracking on: %s", trackable->getName());
                result = false;
            }
        }
    }
    return result;
}

- (bool) doDeinitTrackers {
    Vuforia::TrackerManager& trackerManager = Vuforia::TrackerManager::getInstance();
    trackerManager.deinitTracker(Vuforia::ObjectTracker::getClassType());
    return YES;
}

- (void)selectTrigger:(UITapGestureRecognizer *)sender
{
    long trigger_id = [eaglView cur_trigger_id];
    if (!trigger_id) return;
    Trigger *t = [_MODEL_TRIGGERS_ triggerForId:trigger_id];
    if (!t) return;
    [_MODEL_DISPLAY_QUEUE_ enqueueTrigger:t];
}

- (void)cameraPerformAutoFocus
{
    Vuforia::CameraDevice::getInstance().setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_TRIGGERAUTO);
    
    // After triggering an autofocus event,
    // we must restore the previous focus mode
    if (continuousAutofocusEnabled)
    {
        [self performSelector:@selector(restoreContinuousAutoFocus) withObject:nil afterDelay:2.0];
    }
}

- (void)restoreContinuousAutoFocus
{
    Vuforia::CameraDevice::getInstance().setFocusMode(Vuforia::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO);
}

- (void) dealloc
{
    _ARIS_NOTIF_IGNORE_ALL_(self);
    
    [vapp stopAR:nil];
    
    // Be a good OpenGL ES citizen: now that Vuforia is paused and the render
    // thread is not executing, inform the root view controller that the
    // EAGLView should finish any OpenGL ES commands
    [self finishOpenGLESCommands];
    
    ARISAppDelegate *appDelegate = _DELEGATE_;
    appDelegate.glResourceHandler = nil;
}

@end

#endif
