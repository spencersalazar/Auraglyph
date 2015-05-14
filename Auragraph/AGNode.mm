//
//  AGNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/12/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#include "AGNode.h"

#import "AGViewController.h"
#import "AGGenericShader.h"
#import "AGAudioNode.h"
#import "AGControlNode.h"
#include "sputil.h"

#import "spstl.h"



bool AGControlNode::s_init = false;
GLuint AGControlNode::s_vertexArray = 0;
GLuint AGControlNode::s_vertexBuffer = 0;
GLvncprimf *AGControlNode::s_geo = NULL;
GLuint AGControlNode::s_geoSize = 0;
float AGControlNode::s_radius = 0;


bool AGInputNode::s_init = false;
GLuint AGInputNode::s_vertexArray = 0;
GLuint AGInputNode::s_vertexBuffer = 0;
GLvncprimf *AGInputNode::s_geo = NULL;
GLuint AGInputNode::s_geoSize = 0;
float AGInputNode::s_radius = 0;


bool AGOutputNode::s_init = false;
GLuint AGOutputNode::s_vertexArray = 0;
GLuint AGOutputNode::s_vertexBuffer = 0;
GLvncprimf *AGOutputNode::s_geo = NULL;
GLuint AGOutputNode::s_geoSize = 0;
float AGOutputNode::s_radius = 0;


//------------------------------------------------------------------------------
// ### AGNode ###
//------------------------------------------------------------------------------
#pragma mark - AGNode

bool AGNode::s_initNode = false;
const float AGNode::s_sizeFactor = 0.01;

float AGNode::s_portRadius = 0.01*0.2;
GLvertex3f *AGNode::s_portGeo = NULL;
GLuint AGNode::s_portGeoSize = 0;
GLint AGNode::s_portGeoType = 0;

void AGNode::connect(AGConnection * connection)
{
    connection->src()->lock();
    connection->src()->addOutbound(connection);
    connection->src()->unlock();
    
    connection->dst()->lock();
    connection->dst()->addInbound(connection);
    connection->dst()->unlock();
}

void AGNode::disconnect(AGConnection * connection)
{
    connection->src()->lock();
    connection->src()->removeOutbound(connection);
    connection->src()->unlock();
    
    connection->dst()->lock();
    connection->dst()->removeInbound(connection);
    connection->dst()->unlock();
}

void AGNode::initalizeNode()
{
    if(!s_initNode)
    {
        s_initNode = true;
        
        // generate circle
        s_portGeoSize = 32;
        s_portGeoType = GL_LINE_LOOP;
        s_portGeo = new GLvertex3f[s_portGeoSize];
        for(int i = 0; i < s_portGeoSize; i++)
        {
            float theta = 2*M_PI*((float)i)/((float)(s_portGeoSize));
            s_portGeo[i] = GLvertex3f(s_portRadius*cosf(theta), s_portRadius*sinf(theta), 0);
        }
    }
}


AGNode::AGNode(GLvertex3f pos, AGNodeInfo *nodeInfo) :
m_pos(pos),
m_nodeInfo(nodeInfo),
m_active(true),
m_fadeOut(1, 0, 0.5, 2),
m_uuid(makeUUID())
{
    m_inputActivation = m_outputActivation = 0;
    m_activation = 0;
    
    if(numInputPorts() > 0)
    {
        m_controlPortBuffer = new AGControl *[numInputPorts()];
        for(int i = 0; i < numInputPorts(); i++)
            m_controlPortBuffer[i] = NULL;
    }
    else
    {
        m_controlPortBuffer = NULL;
    }
}

