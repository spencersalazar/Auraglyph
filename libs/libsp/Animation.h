//
//  Animation.h
//  Auragraph
//
//  Created by Spencer Salazar on 3/10/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef Auragraph_Animation_h
#define Auragraph_Animation_h

#include <math.h>

struct second;
struct rate;

struct second
{
    float value = 0;
    
    second(float _value = 0) : value(_value) { }
    
    rate operator ()() const;
};

struct rate
{
    float value = 0;
    
    rate(float _value = 0) : value(_value) { }

    second operator ()() const;
};

inline rate second::operator ()() const
{
    return rate { 1/value };
}

inline second rate::operator ()() const
{
    return second { 1/value };
}

/** Ease in/out function with settable power and midpoint.
 Use p parameter to adjust speed at endpoints (cubic: p=3, quartic: p=4)
 Midpoint is point at which speed is fastest and uneased. 
 */
inline float easeInOut(float t, float p = 3.f, float mid = 0.5f)
{
    if (t < mid) {
        return powf(t/mid, p)*mid;
    } else {
        return 1.f-powf((1.f-t)/(1-mid), p)*(1-mid);
    }
}


/**
 map value in input range to output range, with optional scaling - full version
 */
template<typename Type>
Type rescale(Type v, Type minIn, Type maxIn, Type minOut, Type maxOut, Type power = 1)
{
    Type unit = (v-minIn)/(maxIn-minIn);
    if(power != 1.0f)
        unit = powf(unit, power);;
    return minOut+(unit*(maxOut-minOut));
}

/**
 map value in input range to output range, with optional scaling - unit input version
 */
template<typename Type>
Type rescale(Type v, Type minOut, Type maxOut, Type power = 1)
{
    return rescale<Type>(v, 0, 1, minOut, maxOut, power);
}

/*------------------------------------------------------------------------------
 slew/slewf
 Gradually ease data type to target value. "Getting" the value returns the
 smoothed value, while "setting" it sets the target that is eased to. You need
 to call interp() at a periodic interval, e.g. the graphics frame rate.
 
 Supports a DestType (the final type of the thing you are tracking) and a
 ContainerType, which can be any type that is convertible to the DestType
 (e.g. clamp<DestType>).
 -----------------------------------------------------------------------------*/
template<typename DestType, typename ContainerType=DestType>
struct slew
{
    slew() : value(0), target(0), rate(0.5) { }
    slew(float _rate) : value(0), target(0), rate(_rate) { }
    slew(float _rate, DestType _start) : value(_start), target(_start), rate(_rate) { }
    
    inline void reset() { value = target; }
    inline void reset(DestType _val) { target = _val; value = _val; }
    inline void interp() { value = (target-value)*rate + value; }
    inline void fromTo(DestType from, DestType to) { value = from; target = to; }
    
    // cast directly to float
    operator const DestType &() const { return value; }
    
    void operator=(const DestType &f) { target = f; }
    void operator+=(const DestType &f) { *this = value+f; }
    void operator-=(const DestType &f) { *this = value-f; }
    void operator*=(const DestType &f) { *this = value*f; }
    void operator/=(const DestType &f) { *this = value/f; }
    
    ContainerType value, target;
    float rate;
};

typedef slew<float> slewf;

/*------------------------------------------------------------------------------
 ### clamp/clampf ###
 Clamp value to min/max values. Setting the value will force it into the 
 configured range, and getting it thereafter will return the (potentially)
 clamped value.
 -----------------------------------------------------------------------------*/
#pragma mark - clamp/clampf

template<typename T>
struct clamp
{
    //clamp(T _min = 0, T _max = 1) { value = 0; clampTo(_min, _max); }
    
    clamp(T _value = 0, T _min = 0, T _max = 1) { clampTo(_min, _max); *this = _value; }
    
    inline void clampTo(T _min, T _max) { min = _min; max = _max;  *this = value; }
    
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


/*------------------------------------------------------------------------------
 ### momentum ###
 Apply momentum to a value after it is moved manually based on velocity of the
 manual tracking.
 
 Supports a DestType (the final type of the thing you are tracking) and a
 ContainerType, which can be any type that is convertible to the DestType
 (e.g. clamp<DestType>).
 -----------------------------------------------------------------------------*/
#pragma mark - momentum

template<typename DestType, typename ContainerType=DestType>
class momentum
{
public:
    momentum(DestType x = 0, float slew = 0.5, float loss = 0.75, float drag = 0.05, float gain = 10)
    : m_x(x), m_slew(slew), m_loss(loss), m_drag(drag), m_gain(gain), m_v(0)
    { }
    
