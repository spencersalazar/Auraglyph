//
//  CircularBuffer.h
//  Auragraph
//
//  Created by Spencer Salazar on 6/21/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

//------------------------------------------------------------------------------
// ### SampleCircularBuffer ###
// Circular buffer for float samples
//------------------------------------------------------------------------------
#pragma mark - SampleCircularBuffer

class SampleCircularBuffer
{
public:
    SampleCircularBuffer();
    ~SampleCircularBuffer();
    
    void initialize(int num_elem);
    void cleanup();
    
    int get( float *data, int max );
    int put( float *data, int num );
    inline bool hasMore() { return (m_read != m_write); }
    inline void clear() { m_read = m_write = 0; }
    
    static void test();
    
protected:
    float *m_data = NULL;
    int m_read = 0;
    int m_write = 0;
    int m_size = 0;
};
