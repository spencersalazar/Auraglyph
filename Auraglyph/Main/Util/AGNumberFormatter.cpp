//
//  AGNumberFormatter.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 7/11/20.
//  Copyright © 2020 Spencer Salazar. All rights reserved.
//

#include "AGNumberFormatter.h"

#include <math.h>

// enable/disable instrumentation + testing
#define AGNumberFormatter_INSTRUMENT 0

#if AGNumberFormatter_INSTRUMENT

static const std::string gFormatTest[] = {
    AGNumberFormatter().format(100.0),
    AGNumberFormatter().format(100000.0),
    AGNumberFormatter().format(1000000.0),
    AGNumberFormatter().format(20000000.0),
    AGNumberFormatter().format(0.1),
    AGNumberFormatter().format(0.0001),
    AGNumberFormatter().format(0.00009),
    AGNumberFormatter().format(0.000001),
    AGNumberFormatter().format(0.000009),
    AGNumberFormatter().format(0.11),
    AGNumberFormatter().format(0.012345),
};

#endif // AGNumberFormatter_INSTRUMENT

std::string AGNumberFormatter::format(long int val)
{
    snprintf(m_buf, BUF_SIZE-1, "%li", val);
    
    return std::string(m_buf);
}

std::string AGNumberFormatter::format(double val)
{
    const int MAX_DIGITS = 9; // max decimal digits before using a shortened format
    const int DEFAULT_PRECISION = 2; // default number of digits to show after a decimal point or first non-zero digit, if non-zero

    // count digits
    double absVal = fabs(val);
    int numDigits = 1;
    int factor = 1;
    
    if (absVal >= 1) {
        while (absVal/factor >= 10.f && numDigits <= MAX_DIGITS) {
            factor *= 10;
            numDigits += 1;
        }
    } else {
        while (absVal*factor < 1.f && numDigits <= MAX_DIGITS) {
            factor *= 10;
            numDigits += 1;
        }
    }
    
    bool clearTrailingZeros = false;
    if (numDigits > MAX_DIGITS) {
        // total represented digits over max
        snprintf(m_buf, BUF_SIZE-1, "%#.*G", DEFAULT_PRECISION+1, val);
    } else if (absVal < 1) {
        snprintf(m_buf, BUF_SIZE-1, "%.*f", numDigits-1+DEFAULT_PRECISION, val);
        clearTrailingZeros = true;
    } else {
        int precision = std::max(0, DEFAULT_PRECISION-numDigits+1);
        snprintf(m_buf, BUF_SIZE-1, "%.*f", precision, val);
        if (precision > 0) { clearTrailingZeros = true; }
    }
        
    if (clearTrailingZeros) {
        // clear trailing zeros/decimal point
        size_t i = strnlen(m_buf, BUF_SIZE)-1;
        while ((m_buf[i] == '0' || m_buf[i] == '.') && i > 0) {
            bool doBreak = (m_buf[i] == '.');
            m_buf[i] = '\0';
            i--;
            
            if (doBreak) { break; }
        }
    }
    
#if AGNumberFormatter_INSTRUMENT
    fprintf(stderr, "value: %g numDigits: %i str: %s\n", val, numDigits, m_buf);
#endif // AGNumberFormatter_INSTRUMENT
    
    return std::string(m_buf);
}

