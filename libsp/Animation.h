//
//  Animation.h
//  Auragraph
//
//  Created by Spencer Salazar on 3/10/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef Auragraph_Animation_h
#define Auragraph_Animation_h


struct slewf
{
    slewf() : value(0), target(0), slew(0) { }
    slewf(float _slew) : value(0), target(0), slew(_slew) { }
    slewf(float _slew, float _start) : value(_start), target(_start), slew(_slew) { }
    
    inline void interp() { value = (target-value)*slew + value; }
    
    // cast directly to float
    operator const float &() const { return value; }
    
    void operator=(const float &f) { target = f; }
    void operator+=(const float &f) { *this = value+f; }
    void operator-=(const float &f) { *this = value-f; }
    void operator*=(const float &f) { *this = value*f; }
    void operator/=(const float &f) { *this = value/f; }
    
    float value, target, slew;
};

struct clampf
{
    clampf(float _min = 0, float _max = 1) { value = 0; clamp(_min, _max); }
    
    inline void clamp(float _min, float _max) { min = _min; max = _max; }
    
    inline operator const float &() const { return value; }
    
    inline void operator=(const float &f)
    {
        if(f > max) value = max;
        else if(f < min) value = min;
        else value = f;
    }
    
    void operator+=(const float &f) { *this = value+f; }
    void operator-=(const float &f) { *this = value-f; }
    void operator*=(const float &f) { *this = value*f; }
    void operator/=(const float &f) { *this = value/f; }
    
    float value, min, max;
};

class curvef
{
public:
    curvef(float _start = 0, float _end = 1, float _rate = 1) :
    start(_start), end(_end), rate(_rate), t(0)
    { }
    
    virtual float evaluate(float t) const = 0;
    
    inline void update(float dt) { t += dt*rate; }
    inline void reset() { t = 0; }
    inline operator const float () const { return evaluate(t)*(end-start)+start; }
    
    float t, start, end, rate;
};

class powcurvef : public curvef
{
public:
    powcurvef(float _start = 0, float _end = 1, float _k = 2, float _rate = 1) :
    curvef(_start, _end, _rate), k(_k) { }
    
    virtual float evaluate(float t) const { return powf(t, k); }
    
    float k;
};

class expcurvef : public curvef
{
public:
    expcurvef(float _start = 0, float _end = 1, float _k = 10, float _rate = 1) :
    curvef(_start, _end, _rate), k(_k) { }
    
    virtual float evaluate(float t) const { return start + (end-start)*(1-powf(k, -t)); }
    
    float k;
};


#endif
