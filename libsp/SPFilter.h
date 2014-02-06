/*
 *  SPFilter.h
 *  BallPit
 *
 *  Created by Spencer Salazar on 5/6/11.
 *  Copyright 2011 Spencer Salazar. All rights reserved.
 *
 */


#include <math.h>

#if !defined(MIN)
#define MIN(A,B)	({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __a : __b; })
#endif

#if !defined(MAX)
#define MAX(A,B)	({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __b : __a; })
#endif

#define SQRT2  (1.41421356237309504880)

// shamelessly lifted from ChucK, into which it was shamelessly lifted from SC3

typedef float SAMPLE;

struct Butterworth2Filter
{
    // much of this implementation is adapted or copied outright from SC3
    SAMPLE m_y1;
    SAMPLE m_y2;
    SAMPLE m_a0;
    SAMPLE m_b1;
    SAMPLE m_b2;
    float m_freq;
    float m_Q;
    float m_db;
    
    float m_radians_per_sample;
    
    Butterworth2Filter()
    {
        m_y1 = m_y2 = 0;
        set_rlpf(220,1);
    }
    
    inline void set_sample_rate(float srate)
    {
        m_radians_per_sample = 2.0 * M_PI / srate;
    }
    
    
    inline void set_lpf( float freq, float Q )
    {
        float pfreq = freq * m_radians_per_sample * 0.5;
        
        float C = 1.0 / ::tan(pfreq);
        float C2 = C * C;
        float sqrt2C = C * SQRT2;
        float next_a0 = 1.0 / (1.0 + sqrt2C + C2);
        float next_b1 = -2.0 * (1.0 - C2) * next_a0 ;
        float next_b2 = -(1.f - sqrt2C + C2) * next_a0;
        
        m_freq = freq;
        m_a0 = (SAMPLE)next_a0;
        m_b1 = (SAMPLE)next_b1;
        m_b2 = (SAMPLE)next_b2;
    }
    
    
    // tick_lpf
    inline SAMPLE tick_lpf( SAMPLE in )
    {
        SAMPLE y0, result;
        
        // go: adapted from SC3's LPF
        y0 = in + m_b1 * m_y1 + m_b2 * m_y2;
        result = m_a0 * (y0 + 2 * m_y1 + m_y2);
        m_y2 = m_y1;
        m_y1 = y0;
        
        // be normal
//        CK_DDN(m_y1);
//        CK_DDN(m_y2);
        
        return result;
    }
    
    
    inline void set_hpf( float freq, float Q )
    {
        float pfreq = freq * m_radians_per_sample * 0.5;
        
        float C = ::tan(pfreq);
        float C2 = C * C;
        float sqrt2C = C * SQRT2;
        float next_a0 = 1.0 / (1.0 + sqrt2C + C2);
        float next_b1 = 2.0 * (1.0 - C2) * next_a0 ;
        float next_b2 = -(1.0 - sqrt2C + C2) * next_a0;
        
        m_freq = freq;
        m_a0 = (SAMPLE)next_a0;
        m_b1 = (SAMPLE)next_b1;
        m_b2 = (SAMPLE)next_b2;
    }
    
    
    // tick_hpf
    inline SAMPLE tick_hpf( SAMPLE in )
    {
        SAMPLE y0, result;
        
        // go: adapted from SC3's HPF
        y0 = in + m_b1 * m_y1 + m_b2 * m_y2;
        result = m_a0 * (y0 - 2 * m_y1 + m_y2);
        m_y2 = m_y1;
        m_y1 = y0;
        
        // be normal
//        CK_DDN(m_y1);
//        CK_DDN(m_y2);
        
        return result;
    }
    
    // set_bpf
    inline void set_bpf( float freq, float Q )
    {
        float pfreq = freq * m_radians_per_sample;
        float pbw = 1.0 / Q * pfreq * .5;
        
        float C = 1.0 / ::tan(pbw);
        float D = 2.0 * ::cos(pfreq);
        float next_a0 = 1.0 / (1.0 + C);
        float next_b1 = C * D * next_a0 ;
        float next_b2 = (1.0 - C) * next_a0;
        
        m_freq = freq;
        m_Q = Q;
        m_a0 = (SAMPLE)next_a0;
        m_b1 = (SAMPLE)next_b1;
        m_b2 = (SAMPLE)next_b2;
    }
    
    // tick_bpf
    inline SAMPLE tick_bpf( SAMPLE in )
    {
        SAMPLE y0, result;
        
        // go: adapted from SC3's LPF
        y0 = in + m_b1 * m_y1 + m_b2 * m_y2;
        result = m_a0 * (y0 - m_y2);
        m_y2 = m_y1;
        m_y1 = y0;
        
        // be normal
//        CK_DDN(m_y1);
//        CK_DDN(m_y2);
        
        return result;
    }
    
