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
#include "AGStyle.h"
#include "AGControl.h"

#import "spstl.h"


//------------------------------------------------------------------------------
// ### AGNode ###
//------------------------------------------------------------------------------
#pragma mark - AGNode

bool AGNode::s_initNode = false;
const float AGNode::s_sizeFactor = 0.01*AGStyle::oldGlobalScale;

float AGNode::s_portRadius = 0.01*0.2*AGStyle::oldGlobalScale;
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
    dbgprint("disconnect: (0x%08x) 0x%08x:%i -> 0x%08x:%i\n",
             (unsigned int) connection, (unsigned int) connection->src(), connection->srcPort(),
             (unsigned int) connection->dst(), connection->dstPort());
    
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


AGNode::AGNode(const AGNodeManifest *mf, const GLvertex3f &pos) :
m_pos(pos),
m_manifest(mf),
m_active(true),
m_fadeOut(1, 0, 0.5, 2),
m_uuid(makeUUID())
{ }

AGNode::AGNode(const AGNodeManifest *mf, const AGDocument::Node &docNode) :
m_pos(GLvertex3f(docNode.x, docNode.y, docNode.z)),
m_manifest(mf),
m_active(true),
m_fadeOut(1, 0, 0.5, 2),
m_uuid(docNode.uuid)
{ }

void AGNode::_initBase()
{
    AGRenderObject::init();
    
    m_inputActivation = m_outputActivation = 0;
    m_activation = 0;
    
    if(numInputPorts() > 0)
        m_controlPortBuffer.resize(numInputPorts());
    //        m_controlPortBuffer = new AGControl[numInputPorts()];
    
    int numInput = numInputPorts();
    for(int i = 0; i < numInput; i++)
    {
        const AGPortInfo &info = inputPortInfo(i);
        m_param2InputPort[info.portId] = i;
    }
    
    int numEdit = numEditPorts();
    for(int i = 0; i < numEdit; i++)
    {
        const AGPortInfo &info = editPortInfo(i);
        m_param2EditPort[info.portId] = i;
        m_params[info.portId] = getDefaultParamValue(info.portId);
    }
}

void AGNode::init()
{
    _initBase();
    
    initFinal();
}

void AGNode::init(const AGDocument::Node &docNode)
{
    // initialize base class
    _initBase();
    
    // initialize final subclass
    initFinal();

    // load standard edit params from seralization structure
    loadEditPortValues(docNode);
    
    // load any custom data to final subclass
    deserializeFinal(docNode);
}

