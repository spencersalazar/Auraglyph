//
//  Animation.h
//  Auragraph
//
//  Created by Spencer Salazar on 3/10/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef Auragraph_Animation_h
#define Auragraph_Animation_h

/*------------------------------------------------------------------------------
 slew/slewf
 Gradually ease data type to target value. "Getting" the value returns the
 smoothed value, while "setting" it sets the target that is eased to. You need
 to call interp() at a periodic interval, e.g. the graphics frame rate.
 -----------------------------------------------------------------------------*/
template<typename T>
struct slew
{
    slew() : value(0), target(0), rate(0) { }
    slew(float _rate) : value(0), target(0), rate(_rate) { }
    slew(float _rate, T _start) : value(_start), target(_start), rate(_rate) { }
    
    inline void reset(T _val) { target = _val; value = _val; }
    inline void interp() { value = (target-value)*rate + value; }
    
    // cast directly to float
    operator const T &() const { return value; }
    
    void operator=(const T &f) { target = f; }
    void operator+=(const T &f) { *this = value+f; }
    void operator-=(const T &f) { *this = value-f; }
    void operator*=(const T &f) { *this = value*f; }
    void operator/=(const T &f) { *this = value/f; }
    
    T value, target;
    float rate;
};

typedef slew<float> slewf;

/*------------------------------------------------------------------------------
 clamp/clampf
 Clamp value to min/max values. Setting the value will force it into the 
 configured range, and getting it thereafter will return the (potentially)
 clamped value.
 -----------------------------------------------------------------------------*/
template<typename T>
struct clamp
{
    clamp(T _min = 0, T _max = 1) { value = 0; clampTo(_min, _max); }
    
    inline void clampTo(T _min, T _max) { min = _min; max = _max; }
    
    inline operator const T &() const { return value; }
    
    inline void operator=(const T &f)
    {
        if(f > max) value = max;
        else if(f < min) value = min;
        else value = f;
    }
    
    void operator+=(const T &f) { *this = value+f; }
    void operator-=(const T &f) { *this = value-f; }
    void operator*=(const T &f) { *this = value*f; }
    void operator/=(const T &f) { *this = value/f; }
    
    T value, min, max;
};

typedef clamp<float> clampf;


class curvef
{
public:
    curvef(float _start = 0, float _end = 1, float _rate = 1) :
    start(_start), end(_end), rate(_rate), t(0)
    { }
    
    virtual float evaluate(float t) const = 0;
    
    inline void update(float dt) { t += dt*rate; }
    inline void reset() { t = 0; }
    
    inline operator const float () const
    {
        float v = evaluate(t)*(end-start)+start;
        
        if(start<end)
        {
            if(v<start) return start;
            if(v>end) return end;
        }
        else if(end<start)
        {
            if(v<end) return end;
            if(v>start) return start;
        }
        
        return v;
    }
    
    float t, start, end, rate;
};

class lincurvef : public curvef
{
public:
    lincurvef(float _time = 1, float _start = 0, float _end = 1, float _rate = 1) :
    curvef(_start, _end, _rate), time(_time) { }
    
    virtual float evaluate(float t) const { return t/time; }
    
    float time;
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


//template<typename T, typename SlewType=float>
//struct slew
//{
////    slew() : slewrate(0.1) { }
////    slew(SlewType _slew) : slewrate(_slew) { }
//    slew(SlewType _slew, T _start) : value(_start), target(_start), slewrate(_slew) { }
//    
//    inline void reset(T _val) { target = _val; value = _val; }
//    inline void interp() { value = (target-value)*slewrate + value; }
//    
//    // cast directly to float
//    operator const T &() const { return value; }
//    
//    void operator=(const T &f) { target = f; }
//    void operator+=(const T &f) { target = target+f; }
//    void operator-=(const T &f) { target = target-f; }
//    void operator*=(const T &f) { target = target*f; }
//    void operator/=(const T &f) { target
//        = target/f; }
//    
//    T value, target;
//    SlewType slewrate;
//};



#endif
