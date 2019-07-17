//
//  AGControl.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 2/6/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGControl.h"

AGControl::AGControl(const AGControl &ctl) : type(ctl.type)
{
    switch(type)
    {
        case TYPE_NONE:   break;
        case TYPE_BIT:    vbit = ctl.vbit; break;
        case TYPE_INT:    vint = ctl.vint; break;
        case TYPE_FLOAT:  vfloat = ctl.vfloat; break;
        case TYPE_STRING: vstring = ctl.vstring; break;
    }
}

AGControl AGControl::operator=(const AGControl &ctl)
{
    if(&ctl != this) {
        type = ctl.type;
        
        switch(type) {
            case TYPE_NONE:   break;
            case TYPE_BIT:    vbit = ctl.vbit; break;
            case TYPE_INT:    vint = ctl.vint; break;
            case TYPE_FLOAT:  vfloat = ctl.vfloat; break;
            case TYPE_STRING: vstring = ctl.vstring; break;
        }
    }
    
    return *this;
}

AGControl::AGControl(AGControl && ctl) : type(ctl.type)
{
    switch(type) {
        case TYPE_NONE:   break;
        case TYPE_BIT:    vbit = ctl.vbit; break;
        case TYPE_INT:    vint = ctl.vint; break;
        case TYPE_FLOAT:  vfloat = ctl.vfloat; break;
        case TYPE_STRING: vstring = ctl.vstring; break;
    }
}


AGFloat AGControl::getFloat() const
{
    switch(type) {
        case TYPE_NONE:   return 0;
        case TYPE_BIT:    return vbit ? 1.0f : 0.0f;
        case TYPE_INT:    return (float) vint;
        case TYPE_FLOAT:  return vfloat;
        case TYPE_STRING: return 0;
    }
    
    return 0;
}

AGInt AGControl::getInt() const
{
    switch(type) {
        case TYPE_NONE:   return 0;
        case TYPE_STRING: return 0;
        case TYPE_BIT:    return vbit ? 1 : 0;
        case TYPE_INT:    return vint;
        case TYPE_FLOAT:  return (int) vfloat;
    }
}

AGBit AGControl::getBit() const
{
    switch(type) {
        case TYPE_NONE:   return 0;
        case TYPE_STRING: return vstring.size() ? 1 : 0;
        case TYPE_BIT:    return vbit;
        case TYPE_INT:    return vint ? 1 : 0;
        case TYPE_FLOAT:  return vfloat ? 1 : 0;
    }
}

AGString AGControl::getString() const
{
    switch(type) {
        case TYPE_NONE:   return "";
        case TYPE_STRING: return vstring;
        case TYPE_BIT:    return vbit ? "1" : "0";
        case TYPE_INT: {
            stringstream str;
            str << vint;
            return str.str();
        }
        case TYPE_FLOAT: {
            stringstream str;
            str << vfloat;
            return str.str();
        }
    }
}

