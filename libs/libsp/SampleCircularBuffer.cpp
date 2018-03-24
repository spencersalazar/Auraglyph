//
//  CircularBuffer.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 6/21/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "SampleCircularBuffer.h"

#include <algorithm> // min
#include <assert.h>

SampleCircularBuffer::SampleCircularBuffer() { }

SampleCircularBuffer::~SampleCircularBuffer()
{
    cleanup();
}

void SampleCircularBuffer::initialize(int size)
{
    SAFE_DELETE_ARRAY(m_data);
    m_size = size;
    m_data = new float[size];
}

void SampleCircularBuffer::cleanup()
{
    SAFE_DELETE_ARRAY(m_data);
    m_size = 0;
}

int SampleCircularBuffer::get(float *data, int max)
{
    int elems_before_end;
    int elems_after_end;
    
    if(m_write < m_read)
    {
        elems_before_end = m_size - m_read;
        elems_after_end = m_write;
    }
    else
    {
        elems_before_end = m_write - m_read;
        elems_after_end = 0;
    }
    
    if(elems_before_end > max)
    {
        elems_before_end = max;
        elems_after_end = 0;
    }
    else if(elems_before_end + elems_after_end > max)
    {
        elems_after_end = max - elems_before_end;
    }
    
    if(elems_before_end)
        memcpy(data, m_data + m_read, elems_before_end*sizeof(float));
    
    if(elems_after_end)
        memcpy(data + elems_before_end, m_data, elems_after_end*sizeof(float));
    
    if(elems_after_end)
        m_read = elems_after_end;
    else
        m_read += elems_before_end;
    
    return elems_before_end + elems_after_end;
}

int SampleCircularBuffer::put(float *data, int num)
{
    if(m_write+num >= m_read && m_write+num < m_write)
    {
        // overflow
        return 0;
    }
    
    int elems_before_end = std::min(num, m_size - m_write);
    int elems_after_end = num - elems_before_end;
    
    if(elems_before_end)
        memcpy(m_data + m_write, data, elems_before_end*sizeof(float));
    
    if(elems_after_end)
        memcpy(m_data, data+elems_before_end, elems_after_end*sizeof(float));
    
    if(elems_after_end)
        m_write = elems_after_end;
    else
        m_write += elems_before_end;
    
    return elems_before_end + elems_after_end;
}

void SampleCircularBuffer::test()
{
    SampleCircularBuffer buffer;
    buffer.initialize(1024);
    
    int testSize = 1000;
    int numTests = 100;
    
    float input[testSize];
    float output[testSize];
    
    for(int i = 0; i < testSize; i++)
        input[i] = i;
    
    for(int n = 0; n < numTests; n++)
    {
        buffer.put(input, testSize);
        buffer.get(output, testSize);
        for(int i = 0; i < testSize; i++)
            assert(input[i] == output[i]);
    }
    
    for(int n = 0; n < numTests; n++)
    {
        buffer.put(input, testSize);
        buffer.put(input, testSize);
        
        buffer.get(output, testSize);
        for(int i = 0; i < testSize; i++)
            assert(input[i] == output[i]);
        
        buffer.get(output, testSize);
        for(int i = 0; i < testSize; i++)
            assert(input[i] == output[i]);
    }
}
