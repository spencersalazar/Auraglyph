//
//  AGUserInterface.mm
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#include "AGUserInterface.h"
#include "AGNode.h"
#include "AGAudioNode.h"
#include "AGGenericShader.h"
#include "AGHandwritingRecognizer.h"
#include "AGViewController.h"
#include "AGDef.h"
#include "AGStyle.h"

#include "TexFont.h"
#include "Texture.h"
#include "ES2Render.h"
#include "GeoGenerator.h"
#include "spstl.h"


//------------------------------------------------------------------------------
// ### AGUIButton ###
//------------------------------------------------------------------------------
#pragma mark - AGUIButton

AGUIButton::AGUIButton(const std::string &title, const GLvertex3f &pos, const GLvertex3f &size) :
m_action(nil)
{
    m_hit = m_hitOnTouchDown = m_latch = false;
    m_interactionType = INTERACTION_UPDOWN;
    
    m_title = title;
    
    m_pos = pos;
    m_size = size;
    m_geo[0] = GLvertex3f(0, 0, 0);
    m_geo[1] = GLvertex3f(size.x, 0, 0);
    m_geo[2] = GLvertex3f(size.x, size.y, 0);
    m_geo[3] = GLvertex3f(0, size.y, 0);
    
    float stripeInset = 0.0002*AGStyle::oldGlobalScale;
    
    m_geo[4] = GLvertex3f(stripeInset, stripeInset, 0);
    m_geo[5] = GLvertex3f(size.x-stripeInset, stripeInset, 0);
    m_geo[6] = GLvertex3f(size.x-stripeInset, size.y-stripeInset, 0);
    m_geo[7] = GLvertex3f(stripeInset, size.y-stripeInset, 0);
}

AGUIButton::~AGUIButton()
{
    if(m_action != nil) Block_release(m_action);
    m_action = nil;
}

void AGUIButton::update(float t, float dt)
{
    AGInteractiveObject::update(t, dt);
}

void AGUIButton::render()
{
    TexFont *text = AGStyle::standardFont64();
    
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    float textScale = 0.5;
    
    GLKMatrix4 proj = AGNode::projectionMatrix();
    GLKMatrix4 modelView;
    if(renderFixed())
        modelView = AGNode::fixedModelViewMatrix();
    else
        modelView = AGNode::globalModelViewMatrix();
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    GLKMatrix4 textMV = GLKMatrix4Translate(modelView, m_size.x/2-text->width(m_title)*textScale/2, m_size.y/2-text->height()*textScale/2*1.25, 0);
//    GLKMatrix4 textMV = modelView;
    textMV = GLKMatrix4Scale(textMV, textScale, textScale, textScale);
    
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setProjectionMatrix(proj);
    shader.setModelViewMatrix(modelView);
    shader.setNormalMatrix(GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL));
    
    GLcolor4f color = GLcolor4f::white;
    color.a = m_renderState.alpha;

    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(GLKVertexAttribNormal);
    
    if(isPressed())
    {
        glLineWidth(4.0);
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        
        color = AGStyle::darkColor();
        color.a = m_renderState.alpha;
        
        text->render(m_title, color, textMV, proj);
        
        // restore "default" line width
        glLineWidth(2.0);
    }
    else
    {
        glLineWidth(2.0);
        glDrawArrays(GL_LINE_LOOP, 0, 4);
        
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::black);
        glDrawArrays(GL_LINE_LOOP, 4, 4);
        
        color = AGStyle::lightColor();
        color.a = m_renderState.alpha;
        
        text->render(m_title, color, textMV, proj);
    }
}


void AGUIButton::touchDown(const GLvertex3f &t)
{
    m_hit = true;
    m_hitOnTouchDown = true;
    
    if(m_interactionType == INTERACTION_LATCH)
    {
        m_latch = !m_latch;
        if(m_action)
            m_action();
    }
}

void AGUIButton::touchMove(const GLvertex3f &t)
{
    m_hit = (m_hitOnTouchDown && hitTest(t) == this);
}

