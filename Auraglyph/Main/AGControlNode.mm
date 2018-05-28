//
//  AGControlNode.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGControlNode.h"
#include "AGGenericShader.h"
#include "AGNode.h"
#include "AGArrayNode.h"
#include "AGControlSequencerNode.h"
#include "AGTimer.h"
#include "spstl.h"
#include "AGStyle.h"
#include "AGControlOrientationNode.h"
#include "AGControlGestureNode.h"

// XXX new for MIDI input
#include "AGControlMidiNoteIn.h"
#include "AGControlMidiCCIn.h"

//------------------------------------------------------------------------------
// ### AGControlNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlNode

bool AGControlNode::s_init = false;
GLuint AGControlNode::s_vertexArray = 0;
GLuint AGControlNode::s_vertexBuffer = 0;
GLvncprimf *AGControlNode::s_geo = NULL;
GLuint AGControlNode::s_geoSize = 0;
float AGControlNode::s_radius = 0;

void AGControlNode::initializeControlNode()
{
    initalizeNode();
    
    if(!s_init)
    {
        s_init = true;
        
        // generate square
        s_geoSize = 4;
        s_geo = new GLvncprimf[s_geoSize];
        s_radius = AGNode::s_sizeFactor/(sqrt(sqrtf(2)));
        
        s_geo[0].vertex = GLvertex3f(s_radius, s_radius, 0);
        s_geo[1].vertex = GLvertex3f(s_radius, -s_radius, 0);
        s_geo[2].vertex = GLvertex3f(-s_radius, -s_radius, 0);
        s_geo[3].vertex = GLvertex3f(-s_radius, s_radius, 0);
        
        glGenVertexArraysOES(1, &s_vertexArray);
        glBindVertexArrayOES(s_vertexArray);
        
        glGenBuffers(1, &s_vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, s_vertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, s_geoSize*sizeof(GLvncprimf), s_geo, GL_STATIC_DRAW);
        
        glEnableVertexAttribArray(AGVertexAttribPosition);
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(0));
        glEnableVertexAttribArray(AGVertexAttribNormal);
        glVertexAttribPointer(AGVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(sizeof(GLvertex3f)));
        glEnableVertexAttribArray(AGVertexAttribColor);
        glVertexAttribPointer(AGVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(2*sizeof(GLvertex3f)));
        
        glBindVertexArrayOES(0);
    }
}

AGControlNode::AGControlNode(const AGNodeManifest *mf, const GLvertex3f &pos) :
AGNode(mf, pos)
{
    initializeControlNode();
}

AGControlNode::AGControlNode(const AGNodeManifest *mf, const AGDocument::Node &docNode) :
AGNode(mf, docNode)
{
    initializeControlNode();
}

GLvertex3f AGControlNode::relativePositionForInputPort(int port) const
{
    int numIn = numInputPorts();
    return GLvertex3f(-s_radius, s_portRadius*(numIn-1)-s_portRadius*2*port, 0);
}

GLvertex3f AGControlNode::relativePositionForOutputPort(int port) const
{
    int numOut = numOutputPorts();
    return GLvertex3f(s_radius, s_portRadius*(numOut-1)-s_portRadius*2*port, 0);
}

void AGControlNode::update(float t, float dt)
{
    AGNode::update(t, dt);
    
    GLKMatrix4 projection = projectionMatrix();
    GLKMatrix4 modelView = globalModelViewMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
    
    m_renderState.modelview = modelView;
    m_renderState.projection = projection;
}

void AGControlNode::render()
{
    glBindVertexArrayOES(s_vertexArray);
    
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setMVPMatrix(m_modelViewProjectionMatrix);
    shader.setNormalMatrix(m_normalMatrix);
    
    GLcolor4f color = AGStyle::foregroundColor();
    color.a = m_fadeOut;
    glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &color);
    glDisableVertexAttribArray(AGVertexAttribColor);
    
    if(m_activation)
    {
        float scale = 0.975;
        
        GLKMatrix4 projection = projectionMatrix();
        GLKMatrix4 modelView = globalModelViewMatrix();
        
        modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
        GLKMatrix4 modelViewInner = GLKMatrix4Scale(modelView, scale, scale, scale);
        GLKMatrix4 mvp = GLKMatrix4Multiply(projection, modelViewInner);
        shader.setMVPMatrix(mvp);
        
        glLineWidth(4.0f);
        glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
        
        GLKMatrix4 modelViewOuter = GLKMatrix4Scale(modelView, 1.0/scale, 1.0/scale, 1.0/scale);
        mvp = GLKMatrix4Multiply(projection, modelViewOuter);
        shader.setMVPMatrix(mvp);
        
        glLineWidth(4.0f);
        glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    }
    else
    {
        shader.setMVPMatrix(m_modelViewProjectionMatrix);
        shader.setNormalMatrix(m_normalMatrix);
        
        glLineWidth(4.0f);
        glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    }
    
    AGNode::render();
}

