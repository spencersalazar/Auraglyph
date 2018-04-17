//
//  AGDocumentationViewer.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/16/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGDocumentationViewer.h"
#import <WebKit/WebKit.h>

@interface AGDocumentationView : UIView
{
    WKWebView *_webView;
    UIButton *_button;
}

- (id)initWithFrame:(CGRect)frame;

- (void)close;

@end

@implementation AGDocumentationView

- (id)initWithFrame:(CGRect)frame;
{
    if(self = [super initWithFrame:frame])
    {
        UIColor *fgColor = [UIColor colorWithRed:0.75 green:0.5 blue:0 alpha:1];
        self.backgroundColor = fgColor;
        
        float borderWidth = 2;
        CGRect rect = frame;
        rect.origin.x = borderWidth; rect.origin.y = borderWidth;
        rect.size.width -= borderWidth*2; rect.size.height -= borderWidth*2;
        
        WKWebViewConfiguration *config = [WKWebViewConfiguration new];
        _webView = [[WKWebView alloc] initWithFrame:rect configuration:config];
        NSURL *indexUrl = [[NSBundle mainBundle] URLForResource:@"docs/index.html" withExtension:@""];
        NSURL *dirUrl = [[NSBundle mainBundle] bundleURL];
        [_webView loadFileURL:indexUrl allowingReadAccessToURL:dirUrl];
        [self addSubview:_webView];
        
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

- (void)close
{
    [self removeFromSuperview];
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
    
    [window insertSubview:docView aboveSubview:window.rootViewController.view];
}


