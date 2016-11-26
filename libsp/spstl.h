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
  itmap()
  Map a block to every item in a C++/STL iterable container
  (with shortcircuit)
 -----------------------------------------------------------------------------*/
template<class T>
void itmap(T &container, bool (^func)(typename T::reference v))
{
    for(typename T::iterator i = container.begin(); i != container.end(); i++)
    {
        if(!func(*i)) break;
    }
}

// const version
template<class T>
void itmap(const T &container, bool (^func)(typename T::const_reference v))
{
    for(typename T::const_iterator i = container.begin(); i != container.end(); i++)
    {
        if(!func(*i)) break;
    }
}

/*------------------------------------------------------------------------------
 itmap_safe()
 Map a block to every item in a C++/STL iterable container; safe to remove 
 objects in the block.
 (with shortcircuit)
 -----------------------------------------------------------------------------*/
template<class T>
void itmap_safe(T &container, bool (^func)(typename T::reference v))
{
    for(auto i = container.begin(); i != container.end(); )
    {
        auto j = i;
        i++;
        if(!func(*j)) break;
    }
}

template<class T>
void itmap_safe(T &container, void (^func)(typename T::reference v))
{
    for(auto i = container.begin(); i != container.end(); )
    {
        auto j = i;
        i++;
        func(*j);
    }
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

/*------------------------------------------------------------------------------
 removevalues()
 Remove all keys from a map with the specified value
 -----------------------------------------------------------------------------*/
template<class T>
void removevalues(T &map, const typename T::mapped_type &value)
{
    for(auto kv = map.begin(); kv != map.end(); )
    {
        auto kv2 = kv;
        kv++;
        if(kv2->second == value)
            map.erase(kv2);
    }
}

#endif
