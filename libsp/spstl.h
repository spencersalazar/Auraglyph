//
//  spstl.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/13/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef Auragraph_spstl_h
#define Auragraph_spstl_h

namespace libsp {
    
    template<class T>
    void map(T container, void (^func)(typename T::reference v))
    {
        for(typename T::iterator i = container.begin(); i != container.end(); i++)
            func(*i);
    }
    
}

#endif