void AGNode::loadEditPortValues(const AGDocument::Node &docNode)
{
    for(int i = 0; i < numEditPorts(); i++)
    {
        const string &name = editPortInfo(i).name;
        if(docNode.params.count(name))
        {
            AGDocument::ParamValue pv = docNode.params.find(name)->second;
            AGParamValue v = pv;
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
    
    dbgprint("disconnecting inbound nodes (%li)\n", m_inbound.size());
    itmap_safe(m_inbound, ^(AGConnection *&_connection){
        AGConnection *connection = _connection;
        AGNode::disconnect(connection);
        [[AGViewController instance] fadeOutAndDelete:connection];
    });
    dbgprint("disconnecting outbound nodes (%li)\n", m_outbound.size());
    itmap_safe(m_outbound, ^(AGConnection *&_connection){
        AGConnection *connection = _connection;
        AGNode::disconnect(connection);
        [[AGViewController instance] fadeOutAndDelete:connection];
    });
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
    int inputPort = connection->dstPort();
    
    m_inbound.remove(connection);
    
    // clear m_controlPortBuffer for this connection if no control connections remain
    bool hasCtlLeft = false;
    for(auto inboundConn : m_inbound)
    {
        if(inboundConn->dstPort() == inputPort && inboundConn->rate() == RATE_CONTROL)
        {
            hasCtlLeft = true;
            break;
        }
    }
    
    if(!hasCtlLeft)
        m_controlPortBuffer[connection->dstPort()] = AGControl();
}

void AGNode::removeOutbound(AGConnection *connection)
{
    m_outbound.remove(connection);
}

void AGNode::trimConnectionsToNodes(const set<AGNode *> &nodes)
{
    list<AGConnection *> removeList;
    
    for(auto i = m_inbound.begin(); i != m_inbound.end(); )
    {
        auto j = i++;
        if(!nodes.count((*j)->src()))
            (*j)->removeFromTopLevel();
    }
    
    for(auto i = m_outbound.begin(); i != m_outbound.end(); )
    {
        auto j = i++;
        if(!nodes.count((*j)->dst()))
            (*j)->removeFromTopLevel();
    }
}

const std::list<AGConnection *> AGNode::outbound() const
{
    return m_outbound;
}

const std::list<AGConnection *> AGNode::inbound() const
{
    return m_inbound;
}

AGInteractiveObject *AGNode::_hitTestConnections(const GLvertex3f &t)
{
    // disable (connections are hit-tested explicitly in the view controller)
    return NULL;
    
    AGInteractiveObject *hit = NULL;
    
    // a node is only responsible for hittest/update/rendering inbound connections
    for(AGConnection *connection : m_inbound)
    {
        hit = connection->hitTest(t);
        if(hit != NULL)
            break;
    }
    
    return hit;
}

void AGNode::_updateConnections(float t, float dt)
{
    // a node is only responsible for hittest/update/rendering inbound connections
    for(AGConnection *connection : m_inbound)
        connection->update(t, dt);
}

void AGNode::_renderConnections()
{
    // a node is only responsible for hittest/update/rendering inbound connections
    for(AGConnection *connection : m_inbound)
        connection->render();
}

void AGNode::update(float t, float dt)
{
    if(!m_active)
    {
        m_fadeOut.update(dt);
//        if(m_fadeOut < 0.01)
//            [[AGViewController instance] removeNode:this];
    }
    
    _updateConnections(t, dt);
}

bool AGNode::finishedRenderingOut()
{
    return m_fadeOut < 0.01;
}

void AGNode::render()
{
    glBindVertexArrayOES(0);
    
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setMVPMatrix(m_modelViewProjectionMatrix);
    shader.setNormalMatrix(m_normalMatrix);
    
    int numOut = numOutputPorts();
    for(int port = 0; port < numOut; port++)
    {
        // draw output port
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_portGeo);
        glEnableVertexAttribArray(AGVertexAttribPosition);
        
        GLvertex3f portPos = relativePositionForOutputPort(port);
        GLKMatrix4 mvpOutputPort = GLKMatrix4Translate(m_modelViewProjectionMatrix, portPos.x, portPos.y, portPos.z);
        mvpOutputPort = GLKMatrix4Scale(mvpOutputPort, 0.8, 0.8, 0.8);
        shader.setMVPMatrix(mvpOutputPort);
        
        GLcolor4f color;
        if(m_outputActivation == 1+port)       color = GLcolor4f(0, 1, 0, 1);
        else if(m_outputActivation == -1-port) color = GLcolor4f(1, 0, 0, 1);
        else                                   color = GLcolor4f(1, 1, 1, 1);
        color.a = m_fadeOut;
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &color);
        
        glLineWidth(2.0f);
        glDrawArrays(s_portGeoType, 0, s_portGeoSize);
    }
    
    int numIn = numInputPorts();
    for(int port = 0; port < numIn; port++)
    {
        // draw input port
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_portGeo);
        glEnableVertexAttribArray(AGVertexAttribPosition);

        GLvertex3f portPos = relativePositionForInputPort(port);
        GLKMatrix4 mvpInputPort = GLKMatrix4Translate(m_modelViewProjectionMatrix, portPos.x, portPos.y, portPos.z);
        mvpInputPort = GLKMatrix4Scale(mvpInputPort, 0.8, 0.8, 0.8);
        shader.setMVPMatrix(mvpInputPort);
        
        GLcolor4f color;
        if(m_inputActivation == 1+port)       color = GLcolor4f(0, 1, 0, 1);
        else if(m_inputActivation == -1-port) color = GLcolor4f(1, 0, 0, 1);
        else                                  color = GLcolor4f(1, 1, 1, 1);
        color.a = m_fadeOut;
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &color);
        
        glLineWidth(2.0f);
        glDrawArrays(s_portGeoType, 0, s_portGeoSize);
    }
    
    _renderIcon();
    _renderConnections();
}

