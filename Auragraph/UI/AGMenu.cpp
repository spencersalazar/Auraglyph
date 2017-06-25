//
//  AGMenu.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 6/24/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGMenu.h"
#include "GeoGenerator.h"
#include "AGStyle.h"

AGMenu::AGMenu(const GLvertex3f &pos, const GLvertex2f &size)
: m_pos(pos), m_size(size)
{
    //GeoGen::makeCircle(m_frameGeo, 48, size.x/2);
    m_frameGeo = {
        { -size.x/2, -size.y/2, 0 },
        { -size.x/2,  size.y/2, 0 },
        {  size.x/2,  size.y/2, 0 },
        {  size.x/2, -size.y/2, 0 },
    };
}

AGMenu::~AGMenu()
{
    
}

void AGMenu::setIcon(GLvertex3f *geo, int num, GLint kind)
{
    m_iconGeo = std::vector<GLvertex3f>(geo, geo+num);
    m_iconGeoKind = kind;
}

void AGMenu::addMenuItem(const std::string &title, const std::function<void ()> &action)
{
    m_items.push_back({ title, action });
}

void AGMenu::update(float t, float dt)
{
    AGInteractiveObject::update(t, dt);
    
    GLKMatrix4 parentModelview;
    if(m_parent) parentModelview = m_parent->m_renderState.modelview;
    else if(renderFixed()) parentModelview = AGRenderObject::fixedModelViewMatrix();
    else parentModelview = AGRenderObject::globalModelViewMatrix();
    
    m_renderState.modelview = GLKMatrix4Translate(parentModelview, m_pos.x, m_pos.y, m_pos.z);
    m_renderState.normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_renderState.modelview), NULL);
    
//    if(isPressed())
//    {
//        m_iconInfo.color = AGStyle::darkColor();
//        m_boxInfo.geoType = GL_TRIANGLE_FAN;
//        m_boxInfo.geoOffset = 0;
//        m_boxInfo.numVertex = (m_iconMode == ICONMODE_CIRCLE ? 48 : 4);
//    }
//    else
//    {
//        m_iconInfo.color = AGStyle::lightColor();
//        m_boxInfo.geoType = GL_LINE_LOOP;
//        m_boxInfo.geoOffset = (m_iconMode == ICONMODE_CIRCLE ? 1 : 0);
//        m_boxInfo.numVertex = (m_iconMode == ICONMODE_CIRCLE ? 47 : 4);
//    }
}

void AGMenu::render()
{
    glLineWidth(2.0);
    glVertexAttrib4fv(AGVertexAttribColor, (const float *) &AGStyle::foregroundColor);
    
    if(!m_open)
    {
        // draw frame (stroke circle)
        drawGeometry(m_frameGeo.data(), m_frameGeo.size(), GL_LINE_LOOP);
        // draw icon
        drawGeometry(m_iconGeo.data(), m_iconGeo.size(), m_iconGeoKind);
    }
    else
    {
        // draw frame (fill circle)
        drawGeometry(m_frameGeo.data(), m_frameGeo.size(), GL_TRIANGLE_FAN);
        // draw icon (inverted color)
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &AGStyle::backgroundColor);
        drawGeometry(m_iconGeo.data(), m_iconGeo.size(), m_iconGeoKind);
        
        TexFont *text = AGStyle::standardFont64();
        
        // draw menu items
        for(int i = 0; i < m_items.size(); i++)
        {
            float itemHeight = -m_size.y*(i+1)*1.2f;
            
            glLineWidth(4.0);
            glVertexAttrib4fv(AGVertexAttribColor, (const float *) &AGStyle::foregroundColor);

            drawLineStrip((GLvertex2f[]) {
                { -m_size.x/2, itemHeight + m_size.y/2 },
                { -m_size.x/2, itemHeight - m_size.y/2 },
            }, 2);
            
            GLKMatrix4 modelView = m_renderState.modelview;
            float textScale = 0.55;
            float textHeight = text->ascender()*textScale;
            // left-align + center vertically
            modelView = GLKMatrix4Translate(modelView, -m_size.x/2+5, itemHeight-textHeight/2-text->descender()*textScale, 0);
//             modelView = GLKMatrix4Translate(modelView, -m_size.x/2+5, itemHeight-text->descender(), 0);
            modelView = GLKMatrix4Scale(modelView, textScale, textScale, textScale);
            text->render(m_items[i].title, AGStyle::foregroundColor, modelView, m_renderState.projection);
        }
    }
}

void AGMenu::touchDown(const AGTouchInfo &t)
{
    if(pointInCircle(t.position.xy(), m_pos.xy(), m_size.x/2))
    {
        m_open = true;
    }
}

void AGMenu::touchMove(const AGTouchInfo &t)
{
    
}

void AGMenu::touchUp(const AGTouchInfo &t)
{
    m_open = false;
}

void AGMenu::touchOutside()
{
    
}

AGInteractiveObject *AGMenu::hitTest(const GLvertex3f &t)
{
    if(pointInCircle(t.xy(), m_pos.xy(), m_size.x/2))
        return this;
    return NULL;
}

