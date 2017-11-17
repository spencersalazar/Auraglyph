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
    AGControl() : type(TYPE_NONE) { }
    AGControl(AGBit b) : type(TYPE_BIT), vbit(b) { }
    AGControl(AGInt i) : type(TYPE_INT), vint(i) { }
    AGControl(AGFloat f) : type(TYPE_FLOAT), vfloat(f) { }
    AGControl(const AGString &s) : type(TYPE_STRING), vstring(s) { }

    AGControl(const AGControl &ctl) : type(ctl.type)
    {
        switch(type)
        {
            case TYPE_NONE:
                break;
            case TYPE_BIT:
                vbit = ctl.vbit;
                break;
            case TYPE_INT:
                vint = ctl.vint;
                break;
            case TYPE_FLOAT:
                vfloat = ctl.vfloat;
                break;
            case TYPE_STRING:
                vstring = ctl.vstring;
                break;
        }
    }
    
    AGControl operator=(const AGControl &ctl)
    {
        if(&ctl != this)
        {
            type = ctl.type;
            
            switch(type)
            {
                case TYPE_NONE:
                    break;
                case TYPE_BIT:
                    vbit = ctl.vbit;
                    break;
                case TYPE_INT:
                    vint = ctl.vint;
                    break;
                case TYPE_FLOAT:
                    vfloat = ctl.vfloat;
                    break;
                case TYPE_STRING:
                    vstring = ctl.vstring;
                    break;
            }
        }
        
        return *this;
    }
    
    AGControl(AGControl && ctl) : type(ctl.type)
    {
        switch(type)
        {
            case TYPE_NONE:
                break;
            case TYPE_BIT:
                vbit = ctl.vbit;
                break;
            case TYPE_INT:
                vint = ctl.vint;
                break;
            case TYPE_FLOAT:
                vfloat = ctl.vfloat;
                break;
            case TYPE_STRING:
                vstring = ctl.vstring;
                break;
        }
    }
    
    ~AGControl() { }
    
    enum Type
    {
        TYPE_NONE,
        TYPE_BIT,
        TYPE_INT,
        TYPE_FLOAT,
        TYPE_STRING,
    };
    
    Type type;
    
    union
    {
        AGBit vbit;
        AGInt vint;
        AGFloat vfloat;
    };
    
    AGString vstring;
    
    
    AGFloat getFloat() const
    {
        switch(type)
        {
            case TYPE_NONE:
            case TYPE_STRING:
                return 0;
            case TYPE_BIT:
                return vbit ? 1.0f : 0.0f;
            case TYPE_INT:
                return (float) vint;
            case TYPE_FLOAT:
                return vfloat;
        }
        
        return 0;
    }
    
    void mapTo(AGFloat &v) const
    {
        v = getFloat();
    }
    
    operator AGFloat() const
    {
        return getFloat();
    }
    
    operator double() const
    {
        return getFloat();
    }
    
    AGInt getInt() const
    {
        switch(type)
        {
            case TYPE_NONE:
            case TYPE_STRING:
                return 0;
                break;
            case TYPE_BIT:
                return vbit ? 1 : 0;
                break;
            case TYPE_INT:
                return vint;
                break;
            case TYPE_FLOAT:
                return (int) vfloat;
                break;
        }
    }
    
    void mapTo(AGInt &v) const
    {
        v = getInt();
    }
    
    operator AGInt() const
    {
        return getInt();
    }
    
    AGString getString() const
    {
        switch(type)
        {
            case TYPE_NONE: return "";
            case TYPE_STRING: return vstring;
            case TYPE_BIT: return vbit ? "1" : "0";
            case TYPE_INT:
            {
                stringstream str;
                str << vint;
                return str.str();
            }
            case TYPE_FLOAT:
            {
                stringstream str;
                str << vfloat;
                return str.str();
            }
        }
    }
    
    void mapTo(AGString &v) const
    {
        v = getString();
    }
    
    operator AGString() const
    {
        return getString();
    }
    
    operator bool() const
    {
        return type != TYPE_NONE;
    }
};

#endif /* defined(__Auragraph__AGControl__) */
