//
//  AGStyle.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/6/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGStyle__
#define __Auragraph__AGStyle__

#include "TexFont.h"
#include <string>

using namespace std;

class AGStyle
{
public:
    static const string &standardFontPath();
    static TexFont *standardFont64();
};

#endif /* defined(__Auragraph__AGStyle__) */
