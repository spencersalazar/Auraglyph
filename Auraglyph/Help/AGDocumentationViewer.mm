//
//  AGDocumentationViewer.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/16/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "AGDocumentationViewer.h"
#import <WebKit/WebKit.h>

AGDocumentationViewer::AGDocumentationViewer()
{
    
}

void AGDocumentationViewer::show()
{
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    
    CGRect rect = window.bounds;
    rect.origin.x = rect.size.width*0.1; rect.origin.y = rect.size.height*0.1;
    rect.size.width *= 0.8; rect.size.height *= 0.8;
    
    UIView *containerView = [[UIView alloc] initWithFrame:rect];
    containerView.backgroundColor = [UIColor colorWithRed:0.75 green:0.5 blue:0 alpha:1];
    
    float borderWidth = 2;
    rect.origin.x = borderWidth; rect.origin.y = borderWidth;
    rect.size.width -= borderWidth*2; rect.size.height -= borderWidth*2;

    WKWebView *webView = [[WKWebView alloc] initWithFrame:rect configuration:config];
    NSURL *indexUrl = [[NSBundle mainBundle] URLForResource:@"docs/index.html" withExtension:@""];
    NSURL *dirUrl = [[NSBundle mainBundle] bundleURL];
    [webView loadFileURL:indexUrl allowingReadAccessToURL:dirUrl];
    [containerView addSubview:webView];
    
    [window insertSubview:containerView aboveSubview:window.rootViewController.view];
}