AGNode::AGNode(const AGDocument::Node &docNode, AGNodeInfo *nodeInfo) :
m_pos(GLvertex3f(docNode.x, docNode.y, docNode.z)),
m_nodeInfo(nodeInfo),
m_active(true),
m_fadeOut(1, 0, 0.5, 2),
m_uuid(docNode.uuid)
{
    m_inputActivation = m_outputActivation = 0;
    m_activation = 0;
    
    if(numInputPorts() > 0)
    {
        m_controlPortBuffer = new AGControl *[numInputPorts()];
        for(int i = 0; i < numInputPorts(); i++)
            m_controlPortBuffer[i] = NULL;
    }
    else
    {
        m_controlPortBuffer = NULL;
    }
    
    for(int i = 0; i < numEditPorts(); i++)
    {
        const string &name = editPortInfo(i).name;
        if(docNode.params.count(name))
        {
            AGDocument::ParamValue pv = docNode.params.find(name)->second;
            float v = pv.f;
            setEditPortValue(i, v);
        }
    }
}

AGNode::~AGNode()
{
}

void AGNode::fadeOutAndRemove()
{
    m_active = false;
    m_fadeOut.reset();
    
    // this part is kinda hairy
    // this should remove the connections from the visuals
    // which then deletes them
    // which then breaks the connections between this node and any other node
    // so we shouldnt need to delete connections or break them here
    
    // work on copy of lists
    std::list<AGConnection *> _inbound = m_inbound;
    std::list<AGConnection *> _outbound = m_outbound;
    for(std::list<AGConnection *>::iterator i = _inbound.begin(); i != _inbound.end(); i++)
        (*i)->fadeOutAndRemove();
    for(std::list<AGConnection *>::iterator i = _outbound.begin(); i != _outbound.end(); i++)
        (*i)->fadeOutAndRemove();
}

void AGNode::renderOut()
{
    this->fadeOutAndRemove();
}

void AGNode::addInbound(AGConnection *connection)
{
    m_inbound.push_back(connection);
}

void AGNode::addOutbound(AGConnection *connection)
{
    m_outbound.push_back(connection);
}

void AGNode::removeInbound(AGConnection *connection)
{
    m_inbound.remove(connection);
}

void AGNode::removeOutbound(AGConnection *connection)
{
    m_outbound.remove(connection);
}

void AGNode::update(float t, float dt)
{
    if(!m_active)
    {
        m_fadeOut.update(dt);
        if(m_fadeOut < 0.01)
            [[AGViewController instance] removeNode:this];
    }
}

void AGNode::render()
{
    glBindVertexArrayOES(0);
    
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setMVPMatrix(m_modelViewProjectionMatrix);
    shader.setNormalMatrix(m_normalMatrix);
    
    int numOut = numOutputPorts();
    if(numOut)
    {
        // draw output port
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_portGeo);
        
        GLvertex3f portPos = relativePositionForOutputPort(0);
        GLKMatrix4 mvpOutputPort = GLKMatrix4Translate(m_modelViewProjectionMatrix, portPos.x, portPos.y, portPos.z);
        shader.setMVPMatrix(mvpOutputPort);
        
        GLcolor4f color;
        if(m_outputActivation == 1)       color = GLcolor4f(0, 1, 0, 1);
        else if(m_outputActivation == -1) color = GLcolor4f(1, 0, 0, 1);
        else                              color = GLcolor4f(1, 1, 1, 1);
        color.a = m_fadeOut;
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
        
        glLineWidth(2.0f);
        glDrawArrays(s_portGeoType, 0, s_portGeoSize);
    }
    
    int numIn = numInputPorts();
    for(int i = 0; i < numIn; i++)
    {
        // draw input port
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_portGeo);
        
        GLvertex3f portPos = relativePositionForInputPort(i);
        GLKMatrix4 mvpInputPort = GLKMatrix4Translate(m_modelViewProjectionMatrix, portPos.x, portPos.y, portPos.z);
        shader.setMVPMatrix(mvpInputPort);
        
        GLcolor4f color;
        if(m_inputActivation == 1+i)       color = GLcolor4f(0, 1, 0, 1);
        else if(m_inputActivation == -1-i) color = GLcolor4f(1, 0, 0, 1);
        else                               color = GLcolor4f(1, 1, 1, 1);
        color.a = m_fadeOut;
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
        
        glLineWidth(2.0f);
        glDrawArrays(s_portGeoType, 0, s_portGeoSize);
    }

    if(m_nodeInfo)
    {
        shader.setMVPMatrix(m_modelViewProjectionMatrix);
        shader.setNormalMatrix(m_normalMatrix);
        
        glBindVertexArrayOES(0);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_nodeInfo->iconGeo);
        
        GLcolor4f color = GLcolor4f::white;
        color.a = m_fadeOut;
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
        glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
        
        glLineWidth(2.0f);
        glDrawArrays(m_nodeInfo->iconGeoType, 0, m_nodeInfo->iconGeoSize);
    }
}

