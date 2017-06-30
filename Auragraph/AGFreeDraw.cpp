//
//  AGFreeDraw.m
//  Auragraph
//
//  Created by Andrew Piepenbrink on 6/29/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGFreeDraw.h"

#include "AGNode.h"
#include "AGDocument.h"
#include "AGInteractiveObject.h"
#include "AGGenericShader.h"
#include "Geometry.h"
#include "Animation.h"
#include "AGStyle.h"
#include "sputil.h"
#include "spstl.h"

//------------------------------------------------------------------------------
// ### AGFreeDraw ###
//------------------------------------------------------------------------------
#pragma mark - AGFreeDraw

AGFreeDraw::AGFreeDraw(GLvertex3f *points, int nPoints) :
m_active(true),
m_uuid(makeUUID())
{
    m_points = vector<GLvertex3f>(points, points + nPoints);
    
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
    int nPoints = docFreedraw.points.size()/3;
    
    m_alpha = powcurvef(0, 1, 0.5, 2);
    m_alpha.forceTo(1);
    
    m_points.reserve(nPoints * sizeof(GLvertex3f));
    for(int i = 0; i < nPoints; i++)
    {
        float x = docFreedraw.points[i*3+0];
        float y = docFreedraw.points[i*3+1];
        float z = docFreedraw.points[i*3+2];
        m_points.push_back(GLvertex3f(x, y, z));
    }
    m_touchDown = false;
    m_position = GLvertex3f(docFreedraw.x, docFreedraw.y, docFreedraw.z);
    
    m_touchPoint0 = -1;
}

AGFreeDraw::~AGFreeDraw() { }

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
    
    //    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, m_points);
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, m_points.data());
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
    
    if(m_points.size() == 1)
        glDrawArrays(GL_POINTS, 0, m_points.size());
    else
        glDrawArrays(GL_LINE_STRIP, 0, m_points.size());
    
    // debug
    //    if(m_touchPoint0 >= 0)
    //    {
    //        glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &GLcolor4f::green);
    //        glDrawArrays(GL_LINE_STRIP, m_touchPoint0, 2);
    //    }
}

void AGFreeDraw::touchDown(const GLvertex3f &t)
{
    m_touchLast = t;
}

void AGFreeDraw::touchMove(const GLvertex3f &t)
{
    m_touchLast = t;
}

void AGFreeDraw::touchUp(const GLvertex3f &t)
{
    m_touchPoint0 = -1;
}

const vector<GLvertex3f> &AGFreeDraw::points()
{
    return m_points;
}

AGUIObject *AGFreeDraw::hitTest(const GLvertex3f &_t)
{
    if(!m_active)
        return NULL;
    
    GLvertex2f t = _t.xy();
    GLvertex2f pos = m_position.xy();
    
    for(int i = 0; i < m_points.size()-1; i++)
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
    
    fd.points.reserve(m_points.size()*3);
    for(int i = 0; i < m_points.size(); i++)
    {
        fd.points.push_back(m_points[i].x);
        fd.points.push_back(m_points[i].y);
        fd.points.push_back(m_points[i].z);
    }
    
    return fd;
}
