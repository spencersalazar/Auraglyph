//
//  sputil.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 11/22/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "sputil.h"
#include <CoreFoundation/CoreFoundation.h>

string makeUUID()
{
    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    CFStringRef strRef = CFUUIDCreateString(NULL, uuidRef);
    string str = CFStringGetCStringPtr(strRef, kCFStringEncodingUTF8);
    
    CFRelease(strRef);
    CFRelease(uuidRef);
    
    return str;
}
