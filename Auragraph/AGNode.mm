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


static const float G_RATIO = 1.61803398875;


bool AGConnection::s_init = false;
GLuint AGConnection::s_program = 0;
GLint AGConnection::s_uniformMVPMatrix = 0;
GLint AGConnection::s_uniformNormalMatrix = 0;

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
// ### AGConnection ###
//------------------------------------------------------------------------------
#pragma mark - AGConnection

void AGConnection::initalize()
{
    if(!s_init)
    {
        s_init = true;
        
        s_program = [ShaderHelper createProgram:@"Shader"
                                 withAttributes:SHADERHELPER_ATTR_POSITION | SHADERHELPER_ATTR_NORMAL | SHADERHELPER_ATTR_COLOR];
        s_uniformMVPMatrix = glGetUniformLocation(s_program, "modelViewProjectionMatrix");
        s_uniformNormalMatrix = glGetUniformLocation(s_program, "normalMatrix");
    }
}

AGConnection::AGConnection(AGNode * src, AGNode * dst, int dstPort) :
m_src(src),
m_dst(dst),
m_dstPort(dstPort),
m_rate((src->rate() == RATE_AUDIO && dst->rate() == RATE_AUDIO) ? RATE_AUDIO : RATE_CONTROL), 
m_geoSize(0),
m_hit(false),
m_stretch(false),
m_active(true),
m_alpha(0.5, 1, 0, 4)
{
    initalize();
    
    AGNode::connect(this);
    
    m_inTerminal = dst->positionForOutboundConnection(this);
    m_outTerminal = src->positionForOutboundConnection(this);
    
    // generate line
    updatePath();
    
    m_color = GLcolor4f(0.75, 0.75, 0.75, 1);
    
    m_break = false;
}

AGConnection::~AGConnection()
{
//    if(m_geo != NULL) { delete[] m_geo; m_geo = NULL; }
//    AGNode::disconnect(this);
}

void AGConnection::fadeOutAndRemove()
{
    AGNode::disconnect(this);
    m_active = false;
    m_alpha.reset();
}

void AGConnection::updatePath()
{
    m_geoSize = 3;
    
    m_geo[0] = m_inTerminal;
    if(m_stretch)
        m_geo[1] = m_stretchPoint;
    else
        m_geo[1] = (m_inTerminal + m_outTerminal)/2;
    m_geo[2] = m_outTerminal;
}

void AGConnection::update(float t, float dt)
{
    if(m_break)
        m_color = GLcolor4f::red;
    else
        m_color = GLcolor4f::white;

    if(m_active)
    {
        GLvertex3f newInPos = dst()->positionForInboundConnection(this);
        GLvertex3f newOutPos = src()->positionForOutboundConnection(this);
        
        if(newInPos != m_inTerminal || newOutPos != m_outTerminal)
        {
            // recalculate path
            m_inTerminal = newInPos;
            m_outTerminal = newOutPos;
            
            updatePath();
        }
    }
    else
    {
        m_alpha.update(dt);
        m_color.a = m_alpha;
        
        if(m_alpha < 0.01)
            [[AGViewController instance] removeConnection:this];
    }
}

void AGConnection::render()
{
    GLKMatrix4 projection = AGNode::projectionMatrix();
    GLKMatrix4 modelView = AGNode::globalModelViewMatrix();
    
    GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);

    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    // render line
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &m_color);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    
    glUseProgram(s_program);
    
    glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, modelViewProjectionMatrix.m);
    glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, normalMatrix.m);
    
    if(m_hit)
        glLineWidth(4.0f);
    else
        glLineWidth(2.0f);
    glDrawArrays(GL_LINE_STRIP, 0, m_geoSize);
    
    // render waveform
    if(src()->rate() == RATE_AUDIO)
    {
        AGAudioNode *audioSrc = (AGAudioNode *) src();
        GLvertex3f vec = (m_inTerminal - m_outTerminal);
        
        AGWaveformShader &waveformShader = AGWaveformShader::instance();
        waveformShader.useProgram();
        
        GLKMatrix4 projection = AGNode::projectionMatrix();
        GLKMatrix4 modelView = AGNode::globalModelViewMatrix();
//        GLKMatrix4 modelView = GLKMatrix4Identity;
        
        modelView = GLKMatrix4Translate(modelView, m_outTerminal.x, m_outTerminal.y, m_outTerminal.z);
        modelView = GLKMatrix4Rotate(modelView, vec.xy().angle(), 0, 0, 1);
//        modelView = GLKMatrix4Translate(modelView, 0, vec.xy().magnitude()/10.0, 0);
        modelView = GLKMatrix4Scale(modelView, vec.xy().magnitude(), 0.0005, 1);
//        modelView = GLKMatrix4Scale(modelView, 0.1, 0.1, 1);
        
        waveformShader.setProjectionMatrix(projection);
        waveformShader.setModelViewMatrix(modelView);
        waveformShader.setNormalMatrix(normalMatrix);
        
        waveformShader.setZ(0);
        glVertexAttribPointer(AGWaveformShader::s_attribPositionY, 1, GL_FLOAT, GL_FALSE, 0, audioSrc->lastOutputBuffer());
        glEnableVertexAttribArray(AGWaveformShader::s_attribPositionY);
        
        glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
        glDisableVertexAttribArray(GLKVertexAttribNormal);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &m_color);
        glDisableVertexAttribArray(GLKVertexAttribColor);
        glDisableVertexAttribArray(GLKVertexAttribPosition);
        
        glLineWidth(1.0f);
        //glPointSize(4.0f);
        
        glDrawArrays(GL_LINE_STRIP, 0, AGAudioNode::bufferSize());
