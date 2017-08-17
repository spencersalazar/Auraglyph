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
            float radius = 38;
            float w = radius*1.3, h = w*0.2, t = h*0.75, rot = -M_PI*0.7f;
            
            return {
                // pen
                rotateZ(GLvertex2f( w/2,      0), rot),
                rotateZ(GLvertex2f( w/2-t,  h/2), rot),
                rotateZ(GLvertex2f(-w/2,    h/2), rot),
                rotateZ(GLvertex2f(-w/2,   -h/2), rot),
                rotateZ(GLvertex2f( w/2-t, -h/2), rot),
                rotateZ(GLvertex2f( w/2,      0), rot),
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
    
private:
    int m_value;
    int m_counter;
    int m_direction;
};