void AGNode::_renderIcon()
{
    if(m_manifest)
    {
        AGGenericShader &shader = AGGenericShader::instance();
        shader.useProgram();
        
        shader.setMVPMatrix(m_modelViewProjectionMatrix);
        shader.setNormalMatrix(m_normalMatrix);
        
        GLcolor4f color = GLcolor4f::white;
        color.a = m_fadeOut;
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &color);
        glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
        
        m_manifest->renderIcon();
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

AGInteractiveObject *AGNode::hitTest(const GLvertex3f &t)
{
//    return _hitTestConnections(t);
    return NULL;
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

void AGNode::pushControl(int port, const AGControl &control)
{
    assert(port >= 0 && port < numOutputPorts());
    
    this->lock();
    
    // ensure correct size
    if(port >= m_lastControlOutput.size())
        m_lastControlOutput.resize(numOutputPorts());
    
    m_lastControlOutput[port] = control;
    
    float f;
    control.mapTo(f);
    dbgprint_off("pushControl %i:%f from %0lx\n", port, f, (unsigned long)this);
    
    for(AGConnection *conn : m_outbound)
    {
        if(conn->rate() == RATE_CONTROL && conn->srcPort() == port)
        {
            conn->dst()->receiveControl_internal(conn->dstPort(), control);
            conn->controlActivate(control);
        }
    };
    
    this->unlock();
}

AGControl AGNode::lastControlOutput(int port)
{
    assert(port >= 0 && port < numOutputPorts());
    
    this->lock();
    
    // ensure correct size
    if(port >= m_lastControlOutput.size())
        m_lastControlOutput.resize(numOutputPorts());
    
    AGControl c = m_lastControlOutput[port];
    
    this->unlock();
    
    return c;
}

void AGNode::receiveControl_internal(int port, const AGControl &control)
{
    m_controlPortBuffer[port] = AGControl(control);
    receiveControl(port, control);
}

float AGNode::validateEditPortValue(int port, float _new) const
{
    const AGPortInfo &info = editPortInfo(port);
    
    if(info.min != info.max)
    {
        if(_new < info.min)
            return info.min;
        if(_new > info.max)
            return info.max;
    }
    
    return _new;
}

void AGNode::finalPortValue(float &value, int portId, int sample) const
{
    int index = m_param2InputPort.at(portId);
    if(m_controlPortBuffer[index])
        value = m_controlPortBuffer[index].getFloat();
    else
        value = m_params.at(portId);
}

int AGNode::numInputsForPort(int portId)
{
    int portNum = m_param2InputPort[portId];
    int numInputs = 0;
    for(auto conn : m_inbound)
    {
        if(conn->dstPort() == portNum)
            numInputs++;
    }
    
    return numInputs;
}

AGDocument::Node AGNode::serialize()
{
    assert(type().length());
    
    AGDocument::Node docNode;
    docNode._class = nodeClass();
    docNode.type = type();
    docNode.uuid = uuid();
    docNode.x = position().x;
    docNode.y = position().y;
    docNode.z = position().z;
    
    for(int i = 0; i < numEditPorts(); i++)
    {
        AGParamValue v;
        getEditPortValue(i, v);
        docNode.params[editPortInfo(i).name] = AGDocument::ParamValue(v);
    }
    
    for(const AGConnection *conn : m_inbound)
    {
        docNode.inbound.push_back({
            conn->uuid(),
            conn->src()->uuid(),
            conn->srcPort(),
            conn->dst()->uuid(),
            conn->dstPort()
        });
    }
    
    for(const AGConnection *conn : m_outbound)
    {
        docNode.outbound.push_back({
            conn->uuid(),
            conn->src()->uuid(),
            conn->srcPort(),
            conn->dst()->uuid(),
            conn->dstPort()
        });
    }
    
    return std::move(docNode);
}


//------------------------------------------------------------------------------
// ### AGFreeDraw ###
//------------------------------------------------------------------------------
#pragma mark - AGFreeDraw

AGFreeDraw::AGFreeDraw(GLvertex3f *points, int nPoints) :
m_active(true),
m_uuid(makeUUID())
{
    m_nPoints = nPoints;
    m_points = new GLvertex3f[m_nPoints];
    memcpy(m_points, points, m_nPoints * sizeof(GLvertex3f));
    m_touchDown = false;
    m_position = GLvertex3f();
    
    m_alpha = powcurvef(0, 1, 0.5, 2);
    m_alpha.forceTo(1);
    
    m_touchPoint0 = -1;
}

AGFreeDraw::AGFreeDraw(const AGDocument::Freedraw &docFreedraw) :
m_active(true),
//m_alpha(1, 0, 0.5, 2),
m_uuid(docFreedraw.uuid)
{
    m_nPoints = docFreedraw.points.size()/3;
    
    m_alpha = powcurvef(0, 1, 0.5, 2);
    m_alpha.forceTo(1);
    
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
    AGRenderObject::update(t, dt);
    if(!m_active)
    {
//        m_alpha.update(dt);
//        if(m_alpha < 0.01)
//            [[AGViewController instance] removeFreeDraw:this];
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
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, m_points);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
    GLcolor4f color = GLcolor4f::white;
    color.a = m_alpha;
    glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &color);
    
    glDisableVertexAttribArray(AGVertexAttribTexCoord0);
    glDisableVertexAttribArray(AGVertexAttribTexCoord1);
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
//        glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &GLcolor4f::green);
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
//        m_alpha.reset();
        removeFromTopLevel();
    }
    
    trash.deactivate();
}