AGInteractiveObject *AGControlNode::hitTest(const GLvertex3f &t)
{
    if(pointInRectangle(t.xy(),
                        m_pos.xy() + GLvertex2f(-s_radius, -s_radius),
                        m_pos.xy() + GLvertex2f(s_radius, s_radius)))
        return this;
    
    return _hitTestConnections(t);
}


//------------------------------------------------------------------------------
// ### AGControlTimerNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlTimerNode

class AGControlTimerNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_OUTPUT,
        PARAM_INTERVAL,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlTimerNode>
    {
    public:
        string _type() const override { return "Timer"; };
        string _name() const override { return "Timer"; };
        string _description() const override { return "Emits pulses at the specified interval."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INTERVAL, "interval", .doc = "Timer fire interval (seconds)." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_INTERVAL, "interval", 0.5, 0.001, AGFloat_Max, .doc = "Timer fire interval (seconds)." },
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." },
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 0.005*AGStyle::oldGlobalScale;
            int circleSize = 48;
            int GEO_SIZE = circleSize*2 + 4;
            vector<GLvertex3f> iconGeo = vector<GLvertex3f>(GEO_SIZE);
            
            // TODO: multiple geoTypes (GL_LINE_LOOP + GL_LINE_STRIP) instead of wasteful GL_LINES
            
            for(int i = 0; i < circleSize; i++)
            {
                float theta0 = 2*M_PI*((float)i)/((float)(circleSize));
                float theta1 = 2*M_PI*((float)(i+1))/((float)(circleSize));
                iconGeo[i*2+0] = GLvertex3f(radius*cosf(theta0), radius*sinf(theta0), 0);
                iconGeo[i*2+1] = GLvertex3f(radius*cosf(theta1), radius*sinf(theta1), 0);
            }
            
            float minute = 47;
            float minuteAngle = M_PI/2.0 + (minute/60.0)*(-2.0*M_PI);
            float hour = 1;
            float hourAngle = M_PI/2.0 + (hour/12.0 + minute/60.0/12.0)*(-2.0*M_PI);
            
            iconGeo[circleSize*2+0] = GLvertex3f(0, 0, 0);
            iconGeo[circleSize*2+1] = GLvertex3f(radius/G_RATIO*cosf(hourAngle), radius/G_RATIO*sinf(hourAngle), 0);
            iconGeo[circleSize*2+2] = GLvertex3f(0, 0, 0);
            iconGeo[circleSize*2+3] = GLvertex3f(radius*0.925*cosf(minuteAngle), radius*0.925*sinf(minuteAngle), 0);
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGControlNode::AGControlNode;
    virtual ~AGControlTimerNode() { dbgprint_off("AGControlTimerNode::~AGControlTimerNode()\n"); }
    
    void editPortValueChanged(int paramId) override
    {
        if(paramId == PARAM_INTERVAL)
            m_timer.setInterval(param(PARAM_INTERVAL));
    }
    
    void initFinal() override
    {
        m_lastFire = 0;
        m_lastTime = 0;
        m_value = false;
        
        m_timer = AGTimer(param(PARAM_INTERVAL), ^(AGTimer *) {
            // flip
            m_value = !m_value;
            pushControl(0, AGControl(m_value));
        });
    }
    
    virtual int numOutputPorts() const override { return 1; }
    
private:
    AGTimer m_timer;
    
    bool m_value;
    float m_lastTime;
    float m_lastFire;
};


//------------------------------------------------------------------------------
// ### AGControlAddNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlAddNode

class AGControlAddNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_OUTPUT,
        PARAM_ADD,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlAddNode>
    {
    public:
        string _type() const override { return "Add"; };
        string _name() const override { return "Add"; };
        string _description() const override { return "Adds constant value to input."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_ADD, "add", .doc = "Input control value." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_ADD, "add", 0, .doc = "Quantity to add to input." },
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." },
            };
        };

        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            
            // add icon
            vector<GLvertex3f> iconGeo = {
                { -radius_x, 0, 0 }, { radius_x, 0, 0 },
                { 0, radius_y, 0 }, { 0, -radius_y, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGControlNode::AGControlNode;
    
    virtual void receiveControl(int port, const AGControl &control) override
    {
        AGControl c = control;
        float add = param(PARAM_ADD);
        switch(c.type)
        {
            case AGControl::TYPE_FLOAT:
                c = control;
                c.vfloat += add;
                break;
            case AGControl::TYPE_INT:
                c = control;
                c.vint += add;
                break;
            default:
                c = AGControl(control.getInt() + add);
        }
        
        dbgprint_off("%s: push %f\n", this->title().c_str(), c.getFloat());
        
        pushControl(0, c);
    }
    
    virtual int numOutputPorts() const override { return 1; }
};


//------------------------------------------------------------------------------
// ### AGControlMultiplyNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMultiplyNode

class AGControlMultiplyNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_OUTPUT,
        PARAM_MULTIPLY,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlMultiplyNode>
    {
    public:
        string _type() const override { return "Multiply"; };
        string _name() const override { return "Multiply"; };
        string _description() const override { return "Multiplies input by constant value."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_MULTIPLY, "mult", .doc = "Input control value." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_MULTIPLY, "mult", 0, .doc = "Quantity to multiply input by." },
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." },
            };
        };

        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            
            // x icon
            vector<GLvertex3f> iconGeo = {
                { -radius_x, radius_y, 0 }, { radius_x, -radius_y, 0 },
                { -radius_x, -radius_y, 0 }, { radius_x, radius_y, 0 },
            };
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGControlNode::AGControlNode;
    
    void receiveControl(int port, const AGControl &control) override
    {
        AGControl c = control;
        float mult = param(PARAM_MULTIPLY);
        switch(c.type)
        {
            case AGControl::TYPE_FLOAT:
                c = control;
                c.vfloat *= mult;
                break;
            case AGControl::TYPE_INT:
                c = control;
                c.vint *= mult;
                break;
            default:
                c = AGControl(control.getInt() * mult);
        }
        
        dbgprint_off("%s: push %f\n", this->title().c_str(), c.getFloat());
        
        pushControl(0, c);
    }
    
    virtual int numOutputPorts() const override { return 1; }
};

//------------------------------------------------------------------------------
// ### AGControlMidiToFreqNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMidiToFreqNode

class AGControlMidiToFreqNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_OUTPUT,
        PARAM_MIDI,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlMidiToFreqNode>
    {
    public:
        string _type() const override { return "midi2freq"; };
        string _name() const override { return "midi2freq"; };
        string _description() const override { return "Converts MIDI pitch input to frequency value."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_MIDI, "midi", .doc = "MIDI note input control value." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override { return { }; };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." },
            };
        };

        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 0.005*AGStyle::oldGlobalScale;
            
            return {
                { -radius, 0, 0 }, {  radius, 0, 0 },
                {  radius*0.38f,  radius*0.38f, 0 }, { radius, 0, 0 },
                {  radius*0.38f, -radius*0.38f, 0 }, { radius, 0, 0 },
            };
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGControlNode::AGControlNode;
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void receiveControl(int port, const AGControl &control) override
    {
        float m = control.getFloat();
        AGControl freqControl = powf(2.0f, (m-69.0f)/12.0f)*440.0f;
        pushControl(0, freqControl);
    }
    
private:
};

//------------------------------------------------------------------------------
// ### AGControlSlewNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlSlewNode

class AGControlSlewNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_OUTPUT,
        PARAM_INPUT,
        PARAM_RATE,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlSlewNode>
    {
    public:
        string _type() const override { return "slew"; };
        string _name() const override { return "slew"; };
        string _description() const override { return "Slew between values at a specified rate."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input value." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_RATE, "rate", 0.15, 0, 2, AGPortInfo::LOG, AGControl::TYPE_FLOAT, .doc = "Slew rate." },
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." },
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            int NUM_SAMPS = 25;
            
            slewf iconSlew;
            iconSlew.rate = 0.6;
            
            vector<GLvertex3f> iconGeo;
            
            for (int i = 0; i < NUM_SAMPS; i++)
            {
                GLvertex3f vert;
                
                vert.x = ((float)i/(NUM_SAMPS-1))*2*radius_x - radius_x;
                vert.y = iconSlew * radius_y;

                if(i == 0)
                    iconSlew = 1;
                else if(i == 5)
                    iconSlew = -1;
                else if(i == 13)
                    iconSlew = 0.7;
                else if(i == 19)
                    iconSlew = -0.5;
                
                iconSlew.interp();
                iconGeo.push_back(vert);
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGControlNode::AGControlNode;
    
    virtual int numOutputPorts() const override { return 1; }
    
    void initFinal() override
    {
        float interval = 0.01;
        
        m_timer = AGTimer(interval, ^(AGTimer *) {
            m_slew.interp();
            pushControl(0, AGControl(m_slew));
        });
    }

    void editPortValueChanged(int paramId) override
    {
        if(paramId == PARAM_RATE) {
            m_slew.rate = param(PARAM_RATE);
        }
    }

    virtual void receiveControl(int port, const AGControl &control) override
    {
        float t = control.getFloat();
        m_slew = t;
    }
    
private:
    AGTimer m_timer;
    slewf m_slew;
};

//------------------------------------------------------------------------------
// ### AGControlRandomNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlRandomNode

class AGControlRandomNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_OUTPUT,
        PARAM_INPUT,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlRandomNode>
    {
    public:
        string _type() const override { return "random"; };
        string _name() const override { return "random"; };
        string _description() const override { return "Generates uniformly distributed random numbers in the range 0.0-1.0."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_INPUT, "input", .doc = "Input value." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override { return { }; };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." },
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius_x = 0.005*AGStyle::oldGlobalScale;
            float radius_y = radius_x;
            int NUM_SAMPS = 15;
            
            vector<GLvertex3f> iconGeo;
            
            for (int i = 0; i < NUM_SAMPS; i++)
            {
                GLvertex3f vert;
                
                vert.x = ((float)i/(NUM_SAMPS-1))*2*radius_x - radius_x;
                vert.y = (arc4random()*ONE_OVER_RAND_MAX - 0.5)*2*radius_y;
                
                iconGeo.push_back(vert);
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGControlNode::AGControlNode;
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void receiveControl(int port, const AGControl &control) override
    {
        float out = arc4random()*ONE_OVER_RAND_MAX;
        pushControl(0, AGControl(out));
    }
    
private:
    constexpr static const float ONE_OVER_RAND_MAX = 1.0/4294967295.0;
};

//------------------------------------------------------------------------------
// ### AGControlComparisonEQNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlComparisonEQNode

class AGControlComparisonEQNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_IN_HOT,
        PARAM_IN_COLD,
        PARAM_OUTPUT,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlComparisonEQNode>
    {
    public:
        string _type() const override { return "equals"; };
        string _name() const override { return "equals"; };
        string _description() const override { return "Tests equality of two values."; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_IN_HOT, "hot in", true, false, .type = AGControl::TYPE_INT,
                    .doc = "Hot inlet." },
                { PARAM_IN_COLD, "cold in", true, true, .type = AGControl::TYPE_INT,
                    .mode = AGPortInfo::LIN, .doc = "Cold inlet." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_IN_COLD, "cold in", true, true, .type = AGControl::TYPE_INT,
                    .mode = AGPortInfo::LIN,.doc = "Cold inlet." },
            };
        };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", true, false, .type = AGControl::TYPE_INT,
                    .doc = "Output." },
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 0.005*AGStyle::oldGlobalScale;
            
            return {
                { -radius*0.9f,  radius*0.2f, 0 }, { -radius*0.2f,  radius*0.2f, 0 },
                {  radius*0.9f,  radius*0.2f, 0 }, {  radius*0.2f,  radius*0.2f, 0 },
                { -radius*0.9f, -radius*0.2f, 0 }, { -radius*0.2f, -radius*0.2f, 0 },
                {  radius*0.9f, -radius*0.2f, 0 }, {  radius*0.2f, -radius*0.2f, 0 },
            };
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGControlNode::AGControlNode;
    
    virtual int numOutputPorts() const override { return 1; }
    
    void editPortValueChanged(int paramId) override
    {
        if(paramId == PARAM_IN_COLD) {
            testVal = param(PARAM_IN_COLD);
        }
    }
    
    virtual void receiveControl(int port, const AGControl &control) override
    {
        if(port == 0)
        {
            int val = control.getInt();
            pushControl(0, AGControl(val == testVal));
        }
        else if(port == 1)
        {
            testVal = control.getInt();
            setEditPortValue(0, AGParamValue(testVal));            
        }
    }
    
private:
    int testVal = 0;
};

//------------------------------------------------------------------------------
// ### AGControlGateNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlGateNode

class AGControlGateNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_IN_GATE,
        PARAM_IN_VAL,
        PARAM_OUTPUT,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlGateNode>
    {
    public:
        string _type() const override { return "gate"; };
        string _name() const override { return "gate"; };
        string _description() const override { return "First inlet gates signal present at second inlet"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_IN_GATE, "gate in", true, false, .type = AGControl::TYPE_INT,
                    .doc = "Gate signal inlet." },
                { PARAM_IN_VAL, "value in", true, true, .doc = "Value signal inlet." },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override { return { }; };
        
        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", true, false, .doc = "Output." },
            };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {            
            float radius = 0.006*AGStyle::oldGlobalScale;
            float radius_x = radius;
            //float radius_y = radius_x;
            float radius_circ = radius_x * 0.4;
            int circleSize = 16;
            int GEO_SIZE = circleSize*2;
            vector<GLvertex3f> iconGeo = vector<GLvertex3f>(GEO_SIZE);
            
            for(int i = 0; i < circleSize; i++)
            {
                float theta0 = 2*M_PI*((float)i)/((float)(circleSize));
                float theta1 = 2*M_PI*((float)(i+1))/((float)(circleSize));
                iconGeo[i*2+0] = GLvertex3f(radius_circ*cosf(theta0), radius_circ*sinf(theta0), 0);
                iconGeo[i*2+1] = GLvertex3f(radius_circ*cosf(theta1), radius_circ*sinf(theta1), 0);
            }
            
            vector<GLvertex3f> lines = {
                rotateZ(GLvertex3f(-radius_circ, 0, 0), -M_PI_4),
                rotateZ(GLvertex3f( radius_circ, 0, 0), -M_PI_4),
                rotateZ(GLvertex3f(-radius_circ, 0, 0),  M_PI_4),
                rotateZ(GLvertex3f( radius_circ, 0, 0),  M_PI_4),
                { -radius*0.9f,  radius*0.2f, 0 }, { -radius*0.2f,  radius*0.2f, 0 },
                {  radius*0.9f,  radius*0.2f, 0 }, {  radius*0.2f,  radius*0.2f, 0 },
                { -radius*0.9f, -radius*0.2f, 0 }, { -radius*0.2f, -radius*0.2f, 0 },
                {  radius*0.9f, -radius*0.2f, 0 }, {  radius*0.2f, -radius*0.2f, 0 },
            };
            
            for(int i = 0; i < lines.size(); i++)
            {
                GLvertex3f vert = lines[i];
                iconGeo.push_back(vert);
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGControlNode::AGControlNode;
    
    virtual int numOutputPorts() const override { return 1; }
    
    virtual void receiveControl(int port, const AGControl &control) override
    {
        if(port == 0)
        {
            int val = control.getInt();
            
            if(val)
                isOpen = true;
            else
                isOpen = false;
        }
        else if(port == 1)
        {
            if(isOpen)
                pushControl(0, control);
        }
    }
    
private:
    bool isOpen = false;
};


#include "Nodes/Control/AGControlMapNode.cpp"
#include "Nodes/Control/AGControlScaleNode.cpp"
#include "Nodes/Control/AGControlCounterNode.cpp"


//------------------------------------------------------------------------------
// ### AGNodeManager ###
//------------------------------------------------------------------------------
#pragma mark - AGNodeManager

const AGNodeManager &AGNodeManager::controlNodeManager()
{
    if(s_controlNodeManager == NULL)
    {
        s_controlNodeManager = new AGNodeManager();

        vector<const AGNodeManifest *> &nodeTypes = s_controlNodeManager->m_nodeTypes;
        
        nodeTypes.push_back(new AGControlTimerNode::Manifest);
        nodeTypes.push_back(new AGControlArrayNode::Manifest);
        nodeTypes.push_back(new AGControlSequencerNode::Manifest);
        nodeTypes.push_back(new AGControlMidiToFreqNode::Manifest);
        
        nodeTypes.push_back(new AGControlAddNode::Manifest);
        nodeTypes.push_back(new AGControlMultiplyNode::Manifest);

        nodeTypes.push_back(new AGControlOrientationNode::Manifest);
        nodeTypes.push_back(new AGControlGestureNode::Manifest);
        
        nodeTypes.push_back(new AGControlSlewNode::Manifest);
        nodeTypes.push_back(new AGControlRandomNode::Manifest);
        
        nodeTypes.push_back(new AGControlMidiNoteIn::Manifest);
        nodeTypes.push_back(new AGControlMidiCCIn::Manifest);
        nodeTypes.push_back(new AGControlComparisonEQNode::Manifest);
        nodeTypes.push_back(new AGControlGateNode::Manifest);
        
        nodeTypes.push_back(new AGControlMapNode::Manifest);
        nodeTypes.push_back(new AGControlScaleNode::Manifest);
        
        nodeTypes.push_back(new AGControlCounterNode::Manifest);
        
        for(const AGNodeManifest *const &mf : nodeTypes)
            mf->initialize();
    }
    
    return *s_controlNodeManager;
}