AGNode::HitTestResult AGNode::hit(const GLvertex3f &hit, int *port)
{
    if(!m_active)
        return HIT_NONE;
    
    int numIn = numInputPorts();
    for(int i = 0; i < numIn; i++)
    {
        GLvertex3f portPos = relativePositionForInputPort(i);
        if(pointInCircle(hit.xy(), (m_pos+portPos).xy(), s_portRadius))
        {
            if(port) *port = i;
            return HIT_INPUT_NODE;
        }
    }
    
    int numOut = numOutputPorts();
    for(int i = 0; i < numOut; i++)
    {
        GLvertex3f portPos = relativePositionForOutputPort(i);
        if(pointInCircle(hit.xy(), (m_pos+portPos).xy(), s_portRadius))
        {
            if(port) *port = i;
            return HIT_OUTPUT_NODE;
        }
    }
    
    // check whole node
    if(hitTest(hit) == this)
        return HIT_MAIN_NODE;
    
    return HIT_NONE;
}

void AGNode::unhit()
{
    
}

void AGNode::touchDown(const GLvertex3f &t)
{
    m_lastTouch = t;
}

void AGNode::touchMove(const GLvertex3f &t)
{
    m_pos = m_pos + (t - m_lastTouch);
    m_lastTouch = t;
    
    AGUITrash &trash = AGUITrash::instance();
    if(trash.hitTest(t))
        trash.activate();
    else
        trash.deactivate();
}

void AGNode::touchUp(const GLvertex3f &t)
{
    AGUITrash &trash = AGUITrash::instance();
    
    if(trash.hitTest(t))
    {
        m_active = false;
        m_fadeOut.reset();
    }
    
    trash.deactivate();
}

void AGNode::pushControl(int port, AGControl *control)
{
    this->lock();
    
    itmap(m_outbound, ^(AGConnection *&conn) {
        if(conn->rate() == RATE_CONTROL)
        {
            conn->dst()->receiveControl_internal(conn->dstPort(), control);
            conn->controlActivate();
        }
    });
    
    this->unlock();
}

void AGNode::receiveControl_internal(int port, AGControl *control)
{
    m_controlPortBuffer[port] = control;
    receiveControl(port, control);
}


//------------------------------------------------------------------------------
// ### AGAudioNode ###
//------------------------------------------------------------------------------
#pragma mark - AGAudioNode

bool AGAudioNode::s_init = false;
GLuint AGAudioNode::s_vertexArray = 0;
GLuint AGAudioNode::s_vertexBuffer = 0;
GLuint AGAudioNode::s_geoSize = 0;
int AGAudioNode::s_sampleRate = 44100;

void AGAudioNode::initializeAudioNode()
{
    initalizeNode();
    
    if(!s_init)
    {
        s_init = true;
        
        // generate circle
        s_geoSize = 64;
        GLvertex3f *geo = new GLvertex3f[s_geoSize];
        float radius = 0.01;
        for(int i = 0; i < s_geoSize; i++)
        {
            float theta = 2*M_PI*((float)i)/((float)(s_geoSize));
            geo[i] = GLvertex3f(radius*cosf(theta), radius*sinf(theta), 0);
        }
        
        genVertexArrayAndBuffer(s_geoSize, geo, s_vertexArray, s_vertexBuffer);
        
        delete[] geo;
        geo = NULL;        
    }
}


AGAudioNode::AGAudioNode(GLvertex3f pos, AGNodeInfo *nodeInfo) :
AGNode(pos, nodeInfo)
{
    initializeAudioNode();
    
    m_gain = 1;
    
    m_radius = 0.01;
    m_portRadius = 0.01 * 0.2;
    
    m_lastTime = -1;
    m_outputBuffer = new float[bufferSize()];
    memset(m_outputBuffer, 0, sizeof(float)*bufferSize());
    m_inputPortBuffer = NULL;
}

