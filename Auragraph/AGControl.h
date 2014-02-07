//
//  AGControl.h
//  Auragraph
//
//  Created by Spencer Salazar on 2/6/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGControl__
#define __Auragraph__AGControl__

class AGControl
{
public:
    virtual void mapTo(float &value) = 0;
};

class AGIntControl : public AGControl
{
public:
    AGIntControl() : v(0) { }
    AGIntControl(int _v) : v(_v) { }
    virtual void mapTo(float &value) { value = v; }
    int v;
};

class AGFloatControl : public AGControl
{
public:
    AGFloatControl() : v(0) { }
    AGFloatControl(float _v) : v(_v) { }
    virtual void mapTo(float &value) { value = v; }
    float v;
};

#endif /* defined(__Auragraph__AGControl__) */