void AGUIButton::touchUp(const GLvertex3f &t)
{
    if(m_interactionType == INTERACTION_UPDOWN && m_hit && m_action)
        m_action();
    
    m_hit = false;
}

GLvrectf AGUIButton::effectiveBounds()
{
    return GLvrectf(m_pos, m_pos+m_size);
}

void AGUIButton::setAction(void (^action)())
{
    m_action = action;
}

bool AGUIButton::isPressed()
{
    if(m_interactionType == INTERACTION_UPDOWN)
        return m_hit;
    else
        return m_latch;
}

void AGUIButton::setLatched(bool latched)
{
    m_latch = latched;
}


//------------------------------------------------------------------------------
// ### AGUITextButton ###
//------------------------------------------------------------------------------
#pragma mark - AGUITextButton

void AGUITextButton::render()
{
    TexFont *text = AGStyle::standardFont64();

    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    float textScale = 1;
    
    GLKMatrix4 proj = AGNode::projectionMatrix();
    GLKMatrix4 modelView = GLKMatrix4Translate(AGNode::fixedModelViewMatrix(), m_pos.x, m_pos.y, m_pos.z);
    GLKMatrix4 textMV = GLKMatrix4Translate(modelView, m_size.x/2-text->width(m_title)*textScale/2, m_size.y/2-text->height()*textScale/2*1.25, 0);
    //    GLKMatrix4 textMV = modelView;
    textMV = GLKMatrix4Scale(textMV, textScale, textScale, textScale);
    
    if(isPressed())
    {
        AGGenericShader &shader = AGGenericShader::instance();
        
        shader.useProgram();
        
        shader.setProjectionMatrix(proj);
        shader.setModelViewMatrix(modelView);
        
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &AGStyle::lightColor());
        glDisableVertexAttribArray(GLKVertexAttribColor);
        
        glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
        glDisableVertexAttribArray(GLKVertexAttribNormal);
        
        glLineWidth(4.0);
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    }
    
    text->render(m_title, AGStyle::lightColor(), textMV, proj);
}


//------------------------------------------------------------------------------
// ### AGUIIconButton ###
//------------------------------------------------------------------------------
#pragma mark - AGUIIconButton
AGUIIconButton::AGUIIconButton(const GLvertex3f &pos, const GLvertex2f &size, const AGRenderInfoV &iconRenderInfo) :
AGUIButton("", pos, size),
m_iconInfo(iconRenderInfo)
{
    m_boxGeo = NULL;
    setIconMode(ICONMODE_SQUARE);
    
    m_boxInfo.color = AGStyle::lightColor();
    m_renderList.push_back(&m_boxInfo);
    
    m_renderList.push_back(&m_iconInfo);
}

void AGUIIconButton::setIconMode(AGUIIconButton::IconMode m)
{
    m_iconMode = m;
    
    if(m_iconMode == ICONMODE_SQUARE)
    {
        SAFE_DELETE_ARRAY(m_boxGeo);
        
        m_boxGeo = new GLvertex3f[4];
        GeoGen::makeRect(m_boxGeo, m_size.x, m_size.y);
        
        m_boxInfo.geo = m_boxGeo;
        m_boxInfo.geoType = GL_TRIANGLE_FAN;
        m_boxInfo.numVertex = 4;
    }
    else if (m_iconMode == ICONMODE_CIRCLE)
    {
        SAFE_DELETE_ARRAY(m_boxGeo);
        
        m_boxGeo = new GLvertex3f[48];
        GeoGen::makeCircle(m_boxGeo, 48, m_size.x/2);
        
        m_boxInfo.geo = m_boxGeo;
        m_boxInfo.geoType = GL_LINE_LOOP;
        m_boxInfo.numVertex = 48;
        m_boxInfo.geoOffset = 1;
    }
}

AGUIIconButton::IconMode AGUIIconButton::getIconMode()
{
    return m_iconMode;
}

