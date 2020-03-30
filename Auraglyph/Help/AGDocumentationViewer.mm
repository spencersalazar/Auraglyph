//
//  AGDocumentationViewer.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/16/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGDocumentationViewer.h"
#include "AGStyle.h"

#import <WebKit/WebKit.h>

@interface AGDocumentationView : UIView
{
    WKWebView *_webView;
    UIButton *_button;
}

- (id)initWithFrame:(CGRect)frame;

- (void)open;
- (void)close;

@end

@implementation AGDocumentationView

- (id)initWithFrame:(CGRect)frame;
{
    if(self = [super initWithFrame:frame])
    {
        UIColor *fgColor = [UIColor colorWithRed:0.75 green:0.5 blue:0 alpha:1];
        UIColor *bgColor = [UIColor colorWithRed:12.0/255.0 green:16.0/255.0 blue:33.0/255.0 alpha:1];
        self.backgroundColor = fgColor;
        
        float borderWidth = 2;
        CGRect rect = frame;
        rect.origin.x = borderWidth; rect.origin.y = borderWidth;
        rect.size.width -= borderWidth*2; rect.size.height -= borderWidth*2;
        
        UIView *backgroundView = [[UIView alloc] initWithFrame:rect];
        backgroundView.backgroundColor = bgColor;
        [self addSubview:backgroundView];
        
        WKWebViewConfiguration *config = [WKWebViewConfiguration new];
        _webView = [[WKWebView alloc] initWithFrame:rect configuration:config];
        _webView.backgroundColor = bgColor;
        _webView.opaque = NO;
        NSURL *indexUrl = [[NSBundle mainBundle] URLForResource:@"docs/index.html" withExtension:@""];
        NSURL *dirUrl = [[NSBundle mainBundle] bundleURL];
        [_webView loadFileURL:indexUrl allowingReadAccessToURL:dirUrl];
        [self insertSubview:_webView aboveSubview:backgroundView];
        
        _button = [UIButton buttonWithType:UIButtonTypeSystem];
        CGRect buttonRect;
        float margin = 10;
        buttonRect.size = { 100, 50 };
        // position in bottom right
        buttonRect.origin = { frame.size.width-margin-buttonRect.size.width, frame.size.height-margin-buttonRect.size.height };
        _button.frame = buttonRect;
        [_button addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
        [_button setTitle:@"close" forState:UIControlStateNormal];
        _button.titleLabel.font = [UIFont fontWithName:@"Orbitron-Regular" size:18];
        [_button setTitleColor:fgColor forState:UIControlStateNormal];

        [self insertSubview:_button aboveSubview:_webView];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidChangeStatusBarOrientationNotification
                                                          object:nil queue:nil
                                                      usingBlock:^(NSNotification * _Nonnull note) {
                                                          [self orientationChanged];
                                                      }];
    }
    
    return self;
}

- (void)open
{
    self.transform = CGAffineTransformMakeScale(0.01, 0.01);
    
    [UIView animateWithDuration:AGStyle::open_animTimeX delay:0.0
                        options: UIViewAnimationOptionCurveLinear
                     animations:^{
                         self.transform = CGAffineTransformMakeScale(1, 0.01);
                     } completion:^(BOOL finished) {
                         [UIView animateWithDuration:AGStyle::open_animTimeY delay:0.0
                                             options: UIViewAnimationOptionCurveLinear
                                          animations:^{
                                              self.transform = CGAffineTransformMakeScale(1, 1);
                                          } completion:^(BOOL finished) {
                                          }];
                     }];
}

- (void)close
{
    [UIView animateWithDuration:AGStyle::open_animTimeY*0.5 delay:0.0
                        options: UIViewAnimationOptionCurveLinear
                     animations:^{
                         self.transform = CGAffineTransformMakeScale(1, 0.01);
                     } completion:^(BOOL finished) {
                         [UIView animateWithDuration:AGStyle::open_animTimeX*0.5 delay:0.0
                                             options: UIViewAnimationOptionCurveLinear
                                          animations:^{
                                              self.transform = CGAffineTransformMakeScale(0.01, 0.01);
                                          } completion:^(BOOL finished) {
                                              [self removeFromSuperview];
                                          }];
                     }];
}

- (void)orientationChanged
{
    CGRect frame = self.window.bounds;
    frame.origin.x = frame.size.width*0.1; frame.origin.y = frame.size.height*0.1;
    frame.size.width *= 0.8; frame.size.height *= 0.8;
    self.frame = frame;
    
    float borderWidth = 2;
    CGRect rect = frame;
    rect.origin.x = borderWidth; rect.origin.y = borderWidth;
    rect.size.width -= borderWidth*2; rect.size.height -= borderWidth*2;
    _webView.frame = rect;
    
    CGRect buttonRect;
    float margin = 10;
    buttonRect.size = { 100, 50 };
    // position in bottom right
    buttonRect.origin = { frame.size.width-margin-buttonRect.size.width, frame.size.height-margin-buttonRect.size.height };
    _button.frame = buttonRect;
}

@end

void AGDocumentationViewer::show()
{
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    
    CGRect rect = window.bounds;
    rect.origin.x = rect.size.width*0.1; rect.origin.y = rect.size.height*0.1;
    rect.size.width *= 0.8; rect.size.height *= 0.8;
    
    AGDocumentationView *docView = [[AGDocumentationView alloc] initWithFrame:rect];
    [docView open];
    
    [window insertSubview:docView aboveSubview:window.rootViewController.view];
}