AGAudioNode::AGAudioNode(const AGDocument::Node &docNode, AGNodeInfo *nodeInfo) :
AGNode(docNode, nodeInfo)
{
    initializeAudioNode();
    
    m_gain = 1;
    
    m_radius = 0.01;
    m_portRadius = 0.01 * 0.2;
    
    m_lastTime = -1;
    m_outputBuffer = new float[bufferSize()];
    memset(m_outputBuffer, 0, sizeof(float)*bufferSize());
    m_inputPortBuffer = NULL;
}



AGAudioNode::~AGAudioNode()
{
    if(m_inputPortBuffer)
    {
        for(int i = 0; i < numInputPorts(); i++)
        {
            if(m_inputPortBuffer[i])
            {
                delete[] m_inputPortBuffer[i];
                m_inputPortBuffer[i] = NULL;
            }
        }
        
        delete[] m_inputPortBuffer;
        m_inputPortBuffer = NULL;
    }
    
    SAFE_DELETE_ARRAY(m_outputBuffer);
}

//void AGAudioNode::renderAudio(float *input, float *output, int nFrames)
//{
//}

void AGAudioNode::update(float t, float dt)
{
    AGNode::update(t, dt);
    
    GLKMatrix4 projection = projectionMatrix();
    GLKMatrix4 modelView = globalModelViewMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
}

void AGAudioNode::render()
{
    GLcolor4f color = GLcolor4f::white;
    
    // draw base outline
    glBindVertexArrayOES(s_vertexArray);
    
    color.a = m_fadeOut;
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setNormalMatrix(m_normalMatrix);
    
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
    
    glBindVertexArrayOES(0);
    
    AGNode::render();
}

AGUIObject *AGAudioNode::hitTest(const GLvertex3f &t)
{
    if(pointInCircle(t.xy(), m_pos.xy(), m_radius))
        return this;
    return NULL;
}

GLvertex3f AGAudioNode::relativePositionForInputPort(int port) const
{
    int numIn = numInputPorts();
    // compute placement to pack ports side by side on left side
    // thetaI - inner angle of the big circle traversed by 1/2 of the port
    float thetaI = acosf((2*m_radius*m_radius - s_portRadius*s_portRadius) / (2*m_radius*m_radius));
    // thetaStart - position of first port
    float thetaStart = (numIn-1)*thetaI;
    // theta - position of this port
    float theta = thetaStart - 2*thetaI*port;
    // flip horizontally to place on left side
    return GLvertex3f(-m_radius*cosf(theta), m_radius*sinf(theta), 0);
}

GLvertex3f AGAudioNode::relativePositionForOutputPort(int port) const
{
    return GLvertex3f(m_radius, 0, 0);
}

void AGAudioNode::allocatePortBuffers()
{
    if(numInputPorts() > 0)
    {
        m_inputPortBuffer = new float*[numInputPorts()];
        m_controlPortBuffer = new AGControl *[numInputPorts()];
        for(int i = 0; i < numInputPorts(); i++)
        {
            if(m_nodeInfo->inputPortInfo[i].canConnect)
            {
                m_inputPortBuffer[i] = new float[bufferSize()];
                memset(m_inputPortBuffer[i], 0, sizeof(float)*bufferSize());
            }
            else
            {
                m_inputPortBuffer[i] = NULL;
            }
            
            m_controlPortBuffer[i] = NULL;
        }
    }
    else
    {
        m_inputPortBuffer = NULL;
    }
}