void AGUIIconButton::update(float t, float dt)
{
    AGInteractiveObject::update(t, dt);
    
    GLKMatrix4 parentModelview;
    if(m_parent) parentModelview = m_parent->m_renderState.modelview;
    else if(renderFixed()) parentModelview = AGRenderObject::fixedModelViewMatrix();
    else parentModelview = AGRenderObject::globalModelViewMatrix();
    
    m_renderState.modelview = GLKMatrix4Translate(parentModelview, m_pos.x, m_pos.y, m_pos.z);
    m_renderState.normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_renderState.modelview), NULL);
    
    if(isPressed())
    {
        m_iconInfo.color = AGStyle::darkColor();
        m_boxInfo.geoType = GL_TRIANGLE_FAN;
        m_boxInfo.geoOffset = 0;
        m_boxInfo.numVertex = (m_iconMode == ICONMODE_CIRCLE ? 48 : 4);
    }
    else
    {
        m_iconInfo.color = AGStyle::lightColor();
        m_boxInfo.geoType = GL_LINE_LOOP;
        m_boxInfo.geoOffset = (m_iconMode == ICONMODE_CIRCLE ? 1 : 0);
        m_boxInfo.numVertex = (m_iconMode == ICONMODE_CIRCLE ? 47 : 4);
    }
}

void AGUIIconButton::render()
{
    // bypass AGUIButton::render()
    
    glLineWidth(2.0);

    AGInteractiveObject::render();
}




//------------------------------------------------------------------------------
// ### AGUIButtonGroup ###
//------------------------------------------------------------------------------
#pragma mark - AGUIButtonGroup

AGUIButtonGroup::AGUIButtonGroup()
{
}

AGUIButtonGroup::~AGUIButtonGroup()
{
}

void AGUIButtonGroup::addButton(AGUIButton *button, void (^action)(), bool isDefault)
{
    button->setLatched(isDefault);
    m_buttons.push_back(button);
    addChild(button);
    
    button->setAction(^{
        itmap(m_buttons, ^(AGUIButton *&_b) {
            if(_b != button)
                _b->setLatched(false);
        });
        
        if(action != NULL)
            action();
    });
}




//------------------------------------------------------------------------------
// ### AGUITrash ###
//------------------------------------------------------------------------------
#pragma mark - AGUITrash

AGUITrash &AGUITrash::instance()
{
    static AGUITrash s_trash;
    s_trash.init();
    
    return s_trash;
}

AGUITrash::AGUITrash()
{
    m_tex = loadOrRetrieveTexture(@"trash.png");
    
    m_radius = 0.005*AGStyle::oldGlobalScale;
    m_geo[0] = GLvertex3f(-m_radius, -m_radius, 0);
    m_geo[1] = GLvertex3f( m_radius, -m_radius, 0);
    m_geo[2] = GLvertex3f(-m_radius,  m_radius, 0);
    m_geo[3] = GLvertex3f( m_radius,  m_radius, 0);
    
    m_uv[0] = GLvertex2f(0, 0);
    m_uv[1] = GLvertex2f(1, 0);
    m_uv[2] = GLvertex2f(0, 1);
    m_uv[3] = GLvertex2f(1, 1);
    
    m_active = false;

    m_scale.value = 0.5;
    m_scale.target = 1;
    m_scale.rate = 0.1;
}

AGUITrash::~AGUITrash()
{
    
}

void AGUITrash::update(float t, float dt)
{
    AGInteractiveObject::update(t, dt);
    
    if(m_active)
        m_scale = 1.25;
    else
        m_scale = 1;
    
    m_scale.interp();
}

void AGUITrash::render()
{
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    GLKMatrix4 proj = AGNode::projectionMatrix();
    GLKMatrix4 modelView = GLKMatrix4Translate(AGNode::fixedModelViewMatrix(), m_position.x, m_position.y, m_position.z);
    modelView = GLKMatrix4Scale(modelView, m_scale, m_scale, m_scale);
    
    AGGenericShader &shader = AGTextureShader::instance();
    
    shader.useProgram();
    
    shader.setProjectionMatrix(proj);
    shader.setModelViewMatrix(modelView);
    shader.setNormalMatrix(GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL));
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    
    GLcolor4f color;
    if(m_active)
        color = GLcolor4f::red;
    else
        color = GLcolor4f::white;
    color.a = m_renderState.alpha;

    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    if(m_active)
        glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &color);
    else
        glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &color);
    
    glEnable(GL_TEXTURE_2D);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, m_tex);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLvertex2f), m_uv);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

