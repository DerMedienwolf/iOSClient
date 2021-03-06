//
//  ARISMediaView.h
//  ARIS
//
//  Created by Phil Dougherty on 8/1/13.
//
//

#import <UIKit/UIKit.h>
#import "Media.h"

typedef enum
{
ARISMediaDisplayModeDefault,
ARISMediaDisplayModeAspectFill,
ARISMediaDisplayModeStretchFill,
ARISMediaDisplayModeAspectFit,
ARISMediaDisplayModeTopAlignAspectFitWidth,
ARISMediaDisplayModeTopAlignAspectFitWidthAutoResizeHeight
} ARISMediaDisplayMode;

typedef enum
{
ARISMediaContentTypeDefault,
ARISMediaContentTypeFull,
ARISMediaContentTypeThumb
} ARISMediaContentType;

@class ARISMediaView;
@protocol ARISMediaViewDelegate
@optional
- (void) ARISMediaViewFrameUpdated:(ARISMediaView *)amv;
- (void) ARISMediaViewFinishedPlayback:(ARISMediaView *)amv;
- (BOOL) ARISMediaViewShouldPlayButtonTouched:(ARISMediaView *)amv;
- (void) ARISMediaViewIsReadyToPlay:(ARISMediaView *)amv;
@end

@interface ARISMediaView : UIView

- (id) initWithDelegate:(id<ARISMediaViewDelegate>)d;
- (id) initWithFrame:(CGRect)f delegate:(id<ARISMediaViewDelegate>)d;
- (void) setDelegate:(id<ARISMediaViewDelegate>)d;
- (void) setDisplayMode:(ARISMediaDisplayMode)dm;
- (void) setContentType:(ARISMediaContentType)ct;
- (void) setFrame:(CGRect)f;
- (void) setMedia:(Media *)m;
- (void) setImage:(UIImage *)i;
- (void) play;
- (void) stop;

- (Media *) media;
- (UIImage *) image;

@end

