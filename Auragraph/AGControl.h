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

using namespace std;

class AGControl
{
public:
    AGControl() : type(TYPE_NONE) { }
    AGControl(bool b) : type(TYPE_BIT), vbit(b) { }
    AGControl(int i) : type(TYPE_INT), vint(i) { }
    AGControl(float f) : type(TYPE_FLOAT), vfloat(f) { }

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
        bool vbit;
        int vint;
        float vfloat;
        string vstring;
    };
    
    void mapTo(float &v) const
    {
        switch(type)
        {
            case TYPE_NONE:
            case TYPE_STRING:
                v = 0;
                break;
            case TYPE_BIT:
                v = vbit;
                break;
            case TYPE_INT:
                v = (float) vint;
                break;
            case TYPE_FLOAT:
                v = vfloat;
                break;
        }
    }
    
    void mapTo(int &v) const
    {
        switch(type)
        {
            case TYPE_NONE:
            case TYPE_STRING:
                v = 0;
                break;
            case TYPE_BIT:
                v = vbit;
                break;
            case TYPE_INT:
                v = vint;
                break;
            case TYPE_FLOAT:
                v = (int) vfloat;
                break;
        }
    }
    
    operator bool()
    {
        return type != TYPE_NONE;
    }
};

#endif /* defined(__Auragraph__AGControl__) */
