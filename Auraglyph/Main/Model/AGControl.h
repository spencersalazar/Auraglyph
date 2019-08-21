//
//  AGControl.h
//  Auragraph
//
//  Created by Spencer Salazar on 2/6/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGControl__
#define __Auragraph__AGControl__

#include <string>
#include <float.h>
#include <sstream>

using namespace std;

typedef bool AGBit;
typedef int AGInt;
typedef float AGFloat;
typedef string AGString;

const static float AGFloat_Min = FLT_MIN;
const static float AGFloat_Max = FLT_MAX;
const static int AGInt_Min = INT_MIN;
const static float AGInt_Max = INT_MAX;

class AGControl
{
public:
    enum Type
    {
        TYPE_NONE,
        TYPE_BIT,
        TYPE_INT,
        TYPE_FLOAT,
        TYPE_STRING,
    };
    
    AGControl() : type(TYPE_NONE) { }
    AGControl(AGBit b) : type(TYPE_BIT), vbit(b) { }
    AGControl(AGInt i) : type(TYPE_INT), vint(i) { }
    AGControl(AGFloat f) : type(TYPE_FLOAT), vfloat(f) { }
    AGControl(double f) : type(TYPE_FLOAT), vfloat(f) { }
    AGControl(const AGString &s) : type(TYPE_STRING), vstring(s) { }
    AGControl(const char *s) : type(TYPE_STRING), vstring(s) { }

    AGControl(const AGControl &ctl);
    
    AGControl operator=(const AGControl &ctl);
    
    AGControl(AGControl && ctl);
    
    ~AGControl() { }
    
    Type type;
    
    union
    {
        AGBit vbit;
        AGInt vint;
        AGFloat vfloat;
    };
    
    AGString vstring;
    
    AGBit getBit() const;
    AGInt getInt() const;
    AGFloat getFloat() const;
    AGString getString() const;
    
    void mapTo(AGBit &v) const { v = getBit(); }
    void mapTo(AGFloat &v) const {v = getFloat(); }
    void mapTo(AGInt &v) const { v = getInt(); }
    void mapTo(AGString &v) const { v = getString(); }

    operator bool() const { return getBit(); }
    operator AGInt() const { return getInt(); }
    operator AGFloat() const { return getFloat(); }
    operator double() const { return getFloat(); }
    operator AGString() const { return getString(); }
};

#endif /* defined(__Auragraph__AGControl__) */