    // set_brf
    inline void set_brf( float freq, float Q )
    {
        float pfreq = freq * m_radians_per_sample;
        float pbw = 1.0 / Q * pfreq * .5;
        
        float C = ::tan(pbw);
        float D = 2.0 * ::cos(pfreq);
        float next_a0 = 1.0 / (1.0 + C);
        float next_b1 = -D * next_a0 ;
        float next_b2 = (1.f - C) * next_a0;
        
        m_freq = freq;
        m_Q = Q;
        m_a0 = (SAMPLE)next_a0;
        m_b1 = (SAMPLE)next_b1;
        m_b2 = (SAMPLE)next_b2;
    }
    
    // tick_brf
    inline SAMPLE tick_brf( SAMPLE in )
    {
        SAMPLE y0, result;
        
        // go: adapted from SC3's HPF
        // b1 is actually a1
        y0 = in - m_b1 * m_y1 - m_b2 * m_y2;
        result = m_a0 * (y0 + m_y2) + m_b1 * m_y1;
        m_y2 = m_y1;
        m_y1 = y0;
        
        // be normal
//        CK_DDN(m_y1);
//        CK_DDN(m_y2);
        
        return result;
    }
    
    // set_rlpf
    inline void set_rlpf( float freq, float Q )
    {
        float qres = MAX( .001, 1.0/Q );
        float pfreq = freq * m_radians_per_sample;
        
        float D = ::tan(pfreq * qres * 0.5);
        float C = (1.0 - D) / (1.0 + D);
        float cosf = ::cos(pfreq);
        float next_b1 = (1.0 + C) * cosf;
        float next_b2 = -C;
        float next_a0 = (1.0 + C - next_b1) * 0.25;
        
        m_freq = freq;
        m_Q = 1.0 / qres;
        m_a0 = (SAMPLE)next_a0;
        m_b1 = (SAMPLE)next_b1;
        m_b2 = (SAMPLE)next_b2;
    }
    
    // tick_rlpf
    inline SAMPLE tick_rlpf( SAMPLE in )
    {
        SAMPLE y0, result;
        
        // go: adapated from SC3's RLPF
        y0 = m_a0 * in + m_b1 * m_y1 + m_b2 * m_y2;
        result = y0 + 2 * m_y1 + m_y2;
        m_y2 = m_y1;
        m_y1 = y0;
        
        // be normal
//        CK_DDN(m_y1);
//        CK_DDN(m_y2);
        
        return result;
    }
    
    // set_rhpf
    inline void set_rhpf( float freq, float Q )
    {
        float qres = MAX( .001, 1.0/Q );
        float pfreq = freq * m_radians_per_sample;
        
        float D = ::tan(pfreq * qres * 0.5);
        float C = (1.0 - D) / (1.0 + D);
        float cosf = ::cos(pfreq);
        float next_b1 = (1.0 + C) * cosf;
        float next_b2 = -C;
        float next_a0 = (1.0 + C + next_b1) * 0.25;
        
        m_freq = freq;
        m_Q = 1.0 / qres;
        m_a0 = (SAMPLE)next_a0;
        m_b1 = (SAMPLE)next_b1;
        m_b2 = (SAMPLE)next_b2;
    }
    
    // tick_rhpf
    inline SAMPLE tick_rhpf( SAMPLE in )
    {
        SAMPLE y0, result;
        
        // go: adapted from SC3's RHPF
        y0 = m_a0 * in + m_b1 * m_y1 + m_b2 * m_y2;
        result = y0 - 2 * m_y1 + m_y2;
        m_y2 = m_y1;
        m_y1 = y0;
        
        // be normal
//        CK_DDN(m_y1);
//        CK_DDN(m_y2);
        
        return result;
    }
    
    // set_resonz
    inline void set_resonz( float freq, float Q )
    {
        float pfreq = freq * m_radians_per_sample;
        float B = pfreq / Q;
        float R = 1.0 - B * 0.5;
        float R2 = 2.0 * R;
        float R22 = R * R;
        float cost = (R2 * ::cos(pfreq)) / (1.0 + R22);
        float next_b1 = R2 * cost;
        float next_b2 = -R22;
        float next_a0 = (1.0 - R22) * 0.5;
        
        m_freq = freq;
        m_Q = Q;
        m_a0 = (SAMPLE)next_a0;
        m_b1 = (SAMPLE)next_b1;
        m_b2 = (SAMPLE)next_b2;
    }
    
    // tick_resonz
    inline SAMPLE tick_resonz( SAMPLE in )
    {
        SAMPLE y0, result;
        
        // go: adapted from SC3's ResonZ
        y0 = in + m_b1 * m_y1 + m_b2 * m_y2;
        result = m_a0 * (y0 - m_y2);
        m_y2 = m_y1;
        m_y1 = y0;
        
        // be normal
//        CK_DDN(m_y1);
//        CK_DDN(m_y2);
        
        return result;
    }
    
};

