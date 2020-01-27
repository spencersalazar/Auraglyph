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

const static float AGMenu_ItemSpacing = 1.2f;
const static float AGMenu_TextScale = 0.55f;
const static float AGMenu_ItemInset = 5;
const static float AGMenu_TextOffset = 5;

AGMenu::AGMenu(const GLvertex3f &pos, const GLvertex2f &size)
: m_size(size)
{
    setPosition(pos);
    
    //GeoGen::makeCircle(m_frameGeo, 48, size.x/2);
    m_frameGeo = {
        { -size.x/2, -size.y/2, 0 },
        { -size.x/2,  size.y/2, 0 },
        {  size.x/2,  size.y/2, 0 },
        {  size.x/2, -size.y/2, 0 },
    };
    
    m_itemsAlpha = powcurvef(0, 1, 0.5, 4);
    m_itemsAlpha.forceTo(0);
}

AGMenu::~AGMenu()
{
}

void AGMenu::setIcon(GLvertex3f *geo, unsigned long num, GLint kind)
{
    m_iconGeo = std::vector<GLvertex3f>(geo, geo+num);
    m_iconGeoKind = kind;
}

void AGMenu::addMenuItem(const std::string &title, const std::function<void ()> &action)
{
    m_items.push_back({ title, action });
    
    TexFont *text = AGStyle::standardFont64();
    float textScale = 0.55f;
    float textWidth = text->width(title)*textScale;
    if(textWidth > m_maxTextWidth)
        m_maxTextWidth = textWidth;
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
    
    m_itemsAlpha.update(dt);
}

void AGMenu::render()
{
    glLineWidth(2.0);
    
    if(!m_open)
    {
        AGStyle::frameBackgroundColor().withAlpha(m_renderState.alpha).set();
        // draw frame background (fill rect)
        drawTriangleFan(m_frameGeo.data(), m_frameGeo.size());
        
        AGStyle::foregroundColor().withAlpha(m_renderState.alpha).set();
        // draw frame (stroke rect)
        drawLineLoop(m_frameGeo.data(), m_frameGeo.size());
        // draw icon
        drawGeometry(m_iconGeo.data(), m_iconGeo.size(), m_iconGeoKind);
    }
    else
    {
        AGStyle::foregroundColor().withAlpha(m_renderState.alpha).set();
        // draw frame (fill circle)
        drawGeometry(m_frameGeo.data(), m_frameGeo.size(), GL_TRIANGLE_FAN);
        
        // draw icon (inverted color)
        AGStyle::frameBackgroundColor().withAlpha(m_renderState.alpha).set();
        drawGeometry(m_iconGeo.data(), m_iconGeo.size(), m_iconGeoKind);
    }
    
    if(m_open || m_itemsAlpha > 0.001)
    {
        TexFont *text = AGStyle::standardFont64();
        
        // draw menu items background
        AGStyle::frameBackgroundColor().blend(1, 1, 1, m_renderState.alpha*m_itemsAlpha).set();
        
        float top = -m_size.y/2;
        float bottom = -m_size.y/2-m_size.y*(m_items.size())*AGMenu_ItemSpacing-5;
        float left = -m_size.x/2-5;
        float itemsWidth = max(m_maxTextWidth+AGMenu_TextOffset*2+AGMenu_ItemInset*2, m_size.x);
        float right = -m_size.x/2+itemsWidth+5;
        
        // fill background
        drawTriangleFan((GLvertex3f[]) {
            { left, bottom, 0},
            { right, bottom, 0},
            { right, top, 0},
            { left, top, 0},
        }, 4);
        
        // draw menu items
        for(int i = 0; i < m_items.size(); i++)
        {
            float itemHeight = -m_size.y*(i+1)*AGMenu_ItemSpacing;
            
            GLcolor4f fgColor;
            GLcolor4f bgColor;
            if(i != m_selectedItem)
            {
                fgColor = AGStyle::foregroundColor();
                bgColor = AGStyle::backgroundColor(); // not actually used
            }
            else
            {
                fgColor = AGStyle::backgroundColor();
                bgColor = AGStyle::foregroundColor();
            }
            
            fgColor.a = m_itemsAlpha*m_renderState.alpha;
            bgColor.a = m_itemsAlpha*m_renderState.alpha;
            
            if(i == m_selectedItem)
            {
                bgColor.set();
                GLvrectf r = this->_boundingBoxForItem(i);
                drawTriangleFan((GLvertex3f[]) {
                    { r.bl.x, r.bl.y, m_pos.z },
                    { r.br.x, r.br.y, m_pos.z },
                    { r.ur.x, r.ur.y, m_pos.z },
                    { r.ul.x, r.ul.y, m_pos.z },
                }, 4);
            }
            
            glLineWidth(4.0);
            fgColor.set();
            
            // draw bar on left side
            drawLineStrip((GLvertex2f[]) {
                { -m_size.x/2+AGMenu_ItemInset, itemHeight + m_size.y/2 },
                { -m_size.x/2+AGMenu_ItemInset, itemHeight - m_size.y/2 },
            }, 2);
            
            // render item title
            GLKMatrix4 modelView = m_renderState.modelview;
            float textScale = AGMenu_TextScale;
            float textHeight = text->ascender()*textScale;
            float offset = AGMenu_TextOffset+AGMenu_ItemInset;
            
            // left-align + center vertically
            modelView = GLKMatrix4Translate(modelView, -m_size.x/2+offset, itemHeight-textHeight/2-text->descender()*textScale, 0);
//             modelView = GLKMatrix4Translate(modelView, -m_size.x/2+5, itemHeight-text->descender(), 0);
            modelView = GLKMatrix4Scale(modelView, textScale, textScale, textScale);
            text->render(m_items[i].title, fgColor, modelView, m_renderState.projection);
        }
    }
}

