//
//  AGFileBrowser.mm
//  Auragraph
//
//  Created by Spencer Salazar on 1/7/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGFileBrowser.h"
#include "AGStyle.h"
#include "Animation.h"

AGFileBrowser::AGFileBrowser(const GLvertex3f &position)
{
    m_xScale = lincurvef(AGStyle::open_animTimeX, AGStyle::open_squeezeHeight, 1);
    m_yScale = lincurvef(AGStyle::open_animTimeY, AGStyle::open_squeezeHeight, 1);
    
    m_pos = position;
    m_size.x = 250;
    m_size.y = m_size.x/AGStyle::aspect16_9;
}

AGFileBrowser::~AGFileBrowser()
{
}

void AGFileBrowser::update(float t, float dt)
{
    AGInteractiveObject::update(t, dt);
    
    if(parent())
    {
        m_renderState.modelview = parent()->m_renderState.modelview;
        m_renderState.projection = parent()->m_renderState.projection;
    }
    else
    {
        m_renderState.modelview = globalModelViewMatrix();
        m_renderState.projection = projectionMatrix();
    }
    
    m_renderState.modelview = GLKMatrix4Translate(m_renderState.modelview, m_pos.x, m_pos.y, m_pos.z);
    
    if(m_yScale <= AGStyle::open_squeezeHeight) m_xScale.update(dt);
    if(m_xScale >= 0.99f) m_yScale.update(dt);
    
    m_renderState.modelview = GLKMatrix4Scale(m_renderState.modelview,
                                              m_yScale <= AGStyle::open_squeezeHeight ? (float)m_xScale : 1.0f,
                                              m_xScale >= 0.99f ? (float)m_yScale : AGStyle::open_squeezeHeight,
                                              1);
}

void AGFileBrowser::render()
{
    // draw inner box
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &AGStyle::frameBackgroundColor());
    drawTriangleFan((GLvertex3f[]){
        { -m_size.x/2, -m_size.y/2, 0 },
        {  m_size.x/2, -m_size.y/2, 0 },
        {  m_size.x/2,  m_size.y/2, 0 },
        { -m_size.x/2,  m_size.y/2, 0 },
    }, 4);
    
    // draw outer frame
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &AGStyle::foregroundColor);
    glLineWidth(4.0f);
    drawLineLoop((GLvertex3f[]){
        { -m_size.x/2, -m_size.y/2, 0 },
        {  m_size.x/2, -m_size.y/2, 0 },
        {  m_size.x/2,  m_size.y/2, 0 },
        { -m_size.x/2,  m_size.y/2, 0 },
    }, 4);
    
    AGInteractiveObject::render();
}

void AGFileBrowser::renderOut()
{
    m_xScale = lincurvef(AGStyle::open_animTimeX/2, 1, AGStyle::open_squeezeHeight);
    m_yScale = lincurvef(AGStyle::open_animTimeY/2, 1, AGStyle::open_squeezeHeight);
}

bool AGFileBrowser::finishedRenderingOut()
{
    return m_xScale <= AGStyle::open_squeezeHeight;
}

void AGFileBrowser::touchDown(const AGTouchInfo &t)
{
    
}

void AGFileBrowser::touchMove(const AGTouchInfo &t)
{
    
}

void AGFileBrowser::touchUp(const AGTouchInfo &t)
{
    
}


void AGFileBrowser::setPosition(const GLvertex3f &position)
{
    m_pos = position;
}

GLvertex3f AGFileBrowser::position()
{
    return m_pos;
}

void AGFileBrowser::setSize(const GLvertex2f &size)
{
    m_size = size;
}

GLvertex2f AGFileBrowser::size()
{
    return m_size;
}

void AGFileBrowser::setDirectoryPath(const string &directoryPath)
{
    
}

string AGFileBrowser::selectedFile() const
{
    return m_file;
}

void AGFileBrowser::onChooseFile(const std::function<void (const string &)> &choose)
{
    
}

void AGFileBrowser::onCancel(const std::function<void (void)> &cancel)
{
    
}

/*
 Filter function takes filepath as an argument and returns whether or not
 to display that file.
 */
void AGFileBrowser::setFilter(const std::function<bool (const string &)> &filter)
{
    
}

