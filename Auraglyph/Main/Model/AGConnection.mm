//
//  AGConnection.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/13/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGConnection.h"
#include "AGAudioNode.h"
#include "AGGraph.h"
#include "AGViewController.h"
#include "AGGenericShader.h"

#include "Texture.h"
#include "spstl.h"
#include "GeoGenerator.h"
#include "sputil.h"
#include "AGStyle.h"

#include "AGGraphManager.h"
#include "AGActivityManager.h"
#include "AGActivity.h"

bool AGConnection::s_init = false;
GLuint AGConnection::s_flareTex = 0;

AGRenderInfoV *g_controlVis;
//GLvertex3f *g_controlSignalMesh = NULL;


//------------------------------------------------------------------------------
// ### AGConnection ###
//------------------------------------------------------------------------------
#pragma mark - AGConnection

void AGConnection::initalize()
{
    if(!s_init)
    {
        s_init = true;
        s_flareTex = loadTexture("flare.png");
        
        g_controlVis = new AGRenderInfoV;
        
        float height = 0.62;
        float exponent = 12;
        int nQuads = 32;
        // fill with GL_TRIANGLE_STRIP
        g_controlVis->geo = new GLvertex3f[(nQuads+1)*2];
        g_controlVis->numVertex = (nQuads+1)*2;
        g_controlVis->geoType = GL_TRIANGLE_STRIP;
        for(int i = 0; i < nQuads+1; i++)
        {
            float x = ((float)i)/((float)nQuads);
            float val = powf(sinf(M_PI*x), exponent) * height;
            g_controlVis->geo[i*2] = GLvertex3f(x, val, 0);
            g_controlVis->geo[i*2+1] = GLvertex3f(x, -val, 0);
        }
    }
}

AGConnection *AGConnection::connect(AGNode *src, int srcPort, AGNode *dst, int dstPort)
{
    AGConnection *conn = new AGConnection(src, srcPort, dst, dstPort);
    conn->init();
    
    return conn;
}

AGConnection *AGConnection::connect(const AGDocument::Connection &docConnection)
{
    AGGraphManager &graphManager = AGGraphManager::instance();
    AGNode *srcNode = graphManager.graph()->nodeWithUUID(docConnection.srcUuid);
    AGNode *dstNode = graphManager.graph()->nodeWithUUID(docConnection.dstUuid);
    if(srcNode != nullptr && dstNode != nullptr &&
       docConnection.dstPort >= 0 && docConnection.dstPort < dstNode->numInputPorts() &&
       docConnection.srcPort >= 0 && docConnection.srcPort < srcNode->numOutputPorts())
    {
        AGConnection *conn = new AGConnection(srcNode, docConnection.srcPort,
                                              dstNode, docConnection.dstPort,
                                              docConnection.uuid);
        conn->init();

        return conn;
    }
    else
        return nullptr;
}

AGConnection::AGConnection(AGNode * src, int srcPort, AGNode * dst, int dstPort, const string &uuid) :
m_src(src), m_srcPort(srcPort), m_dst(dst), m_dstPort(dstPort),
m_rate((src->rate() == RATE_AUDIO && dst->rate() == RATE_AUDIO) ? RATE_AUDIO : RATE_CONTROL),
m_geoSize(0), m_hit(false), m_stretch(false), m_active(true),
m_stretchPoint(0.25, GLvertex3f()), m_controlVisScale(0.07, 0),
m_uuid(uuid.length() > 0 ? uuid : makeUUID())
{
    initalize();
    
    AGNode::connect(this);
    
    m_inTerminal = dst->positionForOutboundConnection(this);
    m_outTerminal = src->positionForOutboundConnection(this);
    
    // generate line
    updatePath();
    
    m_color = AGStyle::foregroundColor().blend(0.75, 0.75, 0.75, 1);
    m_alpha.k = 0.5;
    m_alpha.rate = 4;
    m_alpha.finish(); // force to 1
    
    m_break = false;
    
    float flareSize = 0.004*AGStyle::oldGlobalScale;
    GeoGen::makeRect(m_flareGeo, flareSize, flareSize);
    GeoGen::makeRectUV(m_flareUV);
}

AGConnection::~AGConnection()
{
}

void AGConnection::renderOut()
{
    AGRenderObject::renderOut();
    AGNode::disconnect(this);
    m_active = false;
}

void AGConnection::updatePath()
{
    m_geoSize = 3;
    
    m_geo[0] = m_inTerminal;
//    if(m_stretch)
    m_geo[1] = ((m_inTerminal + m_outTerminal)/2 + m_stretchPoint);
//    else
//        m_geo[1] = (m_inTerminal + m_outTerminal)/2;
    m_geo[2] = m_outTerminal;
}