    void set(float slew, float loss, float drag, float gain)
    {
        m_slew = slew;
        m_loss = loss;
        m_drag = drag;
        m_gain = gain;
    }
    
    void setSlew(float slew) { m_slew = slew; }
    void setLoss(float loss) { m_loss = loss; }
    void setDrag(float drag) { m_drag = drag; }
    void setGain(float gain) { m_gain = gain; }
    
    void update(float t, float dt)
    {
        m_t = t;
        
        if(m_on)
        {
            m_v *= m_loss;
            dbgprint_off("v %f\n", m_v);
        }
        else
        {
            m_v *= (1-m_drag);
            m_x += m_v*dt*m_gain;
            dbgprint_off("v %f\n", m_v);
        }
    }
    
    void on()
    {
        m_on = true;
        m_v = 0;
        dbgprint_off("mom on\n");
    }
    
    void off()
    {
        m_on = false;
        *this += 0; // throw in final 0-velocity
        dbgprint_off("mom off\n");
    }
    
    DestType operator +=(const DestType &dx)
    {
        m_x += dx;
        
        float dt = m_t-m_lastInput;
        if(dt < (1.0f/30.0f))
            dt = (1.0f/30.0f);
        
        m_v = m_v*(m_slew) + (dx/dt)*(1-m_slew);
        
        m_lastInput = m_t;
        
        return m_x;
    }
    
    operator DestType () { return (DestType) m_x; }
    
    ContainerType &raw() { return m_x; }
    
private:
    ContainerType m_x; // position
    DestType m_v; // velocity
    float m_t; // current time
    float m_lastInput; // time of last input
    float m_slew; // slew rate of velocity tracking
    float m_loss; // attenuation of velocity over time while on/held
    float m_drag; // attenuation of velocity over time while off/not held
    float m_gain; // scale factor for applying velocity to position while not held/off
    bool m_on; // whether is held or not held
};


/*------------------------------------------------------------------------------
 ### curvef ###
 -----------------------------------------------------------------------------*/
#pragma mark - curvef

class curvef
{
public:
    curvef(float _start = 0, float _end = 1, float _rate = 1) :
    start(_start), end(_end), rate(_rate), t(0)
    { }
    
    virtual float evaluate(float t) const = 0;
    
    inline void update(float dt) { t += dt*rate; }
    inline void reset() { t = 0; }
    inline void reset(float _start, float _end) { t = 0; start = _start; end = _end; }
    inline void finish() { t = 1; }
    inline void forceTo(float val) { t = 1; start = val; end = val; }
    inline bool isFinished() { return t >= 1; }
    
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

/*------------------------------------------------------------------------------
 ### compoundf ###
 -----------------------------------------------------------------------------*/
#pragma mark - compoundf

#include <vector>
#include <memory>

class compoundf : public curvef
{
public:
    template<typename CurveType>
    compoundf(CurveType c)
    {
        m_curves.push_back(std::unique_ptr<CurveType>(c));
    }
    
    template<typename CurveType, typename... Curves>
    compoundf(CurveType c, Curves... curves)
    {
        m_curves.push_back(std::unique_ptr<CurveType>(c));
        compoundf(curves...);
    }

private:
    std::vector<std::unique_ptr<curvef>> m_curves;
};

/*------------------------------------------------------------------------------
 ### lincurvef ###
 -----------------------------------------------------------------------------*/
#pragma mark - lincurvef

class lincurvef : public curvef
{
public:
    lincurvef() : curvef(0, 1, 1), time(1) { }

    lincurvef(float _time, float _start, float _end, float _rate = 1) :
    curvef(_start, _end, _rate), time(_time) { }
    
    virtual float evaluate(float t) const { return t/time; }
    
    float time;
};

/*------------------------------------------------------------------------------
 ### powcurvef ###
 -----------------------------------------------------------------------------*/
#pragma mark - powcurvef

class powcurvef : public curvef
{
public:
    powcurvef() : curvef(0, 1, 1), k(2) { }

    powcurvef(float _start, float _end, float _k = 2, float _rate = 1) :
    curvef(_start, _end, _rate), k(_k) { }
    
    virtual float evaluate(float t) const { return powf(t, k); }
    
    float k;
};

/*------------------------------------------------------------------------------
 ### expcurvef ###
 -----------------------------------------------------------------------------*/
#pragma mark - expcurvef

class expcurvef : public curvef
{
public:
    expcurvef() : curvef(0, 1, 1), k(10) { }

    expcurvef(float _start, float _end, float _k = 10, float _rate = 1) :
    curvef(_start, _end, _rate), k(_k) { }
    
    virtual float evaluate(float t) const { return (1-powf(k, -t)); }
    
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
