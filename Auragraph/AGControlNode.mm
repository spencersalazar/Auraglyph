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
#include "AGTimer.h"
#include "spstl.h"
#include "AGStyle.h"


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
        
        // generate circle
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
        
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(0));
        glEnableVertexAttribArray(GLKVertexAttribNormal);
        glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(sizeof(GLvertex3f)));
        glEnableVertexAttribArray(GLKVertexAttribColor);
        glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(2*sizeof(GLvertex3f)));
        
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

void AGControlNode::update(float t, float dt)
{
    AGNode::update(t, dt);
    
    GLKMatrix4 projection = projectionMatrix();
    GLKMatrix4 modelView = globalModelViewMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
}

void AGControlNode::render()
{
    glBindVertexArrayOES(s_vertexArray);
    
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setMVPMatrix(m_modelViewProjectionMatrix);
    shader.setNormalMatrix(m_normalMatrix);
    
    GLcolor4f color = GLcolor4f::white;
    color.a = m_fadeOut;
    glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &color);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    
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

AGUIObject *AGControlNode::hitTest(const GLvertex3f &t)
{
    if(pointInRectangle(t.xy(),
                        m_pos.xy() + GLvertex2f(-s_radius, -s_radius),
                        m_pos.xy() + GLvertex2f(s_radius, s_radius)))
        return this;
    return NULL;
}


AGDocument::Node AGControlNode::serialize()
{
    assert(type().length());
    
    AGDocument::Node n;
    n._class = AGDocument::Node::CONTROL;
    n.type = type();
    n.uuid = uuid();
    n.x = position().x;
    n.y = position().y;
    n.z = position().z;
    
    for(int i = 0; i < numEditPorts(); i++)
    {
        float v;
        getEditPortValue(i, v);
        n.params[editPortInfo(i).name] = AGDocument::ParamValue(v);
    }
    
    return n;
}


//------------------------------------------------------------------------------
// ### AGControlTimerNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlTimerNode

class AGControlTimerNode : public AGControlNode
{
public:
    class Manifest : public AGStandardNodeManifest<AGControlTimerNode>
    {
    public:
        string _type() const override { return "Timer"; };
        string _name() const override { return "Timer"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { "interval", true, true },
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { "interval", true, true },
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
    
    void setDefaultPortValues() override
    {
        m_interval = 0.5;
        m_lastFire = 0;
        m_lastTime = 0;
        m_control.v = 0;
        
        m_timer = AGTimer(m_interval, ^(AGTimer *) {
            // flip
            m_control.v = !m_control.v;
            pushControl(0, &m_control);
        });
    }
    
    virtual int numOutputPorts() const override { return 1; }
    virtual void setEditPortValue(int port, float value) override;
    virtual void getEditPortValue(int port, float &value) const override;
    
private:
    AGTimer m_timer;
    
    AGIntControl m_control;
    float m_lastTime;
    float m_lastFire;
    float m_interval;
};

void AGControlTimerNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_interval = value; m_timer.setInterval(m_interval); break;
    }
}

void AGControlTimerNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_interval; break;
    }
}


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
        
        for(const AGNodeManifest *const &mf : nodeTypes)
            mf->initialize();
    }
    
    return *s_controlNodeManager;
}


