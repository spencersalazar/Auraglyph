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
void itfilter(T &container, bool (^filt)(typename T::reference v))
{
    for(typename T::iterator i = container.begin(); i != container.end(); ) {
        if(filt(*i)) {
            typename T::iterator d = i;
            i++;
            container.erase(d);
        } else {
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

/** Insert object before another object, or at the front of the collection.
 */
template<class T>
void insert_before(T &container, typename T::const_reference value, typename T::const_reference before)
{
    typename T::iterator it_before = find(container.begin(), container.end(), before);
    if(it_before != container.end()) {
        container.insert(it_before, value);
    } else {
        container.push_front(value);
    }
}

/** Insert object after another object, or at the back of the collection.
 */
template<class T>
void insert_after(T &container, typename T::const_reference value, typename T::const_reference after)
{
    typename T::iterator it_after = find(container.begin(), container.end(), after);
    if(it_after != container.end()) {
        container.insert(++it_after, value);
    } else {
        container.push_back(value);
    }
}

/** Existence test for value in collection.
 */
template<class T>
bool contains(const T &collection, typename T::const_reference value)
{
    return find(collection.begin(), collection.end(), value) != collection.end();
}


#endif
