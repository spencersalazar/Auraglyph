//
//  AGControlCounterNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/15/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGControlNode.h"

//------------------------------------------------------------------------------
// ### AGControlCounterNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlCounterNode

class AGControlCounterNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_INPUT,
        PARAM_UP,
        PARAM_DOWN,
        PARAM_OUTPUT,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlCounterNode>
    {
    public:
        string _type() const override { return "Counter"; };
        string _name() const override { return "Counter"; };
        string _description() const override { return "Count up a specified number of times and then down a specified number of times, then resets to zero."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "count", 0, -AGFloat_Max, AGFloat_Max, AGPortInfo::LIN, .doc = "Non-zero input triggers count." },
                { PARAM_UP, "up", 8, 0, AGInt_Max, AGPortInfo::LIN, .type = AGControl::TYPE_INT, .doc = "Number of times to count up." },
                { PARAM_DOWN, "down", 0, 0, AGInt_Max, AGPortInfo::LIN, .type = AGControl::TYPE_INT, .doc = "Number of times to count down." },
            };
        }
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_UP, "up", 8, 0, AGInt_Max, AGPortInfo::LIN, .type = AGControl::TYPE_INT, .doc = "Number of times to count up." },
                { PARAM_DOWN, "down", 0, 0, AGInt_Max, AGPortInfo::LIN, .type = AGControl::TYPE_INT, .doc = "Number of times to count down." },
            };
        }
        
        vector<AGPortInfo> _outputPortInfo() const override {
            return {
                { PARAM_OUTPUT, "output", .doc = "" },
            };
        }
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float r = 22; // radius
            
            return {
                // steps
                GLvertex2f(   -r, -r),
                GLvertex2f(   -r, -r/3),
                GLvertex2f( -r/3, -r/3),
                GLvertex2f( -r/3,  r/3),
                GLvertex2f(  r/3,  r/3),
                GLvertex2f(  r/3,  r),
                GLvertex2f(    r,  r),
            };
        }
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGControlNode::AGControlNode;
    
    virtual void initFinal() override
    {
        m_value = 0;
        m_counter = 0;
        m_direction = 1;
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void receiveControl(int port, const AGControl &control) override
    {
        if(port == m_param2InputPort[PARAM_UP])
            setParam(PARAM_UP, control);
        else if(port == m_param2InputPort[PARAM_DOWN])
            setParam(PARAM_DOWN, control);
        else if(port == m_param2InputPort[PARAM_INPUT])
        {
            int up = param(PARAM_UP);
            int down = param(PARAM_DOWN);
            
            if(control.getInt())
            {
                pushControl(0, AGControl(m_value));
                
                m_value += m_direction;
                ++m_counter;
                if(m_direction == 1 && m_counter >= up)
                {
                    if(down)
                        m_direction = -1;
                    else
                        m_value = 0;
                    m_counter = 0;
                }
                else if(m_direction == -1 && m_counter >= down)
                {
                    if(up)
                        m_direction = 1;
                    
                    m_value = 0;
                    m_counter = 0;
                }
            }
        }
    }
    
private:
    int m_value;
    int m_counter;
    int m_direction;
};