void AGConnection::update(float t, float dt)
{
    AGRenderObject::update(t, dt);
    
    m_stretchPoint.interp();
    m_controlVisScale.interp();
    
    if(m_break)
        m_color = AGStyle::errorColor();
    else
        m_color = AGStyle::foregroundColor();
    m_color.a = m_alpha;
    
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
        
        updatePath();
    }
    
    float flareSpeed = 2;
    itmap(m_flares, ^(float &f){
        f += dt*flareSpeed*(0.25f+(1.0f+cosf(M_PI*(f-0.1)))/2.0f);
    });
    itfilter(m_flares, ^bool (float &f){
        return f >= 1;
    });
    
    // relax to zero
    m_controlVisScale = 0;
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
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(AGVertexAttribNormal);
    glVertexAttrib4fv(AGVertexAttribColor, (const float *) &m_color);
    glDisableVertexAttribArray(AGVertexAttribColor);
    
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setMVPMatrix(modelViewProjectionMatrix);
    shader.setNormalMatrix(normalMatrix);
    
    if(m_hit)
        glLineWidth(4.0f);
    else
        glLineWidth(2.0f);
    glDrawArrays(GL_LINE_STRIP, 0, m_geoSize);
    
    // render waveform
    if(src()->rate() == RATE_AUDIO)
    {
        AGAudioNode *audioSrc = (AGAudioNode *) src();
        //        GLvertex3f vec = (m_inTerminal - m_outTerminal);
        GLvertex3f vec = (m_outTerminal - m_inTerminal);
        
        // scale gain logarithmically
        float gain = audioSrc->gain();
        gain = 1.0f/gain * (1+log10f(gain+0.1));
        
        AGWaveformShader &waveformShader = AGWaveformShader::instance();
        waveformShader.useProgram();
        
        GLKMatrix4 projection = AGNode::projectionMatrix();
        GLKMatrix4 modelView = AGNode::globalModelViewMatrix();
        
        // rendering the waveform in reverse seems to look better
        // probably because of aliasing between graphic fps and audio rate
        // move to destination terminal
        // modelView = GLKMatrix4Translate(modelView, m_outTerminal.x, m_outTerminal.y, m_outTerminal.z);
        modelView = GLKMatrix4Translate(modelView, m_inTerminal.x, m_inTerminal.y, m_inTerminal.z);
        // rotate to face direction of source terminal
        modelView = GLKMatrix4Rotate(modelView, vec.xy().angle(), 0, 0, 1);
        // move a to edge of port circle
        modelView = GLKMatrix4Translate(modelView, 0.002*AGStyle::oldGlobalScale, 0, 0);
        // scale [0,1] to length of connection (minus port circle radius)
        // also flip y axis (somehow is necessary for correct visuals)
        modelView = GLKMatrix4Scale(modelView, (vec.xy().magnitude()-0.004*AGStyle::oldGlobalScale), -1*0.001*AGStyle::oldGlobalScale, 1);
        
        waveformShader.setProjectionMatrix(projection);
        waveformShader.setModelViewMatrix(modelView);
        waveformShader.setNormalMatrix(normalMatrix);
        
        waveformShader.setZ(0);
        waveformShader.setGain(gain);
        
        glVertexAttribPointer(AGWaveformShader::s_attribPositionY, 1, GL_FLOAT, GL_FALSE, 0, audioSrc->lastOutputBuffer(srcPort()));
        
        glEnableVertexAttribArray(AGWaveformShader::s_attribPositionY);
        waveformShader.setNumElements(AGAudioNode::bufferSize());
        
        glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
        glDisableVertexAttribArray(AGVertexAttribNormal);
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &m_color);
        glDisableVertexAttribArray(AGVertexAttribColor);
        glDisableVertexAttribArray(AGVertexAttribPosition);
        
        glLineWidth(1.0f);
        
        glDrawArrays(GL_LINE_STRIP, 0, AGAudioNode::bufferSize());
        
        glEnableVertexAttribArray(AGVertexAttribPosition);
    }
    
    if(src()->rate() == RATE_CONTROL)
    {
        GLvertex3f vec = (m_outTerminal - m_inTerminal);
        
        AGGenericShader &shader = AGGenericShader::instance();
        shader.useProgram();
        
        GLKMatrix4 projection = AGNode::projectionMatrix();
        GLKMatrix4 modelView = AGNode::globalModelViewMatrix();
        
        // move to destination terminal
        modelView = GLKMatrix4Translate(modelView, m_inTerminal.x, m_inTerminal.y, m_inTerminal.z);
        // rotate to face direction of source terminal
        modelView = GLKMatrix4Rotate(modelView, vec.xy().angle(), 0, 0, 1);
        // move a to edge of port circle
        modelView = GLKMatrix4Translate(modelView, 0.002*AGStyle::oldGlobalScale, 0, 0);
        // scale x = [0,1] to length of connection (minus port circle radius)
        modelView = GLKMatrix4Scale(modelView, (vec.xy().magnitude()-0.004*AGStyle::oldGlobalScale), 0.0025*AGStyle::oldGlobalScale, 1);
        // scale height to control activation
        modelView = GLKMatrix4Scale(modelView, 1, m_controlVisScale*0.5, 1);
//        modelView = GLKMatrix4Scale(modelView, 1, 1, 1);
        
        shader.setProjectionMatrix(projection);
        shader.setModelViewMatrix(modelView);
        shader.setNormalMatrix(normalMatrix);
        
        glEnableVertexAttribArray(AGVertexAttribPosition);
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), g_controlVis->geo);
        glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &m_color);
        
        glDrawArrays(g_controlVis->geoType, 0, g_controlVis->numVertex);
    }
}

