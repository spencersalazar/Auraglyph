//
//  AGUtility.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 5/18/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGUtility.h"

#include <Foundation/Foundation.h>
#include "NSString+STLString.h"

std::string AGUtility::getVersionString()
{
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *versionString = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    std::string v = [versionString stlString];
    
#ifdef AG_BETA
    v += " (beta)";
#endif // AG_BETA
    
    return v;
}

void AGUtility::after(float timeInSeconds, std::function<void ()> func)
{
    [NSTimer scheduledTimerWithTimeInterval:timeInSeconds repeats:NO block:^(NSTimer * _Nonnull timer) {
        func();
    }];
}