//        glDrawArrays(GL_LINE_STRIP, 0, 16);
        
        glEnableVertexAttribArray(GLKVertexAttribPosition);
    }
}

void AGConnection::touchDown(const GLvertex3f &t)
{
    m_hit = true;
}

void AGConnection::touchMove(const GLvertex3f &_t)
{
    m_stretch = true;
    m_stretchPoint = _t;
    updatePath();
    
    // maths courtesy of: http://mathworld.wolfram.com/Point-LineDistance2-Dimensional.html
    GLvertex2f r = GLvertex2f(m_outTerminal.x - _t.x, m_outTerminal.y - _t.y);
    GLvertex2f normal = GLvertex2f(m_inTerminal.y - m_outTerminal.y, m_outTerminal.x - m_inTerminal.x);
    
    if(fabsf(normal.normalize().dot(r)) > 0.01)
    {
        m_break = true;
    }
    else
    {
        m_break = false;
    }
}

void AGConnection::touchUp(const GLvertex3f &t)
{
    m_stretch = false;
    m_hit = false;
    
    if(m_break)
    {
        fadeOutAndRemove();
    }
    else
    {
        updatePath();
    }
    
    m_break = false;
}

AGUIObject *AGConnection::hitTest(const GLvertex3f &_t)
{
    if(!m_active)
        return NULL;

    GLvertex2f p0 = GLvertex2f(m_outTerminal.x, m_outTerminal.y);
    GLvertex2f p1 = GLvertex2f(m_inTerminal.x, m_inTerminal.y);
    GLvertex2f t = GLvertex2f(_t.x, _t.y);
    
    if(pointOnLine(t, p0, p1, 0.005))
        return this;
    
    return NULL;
}


//------------------------------------------------------------------------------
// ### AGNode ###
//------------------------------------------------------------------------------
#pragma mark - AGNode

bool AGNode::s_initNode = false;
GLKMatrix4 AGNode::s_projectionMatrix = GLKMatrix4Identity;
GLKMatrix4 AGNode::s_modelViewMatrix = GLKMatrix4Identity;
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


AGNode::AGNode(GLvertex3f pos) :
m_pos(pos),
m_nodeInfo(NULL),
m_active(true),
m_fadeOut(0.5, 1, 0, 2)
{
    m_inputActivation = m_outputActivation = 0;
    m_activation = 0;
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
        
        // initialize audio nodes
        const std::vector<AGAudioNodeManager::AudioNodeType *> &audioNodeTypes = AGAudioNodeManager::instance().audioNodeTypes();
        for(std::vector<AGAudioNodeManager::AudioNodeType *>::const_iterator type = audioNodeTypes.begin(); type != audioNodeTypes.end(); type++)
        {
            if((*type)->initialize)
                (*type)->initialize();
        }
    }
}


AGAudioNode::AGAudioNode(GLvertex3f pos) :
AGNode(pos)
{
    initializeAudioNode();
    
    m_gain = 1;
    
    m_radius = 0.01;
    m_portRadius = 0.01 * 0.2;
    
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
        }
    }
    else
    {
        m_inputPortBuffer = NULL;
    }
}

void AGAudioNode::pullInputPorts(sampletime t, int nFrames)
{
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
        else
        {
            AGControl *control = conn->src()->renderControl(t);
            float v;
            control->mapTo(v);
            for(int i = 0; i < nFrames; i++)
                m_inputPortBuffer[conn->dstPort()][i] += v;
        }
    }
    
    this->unlock();
}



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
        
        AGControlTimerNode::initialize();
    }
}

AGControlNode::AGControlNode(GLvertex3f pos) :
AGNode(pos)
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

//AGNode::HitTestResult AGControlNode::hit(const GLvertex3f &hit)
//{
//    float x, y;
//    
//    if(numInputPorts())
//    {
//        // check input port
//        x = hit.x - (m_pos.x - s_radius);
//        y = hit.y - m_pos.y;
//        if(x*x + y*y <= s_portRadius*s_portRadius)
//        {
//            return HIT_INPUT_NODE;
//        }
//    }
//    
//    if(numOutputPorts())
//    {
//        // check output port
//        x = hit.x - (m_pos.x + s_radius);
//        y = hit.y - m_pos.y;
//        if(x*x + y*y <= s_portRadius*s_portRadius)
//        {
//            return HIT_OUTPUT_NODE;
//        }
//    }
//    
//    // check whole node
//    x = hit.x - m_pos.x;
//    y = hit.y - m_pos.y;
//    if(x*x + y*y <= s_radius*s_radius)
//    {
//        return HIT_MAIN_NODE;
//    }
//    
//    return HIT_NONE;
//}
//
//void AGControlNode::unhit()
//{
//    
//}