void AGMenu::touchDown(const AGTouchInfo &t)
{
    if(pointInRectangle(t.position.xy(), m_pos.xy()-m_size/2, m_pos.xy()+m_size/2))
    {
        m_open = true;
        m_leftTab = false;
        m_itemsAlpha.reset(0, 1);
    }
}

void AGMenu::touchMove(const AGTouchInfo &t)
{
    if(!m_leftTab)
    {
        if(!pointInRectangle(t.position.xy(), m_pos.xy()-m_size/2, m_pos.xy()+m_size/2))
            m_leftTab = true;
    }
    else
    {
        m_selectedItem = -1;
        GLvertex3f relPos = t.position-m_pos;
        for(int i = 0; i < m_items.size(); i++)
        {
            GLvrectf r = this->_boundingBoxForItem(i);
            if(pointInRectangle(relPos.xy(), r.bl.xy(), r.ur.xy()))
            {
                m_selectedItem = i;
                //dbgprint("AGMenu: %s\n", m_items[i].title.c_str());
                break;
            }
        }
    }
}

void AGMenu::touchUp(const AGTouchInfo &t)
{
//    if(m_leftTab || !pointInRectangle(t.position.xy(), m_pos.xy()-m_size/2, m_pos.xy()+m_size/2))
    {
        m_open = false;
        m_selectedItem = -1;
        m_itemsAlpha.reset(1, 0);
        
        GLvertex3f relPos = t.position-m_pos;
        for(int i = 0; i < m_items.size(); i++)
        {
            GLvrectf r = this->_boundingBoxForItem(i);
            if(pointInRectangle(relPos.xy(), r.bl.xy(), r.ur.xy()))
            {
                m_items[i].action();
                //dbgprint("AGMenu: %s\n", m_items[i].title.c_str());
                break;
            }
        }
    }
}

void AGMenu::touchedOutside()
{
    
}

AGInteractiveObject *AGMenu::hitTest(const GLvertex3f &t)
{
    if(pointInCircle(t.xy(), m_pos.xy(), m_size.x/2))
        return this;
    return NULL;
}

GLvrectf AGMenu::_boundingBoxForItem(int item)
{
    float centerY = -m_size.y*(item+1)*AGMenu_ItemSpacing;
    float top = centerY+m_size.y/2*AGMenu_ItemSpacing;
    float bottom = centerY-m_size.y/2*AGMenu_ItemSpacing;
    float left = -m_size.x/2;
    float itemsWidth = max(m_maxTextWidth+AGMenu_TextOffset*2+AGMenu_ItemInset*2, m_size.x);
    float right = -m_size.x/2+itemsWidth;
    float z = 0;
    
    return GLvrectf({ left, bottom, z }, { right, top, z});
}