AGUIObject *AGFreeDraw::hitTest(const GLvertex3f &_t)
{
    return NULL;
    
    if(!m_active)
        return NULL;
    
    GLvertex2f t = _t.xy();
    GLvertex2f pos = m_position.xy();
    
    for(int i = 0; i < m_nPoints-1; i++)
    {
        GLvertex2f p0 = m_points[i].xy() + pos;
        GLvertex2f p1 = m_points[i+1].xy() + pos;
        
        if(pointOnLine(t, p0, p1, 0.0025*AGStyle::oldGlobalScale))
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



//------------------------------------------------------------------------------
// ### AGNodeManager ###
//------------------------------------------------------------------------------
#pragma mark - AGNodeManager

AGNodeManager *AGNodeManager::s_audioNodeManager = NULL;
AGNodeManager *AGNodeManager::s_controlNodeManager = NULL;
AGNodeManager *AGNodeManager::s_inputNodeManager = NULL;
AGNodeManager *AGNodeManager::s_outputNodeManager = NULL;

const AGNodeManager &AGNodeManager::outputNodeManager()
{
    if(s_outputNodeManager == NULL)
    {
        s_outputNodeManager = new AGNodeManager();
    }
    
    return *s_outputNodeManager;
}

AGNodeManager::AGNodeManager() { }

const std::vector<const AGNodeManifest *> &AGNodeManager::nodeTypes() const
{
    return m_nodeTypes;
}

void AGNodeManager::renderNodeTypeIcon(const AGNodeManifest *type) const
{
    type->renderIcon();
}

AGNode *AGNodeManager::createNodeType(const AGNodeManifest *mf, const GLvertex3f &pos) const
{
    AGNode *node = mf->createNode(pos);
    node->setTitle(mf->name());
    return node;
}

AGNode *AGNodeManager::createNodeType(const AGDocument::Node &docNode) const
{
    AGNode *node = NULL;
    
    for(const AGNodeManifest *const &mf : m_nodeTypes)
    {
        if(mf->type() == docNode.type)
        {
            node = mf->createNode(docNode);
            node->setTitle(mf->name());
            break;
        }
    }
    
    return node;
}

AGNode *AGNodeManager::createNodeOfType(const string &type, const GLvertex3f &pos) const
{
    for(const AGNodeManifest *const &mf : m_nodeTypes)
    {
        if(mf->type() == type)
        {
            AGNode *node = mf->createNode(pos);
            node->setTitle(mf->name());
            return node;
        }
    }
    
    return NULL;
}