AGUIObject *AGControlNode::hitTest(const GLvertex3f &t)
{
    if(pointInRectangle(t.xy(),
                        m_pos.xy() + GLvertex2f(-s_radius, -s_radius),
                        m_pos.xy() + GLvertex2f(s_radius, s_radius)))
       return this;
    return NULL;
}


//------------------------------------------------------------------------------
// ### AGControlTimerNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlTimerNode

AGNodeInfo *AGControlTimerNode::s_nodeInfo = NULL;

void AGControlTimerNode::initialize()
{
    s_nodeInfo = new AGNodeInfo;
    
    float radius = 0.005;
    int circleSize = 48;
    s_nodeInfo->iconGeoSize = circleSize*2 + 4;
    s_nodeInfo->iconGeoType = GL_LINES;
    s_nodeInfo->iconGeo = new GLvertex3f[s_nodeInfo->iconGeoSize];
    
    // TODO: multiple geoTypes (GL_LINE_LOOP + GL_LINE_STRIP) instead of wasteful GL_LINES
    
    for(int i = 0; i < circleSize; i++)
    {
        float theta0 = 2*M_PI*((float)i)/((float)(circleSize));
        float theta1 = 2*M_PI*((float)(i+1))/((float)(circleSize));
        s_nodeInfo->iconGeo[i*2+0] = GLvertex3f(radius*cosf(theta0), radius*sinf(theta0), 0);
        s_nodeInfo->iconGeo[i*2+1] = GLvertex3f(radius*cosf(theta1), radius*sinf(theta1), 0);
    }
    
    float minute = 47;
    float minuteAngle = M_PI/2.0 + (minute/60.0)*(-2.0*M_PI);
    float hour = 1;
    float hourAngle = M_PI/2.0 + (hour/12.0 + minute/60.0/12.0)*(-2.0*M_PI);
    
    s_nodeInfo->iconGeo[circleSize*2+0] = GLvertex3f(0, 0, 0);
    s_nodeInfo->iconGeo[circleSize*2+1] = GLvertex3f(radius/G_RATIO*cosf(hourAngle), radius/G_RATIO*sinf(hourAngle), 0);
    s_nodeInfo->iconGeo[circleSize*2+2] = GLvertex3f(0, 0, 0);
    s_nodeInfo->iconGeo[circleSize*2+3] = GLvertex3f(radius*0.925*cosf(minuteAngle), radius*0.925*sinf(minuteAngle), 0);
    
    s_nodeInfo->editPortInfo.push_back({ "intrvl", true, true });
    s_nodeInfo->inputPortInfo.push_back({ "intrvl", true, true });
}

AGControlTimerNode::AGControlTimerNode(const GLvertex3f &pos) :
AGControlNode(pos)
{
    m_nodeInfo = s_nodeInfo;
    m_interval = 0.5;
    m_lastFire = 0;
    m_lastTime = 0;
}

void AGControlTimerNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_interval = value; break;
    }
}

void AGControlTimerNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_interval; break;
    }
}

AGControl *AGControlTimerNode::renderControl(sampletime t)
{
    if(t > m_lastTime)
    {
        if(((float)(t - m_lastFire))/AGAudioNode::sampleRate() > m_interval)
        {
            m_control.v = 1;
            m_lastFire = t;
        }
        else
        {
            m_control.v = 0;
        }
        
        m_lastTime = t;
    }
    
    return &m_control;
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
    GLKMatrix4 projection = projectionMatrix();
    GLKMatrix4 modelView = globalModelViewMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
}

void AGInputNode::render()
{
    glBindVertexArrayOES(s_vertexArray);
    
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
    GLKMatrix4 projection = projectionMatrix();
    GLKMatrix4 modelView = globalModelViewMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
}

void AGOutputNode::render()
{
    glBindVertexArrayOES(s_vertexArray);
    
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


//------------------------------------------------------------------------------
// ### AGFreeDraw ###
//------------------------------------------------------------------------------
#pragma mark - AGFreeDraw

AGFreeDraw::AGFreeDraw(GLvncprimf *points, int nPoints) :
m_active(true),
m_alpha(0.5, 1, 0, 2)
{
    m_nPoints = nPoints;
    m_points = new GLvncprimf[m_nPoints];
    memcpy(m_points, points, m_nPoints * sizeof(GLvncprimf));
    m_touchDown = false;
    m_position = GLvertex3f();
    
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
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), m_points);
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
        GLvertex2f p0 = m_points[i].vertex.xy() + pos;
        GLvertex2f p1 = m_points[i+1].vertex.xy() + pos;
        
        if(pointOnLine(t, p0, p1, 0.0025))
        {
            m_touchPoint0 = i;
            return this;
        }
    }
    
    return NULL;
}




