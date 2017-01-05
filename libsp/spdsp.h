//
//  spdsp.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 9/9/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef spdsp_hpp
#define spdsp_hpp

#include <stdio.h>

#ifndef lin2dB
// if below -100dB, set to -100dB to prevent taking log of zero
#define lin2dB(x)               20.0 * ((x) > 0.00001 ? log10(x) : log10(0.00001))
#endif

#ifndef dB2lin
#define dB2lin(x)           pow( 10.0, (x) / 20.0 )
#endif

#include <cmath>

template<typename T>
inline T clipunit(T x) { return x-std::floor(x); }

#endif /* spdsp_hpp */
