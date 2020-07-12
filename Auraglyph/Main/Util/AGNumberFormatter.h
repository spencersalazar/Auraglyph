//
//  AGNumberFormatter.h
//  Auraglyph
//
//  Created by Spencer Salazar on 7/11/20.
//  Copyright © 2020 Spencer Salazar. All rights reserved.
//

#pragma once

#include <string>


class AGNumberFormatter
{
public:
    
    std::string format(long int val);
    std::string format(double val);

private:
    
    constexpr const static size_t BUF_SIZE = 32;
    char m_buf[BUF_SIZE];
};