void AGAudioNode::pullInputPorts(sampletime t, int nFrames)
{
    if(t <= m_lastTime) return;
    
    this->lock();
    
    if(m_inputPortBuffer != NULL)
    {
        for(int i = 0; i < numInputPorts(); i++)
        {
            if(m_inputPortBuffer[i] != NULL)
                memset(m_inputPortBuffer[i], 0, nFrames*sizeof(float));
        }
    }
    
    for(std::list<AGConnection *>::iterator c = m_inbound.begin(); c != m_inbound.end(); c++)
    {
        AGConnection *conn = *c;
        
        assert(m_inputPortBuffer && m_inputPortBuffer[conn->dstPort()]);
        
        if(conn->rate() == RATE_AUDIO)
        {
            conn->src()->renderAudio(t, NULL, m_inputPortBuffer[conn->dstPort()], nFrames);
        }
    }
    
    this->unlock();
}


void AGAudioNode::renderLast(float *output, int nFrames)
{
    for(int i = 0; i < nFrames; i++) output[i] += m_outputBuffer[i];
}


AGDocument::Node AGAudioNode::serialize()
{
    AGDocument::Node docNode;
    docNode._class = AGDocument::Node::AUDIO;
    docNode.type = type();
    docNode.uuid = uuid();
    docNode.x = position().x;
    docNode.y = position().y;
    docNode.z = position().z;
    
    for(int i = 0; i < numEditPorts(); i++)
    {
        float v;
        getEditPortValue(i, v);
        docNode.params[editPortInfo(i).name] = AGDocument::ParamValue(v);
    }
    
    return docNode;
}

//template<class NodeClass>
//AGAudioNode *AGAudioNode::createFromDocNode(const AGDocument::Node &docNode)
//{
//    AGAudioNode *node = new NodeClass(GLvertex3f(docNode.x, docNode.y, docNode.z));
//    node->m_uuid = docNode.uuid;
//    
//    for(int i = 0; i < node->numEditPorts(); i++)
//    {
//        const string &name = node->editPortInfo(i).name;
//        if(docNode.params.count(name))
//        {
//            AGDocument::ParamValue pv = docNode.params.find(name)->second;
//            float v = pv.f;
//            node->getEditPortValue(i, v);
//        }
//    }
//    
//    return node;
//}



//------------------------------------------------------------------------------
// ### AGControlNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlNode

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
        
//        AGControlTimerNode::initialize();
        
        // initialize audio nodes
        const std::vector<AGControlNodeManager::ControlNodeType *> &controlNodeTypes = AGControlNodeManager::instance().nodeTypes();
        for(std::vector<AGControlNodeManager::ControlNodeType *>::const_iterator type = controlNodeTypes.begin(); type != controlNodeTypes.end(); type++)
        {
            if((*type)->initialize)
                (*type)->initialize();
        }

    }
}

AGControlNode::AGControlNode(GLvertex3f pos, AGNodeInfo *nodeInfo) :
AGNode(pos, nodeInfo)
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
    AGDocument::Node n;
    n._class = AGDocument::Node::CONTROL;
    n.type = type();
    n.uuid = uuid();
    n.x = position().x;
    n.y = position().y;
    
    return n;
}


//------------------------------------------------------------------------------
// ### AGInputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGInputNode

void AGInputNode::initializeInputNode()
{
    initalizeNode();
    
    if(!s_init)
    {
        s_init = true;
        
        // generate triangle
        s_geoSize = 3;
        s_geo = new GLvncprimf[s_geoSize];
        float radius = AGNode::s_sizeFactor/G_RATIO;
        
        s_geo[0].vertex = GLvertex3f(-radius, radius, 0);
        s_geo[1].vertex = GLvertex3f(radius, radius, 0);
        s_geo[2].vertex = GLvertex3f(0, -(sqrtf(radius*radius*4 - radius*radius) - radius), 0);
        
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

AGInputNode::AGInputNode(GLvertex3f pos) :
AGNode(pos)
{
    initializeInputNode();
}

void AGInputNode::update(float t, float dt)
{
    AGNode::update(t, dt);
    
    GLKMatrix4 projection = projectionMatrix();
    GLKMatrix4 modelView = globalModelViewMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
}

void AGInputNode::render()
{
    glBindVertexArrayOES(s_vertexArray);
    
    GLcolor4f color = GLcolor4f::white;
    color.a = m_fadeOut;
    glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &color);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    
    // TODO
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setMVPMatrix(m_modelViewProjectionMatrix);
    shader.setNormalMatrix(m_normalMatrix);

    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}


AGNode::HitTestResult AGInputNode::hit(const GLvertex3f &hit)
{
    return HIT_NONE;
}

void AGInputNode::unhit()
{
    
}

AGUIObject *AGInputNode::hitTest(const GLvertex3f &t)
{
    GLvertex2f posxy = m_pos.xy();
    if(pointInTriangle(t.xy(), s_geo[0].vertex.xy()+posxy,
                       s_geo[1].vertex.xy()+posxy,
                       s_geo[2].vertex.xy()+posxy))
        return this;
    return NULL;
}


AGDocument::Node AGInputNode::serialize()
{
    AGDocument::Node n;
    n._class = AGDocument::Node::INPUT;
    n.type = type();
    n.uuid = uuid();
    n.x = position().x;
    n.y = position().y;
    
    return n;
}


//------------------------------------------------------------------------------
// ### AGOutputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGOutputNode

void AGOutputNode::initializeOutputNode()
{
    initalizeNode();
    
    if(!s_init)
    {
        s_init = true;
        
        // generate triangle
        s_geoSize = 3;
        s_geo = new GLvncprimf[s_geoSize];
        s_radius = AGNode::s_sizeFactor/G_RATIO;
        
        s_geo[0].vertex = GLvertex3f(-s_radius, -s_radius, 0);
        s_geo[1].vertex = GLvertex3f(s_radius, -s_radius, 0);
        s_geo[2].vertex = GLvertex3f(0, sqrtf(s_radius*s_radius*4 - s_radius*s_radius) - s_radius, 0);
        
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

AGOutputNode::AGOutputNode(GLvertex3f pos) :
AGNode(pos)
{
    initializeOutputNode();
}

void AGOutputNode::update(float t, float dt)
{
    AGNode::update(t, dt);
    
    GLKMatrix4 projection = projectionMatrix();
    GLKMatrix4 modelView = globalModelViewMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
}

void AGOutputNode::render()
{
    glBindVertexArrayOES(s_vertexArray);
    
    GLcolor4f color = GLcolor4f::white;
    color.a = m_fadeOut;
    glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &color);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    
    // TODO
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setMVPMatrix(m_modelViewProjectionMatrix);
    shader.setNormalMatrix(m_normalMatrix);

    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
}

AGNode::HitTestResult AGOutputNode::hit(const GLvertex3f &hit)
{
    return HIT_NONE;
}

void AGOutputNode::unhit()
{
    
}

AGUIObject *AGOutputNode::hitTest(const GLvertex3f &t)
{
    GLvertex2f posxy = m_pos.xy();
    if(pointInTriangle(t.xy(), s_geo[0].vertex.xy()+posxy,
                       s_geo[2].vertex.xy()+posxy,
                       s_geo[1].vertex.xy()+posxy))
        return this;
    return NULL;
}


AGDocument::Node AGOutputNode::serialize()
{
    AGDocument::Node n;
    n._class = AGDocument::Node::OUTPUT;
    n.type = type();
    n.uuid = uuid();
    n.x = position().x;
    n.y = position().y;
    
    return n;
}


//------------------------------------------------------------------------------
// ### AGFreeDraw ###
//------------------------------------------------------------------------------
#pragma mark - AGFreeDraw

AGFreeDraw::AGFreeDraw(GLvertex3f *points, int nPoints) :
m_active(true),
m_alpha(1, 0, 0.5, 2),
m_uuid(makeUUID())
{
    m_nPoints = nPoints;
    m_points = new GLvertex3f[m_nPoints];
    memcpy(m_points, points, m_nPoints * sizeof(GLvertex3f));
    m_touchDown = false;
    m_position = GLvertex3f();
    
    m_touchPoint0 = -1;
}

AGFreeDraw::AGFreeDraw(const AGDocument::Freedraw &docFreedraw) :
m_active(true),
m_alpha(1, 0, 0.5, 2),
m_uuid(docFreedraw.uuid)
{
    m_nPoints = docFreedraw.points.size()/3;
    
    m_points = new GLvertex3f[m_nPoints];
    for(int i = 0; i < m_nPoints; i++)
    {
        m_points[i].x = docFreedraw.points[i*3+0];
        m_points[i].y = docFreedraw.points[i*3+1];
        m_points[i].z = docFreedraw.points[i*3+2];
    }
    m_touchDown = false;
    m_position = GLvertex3f(docFreedraw.x, docFreedraw.y, docFreedraw.z);
    
    m_touchPoint0 = -1;
}

AGFreeDraw::~AGFreeDraw()
{
    delete[] m_points;
    m_points = NULL;
    m_nPoints = 0;
}

void AGFreeDraw::update(float t, float dt)
{
    if(!m_active)
    {
        m_alpha.update(dt);
        if(m_alpha < 0.01)
            [[AGViewController instance] removeFreeDraw:this];
    }
}

void AGFreeDraw::render()
{
    GLKMatrix4 proj = AGNode::projectionMatrix();
    GLKMatrix4 modelView = GLKMatrix4Translate(AGNode::globalModelViewMatrix(), m_position.x, m_position.y, m_position.z);
    
    AGGenericShader &shader = AGGenericShader::instance();    
    shader.useProgram();
    shader.setProjectionMatrix(proj);
    shader.setModelViewMatrix(modelView);
    shader.setNormalMatrix(GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL));
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, m_points);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    GLcolor4f color = GLcolor4f::white;
    color.a = m_alpha;
    glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &color);
    
    glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
    glDisableVertexAttribArray(GLKVertexAttribTexCoord1);
    glDisable(GL_TEXTURE_2D);
    
    if(m_touchDown)
    {
        glPointSize(8.0f);
        glLineWidth(8.0f);
    }
    else
    {
        glPointSize(4.0f);
        glLineWidth(4.0f);
    }
    
    if(m_nPoints == 1)
        glDrawArrays(GL_POINTS, 0, m_nPoints);
    else
        glDrawArrays(GL_LINE_STRIP, 0, m_nPoints);

    // debug
