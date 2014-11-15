//
//  spstl.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/13/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef Auragraph_spstl_h
#define Auragraph_spstl_h


/*------------------------------------------------------------------------------
  itmap()
  Map a block to every item in a C++/STL iterable container
 -----------------------------------------------------------------------------*/
template<class T>
void itmap(T &container, void (^func)(typename T::reference v))
{
    for(typename T::iterator i = container.begin(); i != container.end(); i++)
        func(*i);
}

/*------------------------------------------------------------------------------
 itfilter()
 Use a block to remove/filter elements from a C++/STL iterable container
 -----------------------------------------------------------------------------*/
template<class T>
void itfilter(T &container, bool (^func)(typename T::reference v))
{
    for(typename T::iterator i = container.begin(); i != container.end(); )
    {
        bool filt = func(*i);
        
        if(filt)
        {
            typename T::iterator d = i;
            i++;
            container.erase(d);
        }
        else
        {
            i++;
        }
    }
}

#endif