void AGConnection::touchDown(const GLvertex3f &t)
{
    m_hit = true;
}

void AGConnection::touchMove(const GLvertex3f &_t)
{
    m_stretch = true;
    m_stretchPoint.reset(_t - (m_inTerminal + m_outTerminal)/2);
    updatePath();
    
    // maths courtesy of: http://mathworld.wolfram.com/Point-LineDistance2-Dimensional.html
    GLvertex2f r = GLvertex2f(m_outTerminal.x - _t.x, m_outTerminal.y - _t.y);
    GLvertex2f normal = GLvertex2f(m_inTerminal.y - m_outTerminal.y, m_outTerminal.x - m_inTerminal.x);
    
    if(fabsf(normal.normalize().dot(r)) > 0.01*AGStyle::oldGlobalScale)
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
    m_stretchPoint = GLvertex3f();
    m_hit = false;
    
    if(m_break)
    {
        AGActivity *action = AGActivity::deleteConnectionActivity(this);
        AGActivityManager::instance().addActivity(action);
        
        removeFromTopLevel();
    }
    else
    {
        updatePath();
    }
    
    m_break = false;
}

AGInteractiveObject *AGConnection::hitTest(const GLvertex3f &_t)
{
    if(!m_active)
        return NULL;
    
    GLvertex2f p0 = GLvertex2f(m_outTerminal.x, m_outTerminal.y);
    GLvertex2f p1 = GLvertex2f(m_inTerminal.x, m_inTerminal.y);
    GLvertex2f t = GLvertex2f(_t.x, _t.y);
    
    if(pointOnLine(t, p0, p1, 0.005*AGStyle::oldGlobalScale))
        return this;
    
    return NULL;
}

void AGConnection::controlActivate(const AGControl &ctrl)
{
//    // immediately pop up to "1"
//    m_controlVisScale.reset(1);
//    // set target to 0 - slowly contract
//    m_controlVisScale = 0;
    
    bool set = false;
    float val = 0;
    
    switch(ctrl.type)
    {
        case AGControl::TYPE_NONE:
            val = 0;
            set = true;
            break;
        case AGControl::TYPE_BIT:
            if(ctrl.vbit)
                m_controlVisScale.reset(1); // jump to full on
            else
                m_controlVisScale = 0; // relax to off
            break;
        case AGControl::TYPE_INT:
            val = ctrl.vint;
            set = true;
//            m_controlVisScale = 1+log10(fabsf((float)ctrl.vint)+0.00001);
            break;
        case AGControl::TYPE_FLOAT:
            val = ctrl.vfloat;
            set = true;
//            m_controlVisScale = 1+log10(fabsf(ctrl.vfloat)+0.00001);
            break;
        case AGControl::TYPE_STRING:
            m_controlVisScale = ctrl.vstring.length() > 0 ? 1 : 0;
            break;
    }
    
    if(set)
    {
        val = fabsf(val);
        if(val >= 1)
            m_controlVisScale.reset(1+(log10f(val)));
        else if(val > 0)
            m_controlVisScale.reset(1/(1-log10(val)));
        else
            m_controlVisScale = 0;
    }
    
    m_activation = ctrl;
}


AGDocument::Connection AGConnection::serialize()
{
    AGDocument::Connection docConnection;
    docConnection.uuid = m_uuid;
    docConnection.srcUuid = src()->uuid();
    docConnection.srcPort = srcPort();
    docConnection.dstUuid = dst()->uuid();
    docConnection.dstPort = dstPort();
    
    return docConnection;
}

