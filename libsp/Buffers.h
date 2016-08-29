//
//  Buffers.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/26/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef Buffers_h
#define Buffers_h

#include <stddef.h>

template<typename T>
struct Buffer
{
public:
    Buffer() :
    size(0),
    buffer(NULL)
    {
    }
    
    Buffer(size_t _size) :
    size(_size)
    {
        buffer = new T[size];
    }
    
    ~Buffer()
    {
        if(buffer != NULL)
        {
            delete[] buffer;
            buffer = NULL;
        }
    }
    
    void resize(size_t _size)
    {
        if(size != _size)
        {
            size = _size;
            if(buffer != NULL)
                delete[] buffer;
            buffer = new T[size];
        }
    }
    
    void clear()
    {
        memset(buffer, 0, sizeof(T)*size);
    }
    
    operator T*()
    {
        return buffer;
    }
    
    operator const T*() const
    {
        return buffer;
    }
    
    const T operator[](int i) const
    {
        return buffer[i];
    }
    
    T &operator[](int i)
    {
        return buffer[i];
    }
    
    size_t size;
    T *buffer;
};


#endif /* Buffers_hpp */