//    if(m_touchPoint0 >= 0)
//    {
//        glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &GLcolor4f::green);
//        glDrawArrays(GL_LINE_STRIP, m_touchPoint0, 2);
//    }
}

void AGFreeDraw::touchDown(const GLvertex3f &t)
{
    m_touchDown = true;
    m_touchLast = t;
}

void AGFreeDraw::touchMove(const GLvertex3f &t)
{
    m_position = m_position + (t - m_touchLast);
    m_touchLast = t;
    
    AGUITrash &trash = AGUITrash::instance();
    if(trash.hitTest(t))
        trash.activate();
    else
        trash.deactivate();
}

void AGFreeDraw::touchUp(const GLvertex3f &t)
{
    m_touchDown = false;
    
    m_touchPoint0 = -1;
    
    AGUITrash &trash = AGUITrash::instance();
    
    if(trash.hitTest(t))
    {
        m_active = false;
        m_alpha.reset();
    }
    
    trash.deactivate();
}

AGUIObject *AGFreeDraw::hitTest(const GLvertex3f &_t)
{
    if(!m_active)
        return NULL;
    
    GLvertex2f t = _t.xy();
    GLvertex2f pos = m_position.xy();
    
    for(int i = 0; i < m_nPoints-1; i++)
    {
        GLvertex2f p0 = m_points[i].xy() + pos;
        GLvertex2f p1 = m_points[i+1].xy() + pos;
        
        if(pointOnLine(t, p0, p1, 0.0025))
        {
            m_touchPoint0 = i;
            return this;
        }
    }
    
    return NULL;
}


AGDocument::Freedraw AGFreeDraw::serialize()
{
    AGDocument::Freedraw fd;
    fd.uuid = uuid();
    fd.x = position().x;
    fd.y = position().y;
    fd.z = position().z;
    
    fd.points.reserve(m_nPoints*3);
    for(int i = 0; i < m_nPoints; i++)
    {
        fd.points.push_back(m_points[i].x);
        fd.points.push_back(m_points[i].y);
        fd.points.push_back(m_points[i].z);
    }
    
    return fd;
}



