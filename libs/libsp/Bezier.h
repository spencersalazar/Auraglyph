//
//  Bezier.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 4/27/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include <vector>

namespace bezier
{
    template<typename T, typename P>
    P cubic(P p0, P p1, P p2, T t)
    {
        T _1_t = 1-t;
        return _1_t*_1_t*p0 + 2*_1_t*t*p1 + t*t*p2;
    }
    
    template<typename T, typename P>
    P cubic(std::vector<P> &p, T t)
    {
        return cubic(p[0], p[1], p[2], t);
    }
}