void AGUITrash::touchDown(const GLvertex3f &t)
{
    
}

void AGUITrash::touchMove(const GLvertex3f &t)
{
    
}

void AGUITrash::touchUp(const GLvertex3f &t)
{
    
}

AGUIObject *AGUITrash::hitTest(const GLvertex3f &t)
{
    // point in circle
    if((t-m_position).magnitudeSquared() < m_radius*m_radius)
        return this;
    return NULL;
}

void AGUITrash::activate()
{
    m_active = true;
}

void AGUITrash::deactivate()
{
    m_active = false;
}


/*------------------------------------------------------------------------------
 - AGUITrace -
 -----------------------------------------------------------------------------*/
#pragma mark - AGUITrace

AGUITrace::AGUITrace()
{
    m_renderInfo.numVertex = 0;
    m_renderInfo.geo = m_traceGeo.data();
    m_renderInfo.geoType = GL_LINE_STRIP;
    m_renderInfo.geoOffset = 0;
    m_renderInfo.color = GLcolor4f::white;
    m_renderInfo.lineWidth = 4.0;
    
    m_renderList.push_back(&m_renderInfo);
}

void AGUITrace::addPoint(const GLvertex3f &v)
{
    m_traceGeo.push_back(v);
    m_renderInfo.numVertex = m_traceGeo.size();
    m_renderInfo.geo = m_traceGeo.data();
}

const vector<GLvertex3f> AGUITrace::points() const
{
    return m_traceGeo;
}



/*------------------------------------------------------------------------------
 - AGUILabel -
 -----------------------------------------------------------------------------*/
#pragma mark - AGUILabel

static const float AGUILabel_TextScale = 0.61f;

AGUILabel::AGUILabel(const GLvertex3f &position, const string &text)
: m_text(text), m_position(position)
{
    TexFont *texFont = AGStyle::standardFont64();
    
    m_textSize.x = texFont->width(m_text)*AGUILabel_TextScale;
    m_textSize.y = texFont->height()*AGUILabel_TextScale;
}

AGUILabel::~AGUILabel()
{
    
}

void AGUILabel::update(float t, float dt)
{
    AGRenderObject::update(t, dt);
}

void AGUILabel::render()
{
    TexFont *text = AGStyle::standardFont64();
    
    GLKMatrix4 modelView;
    GLKMatrix4 proj;
    
    if(parent())
    {
        modelView = parent()->m_renderState.modelview;
        proj = parent()->m_renderState.projection;
    }
    else
    {
        modelView = globalModelViewMatrix();
        proj = projectionMatrix();
    }
    
    GLcolor4f valueColor = GLcolor4f::white;
    valueColor.a = m_renderState.alpha;
    
    GLKMatrix4 valueMV = modelView;
    valueMV = GLKMatrix4Translate(valueMV, m_position.x, m_position.y, m_position.z);
    valueMV = GLKMatrix4Translate(valueMV, -m_textSize.x/2, -m_textSize.y/2, 0);
    valueMV = GLKMatrix4Scale(valueMV, AGUILabel_TextScale, AGUILabel_TextScale, AGUILabel_TextScale);
    text->render(m_text, valueColor, valueMV, proj);
}

void AGUILabel::setPosition(const GLvertex3f &position)
{
    m_position = position;
}

GLvertex3f AGUILabel::position()
{
    return m_position;
}

GLvertex2f AGUILabel::size()
{
    return m_size;
}

void AGUILabel::setSize(const GLvertex2f &size)
{
    m_size = size;
}

GLvertex2f AGUILabel::naturalSize() const
{
    return m_textSize;
}


