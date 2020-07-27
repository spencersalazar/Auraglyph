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
#include "AGDef.h"
#include "AGStyle.h"
#include "AGUINodeEditor.h"

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
m_actionBlock(nil), m_action([](){ })
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
    if(m_actionBlock != nil) Block_release(m_actionBlock);
    m_actionBlock = nil;
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
    
    GLKMatrix4 proj = projection();
    GLKMatrix4 modelView = modelview();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    GLKMatrix4 textMV = GLKMatrix4Translate(modelView, m_size.x/2-text->width(m_title)*textScale/2, m_size.y/2-text->height()*textScale/2*1.25, 0);
//    GLKMatrix4 textMV = modelView;
    textMV = GLKMatrix4Scale(textMV, textScale, textScale, textScale);
    
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setProjectionMatrix(proj);
    shader.setModelViewMatrix(modelView);
    shader.setNormalMatrix(GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL));
    
    GLcolor4f color = AGStyle::foregroundColor().withAlpha(m_renderState.alpha);
    GLcolor4f blackA = AGStyle::darkColor().blend(1, 1, 1, m_renderState.alpha*0.75);
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glVertexAttrib4fv(AGVertexAttribColor, (const float *) &color);
    glDisableVertexAttribArray(AGVertexAttribColor);
    
    glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(AGVertexAttribNormal);
    
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
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &blackA);
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        
        glLineWidth(2.0);
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &color);
        glDrawArrays(GL_LINE_LOOP, 0, 4);
        
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &AGStyle::frameBackgroundColor());
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
        m_action();
    }
}

void AGUIButton::touchMove(const GLvertex3f &t)
{
    m_hit = (m_hitOnTouchDown && hitTest(t) == this);
}

void AGUIButton::touchUp(const GLvertex3f &t)
{
    if(m_interactionType == INTERACTION_UPDOWN && m_hit)
        m_action();
    
    m_hit = false;
}

GLvrectf AGUIButton::effectiveBounds()
{
    return GLvrectf(m_pos, m_pos+m_size);
}

void AGUIButton::setAction(void (^action)())
{
    m_actionBlock = Block_copy(action);
    m_action = [this](){ m_actionBlock(); };
}

void AGUIButton::setAction(const std::function<void ()>& action)
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

void AGUIButton::setTitle(const std::string &title)
{
    m_title = title;
}

const std::string &AGUIButton::title()
{
    return m_title;
}


AGUIButton *AGUIButton::makePinButton(AGUINodeEditor *nodeEditor)
{
    float w = 20;
    float h = 20;
    float f = 0.9f; // fraction of size occupied by pin icon
    
    AGUIIconButton *pinButton = new AGUIIconButton(GLvertex2f(0, 0), GLvertex2f(w, h), vector<GLvertex3f>({
        { -w/2*f, -h/2*f, 0 },
        { w/2*f, h/2*f, 0 },
    }), GL_LINES);
    
    pinButton->init();
    pinButton->setInteractionType(AGUIButton::INTERACTION_LATCH);
    pinButton->setIconMode(AGUIIconButton::ICONMODE_SQUARE);
    
    if(nodeEditor != nullptr)
    {
        pinButton->setAction(^{
            nodeEditor->pin(pinButton->isPressed());
        });
    }
    
    return pinButton;
}

AGUIButton *AGUIButton::makeCheckButton()
{
    float w = 20;
    float h = 20;
    
    AGUIIconButton *checkButton = new AGUIIconButton(GLvertex2f(0, 0), GLvertex2f(w, h), vector<GLvertex3f>({
    }), GL_LINE_STRIP);
    
    checkButton->init();
    checkButton->setInteractionType(AGUIButton::INTERACTION_LATCH);
    checkButton->setIconMode(AGUIIconButton::ICONMODE_SQUARE);
    
    return checkButton;
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
        
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
        glEnableVertexAttribArray(AGVertexAttribPosition);
        
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &AGStyle::lightColor());
        glDisableVertexAttribArray(AGVertexAttribColor);
        
        glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
        glDisableVertexAttribArray(AGVertexAttribNormal);
        
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
m_iconInfo(iconRenderInfo),
m_iconGeoType(0)
{
    m_boxGeo = NULL;
    setIconMode(ICONMODE_SQUARE);
}

AGUIIconButton::AGUIIconButton(const GLvertex3f &pos, const GLvertex2f &size,
                               const vector<GLvertex3f> &iconGeo, int geoType) :
AGUIButton("", pos, size),
m_iconGeo(iconGeo),
m_iconGeoType(geoType)
{
    m_boxGeo = NULL;
    setIconMode(ICONMODE_SQUARE);
}

AGUIIconButton::~AGUIIconButton()
{
    SAFE_DELETE_ARRAY(m_boxGeo);
}

void AGUIIconButton::setIconMode(AGUIIconButton::IconMode m)
{
    m_iconMode = m;
    
    if(m_iconMode == ICONMODE_SQUARE)
    {
        SAFE_DELETE_ARRAY(m_boxGeo);
        
        m_boxGeo = new GLvertex3f[4];
        GeoGen::makeRect(m_boxGeo, m_size.x, m_size.y);
    }
    else if (m_iconMode == ICONMODE_CIRCLE)
    {
        SAFE_DELETE_ARRAY(m_boxGeo);
        
        m_boxGeo = new GLvertex3f[48];
        GeoGen::makeCircle(m_boxGeo, 48, m_size.x/2);
    }
}

AGUIIconButton::IconMode AGUIIconButton::getIconMode()
{
    return m_iconMode;
}

void AGUIIconButton::blink(bool blink)
{
    m_blink.activate(blink);
}

void AGUIIconButton::update(float t, float dt)
{
    AGRenderObject::update(t, dt);
    
    GLKMatrix4 parentModelview;
    if(m_parent) parentModelview = m_parent->m_renderState.modelview;
    else if(renderFixed()) parentModelview = AGRenderObject::fixedModelViewMatrix();
    else parentModelview = AGRenderObject::globalModelViewMatrix();
    
    m_renderState.modelview = GLKMatrix4Translate(parentModelview, m_pos.x, m_pos.y, m_pos.z);
    m_renderState.normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_renderState.modelview), NULL);
    
    m_blink.update(t, dt);
}

void AGUIIconButton::render()
{
    // bypass AGUIButton::render()
    
    glLineWidth(2.0);

    if(m_iconMode == ICONMODE_SQUARE)
    {
        AGStyle::lightColor().withAlpha(m_renderState.alpha).set();
        // fill square
        if(isPressed()) drawTriangleFan(m_boxGeo, 4);
        // stroke square
        else drawLineLoop(m_boxGeo, 4);
    }
    else if(m_iconMode == ICONMODE_CIRCLE)
    {
        if(isPressed() && !(m_latch && m_blink.isActive())) {
            // fill circle
            AGStyle::lightColor().withAlpha(m_renderState.alpha).set();
            drawTriangleFan(m_boxGeo, 48);
        } else if (m_blink.isActive()) {
            // blink
            // even if pressed in latch mode
            m_blink.backgroundColor().withAlpha(m_renderState.alpha).set();
            drawTriangleFan(m_boxGeo, 48);
            AGStyle::lightColor().withAlpha(m_renderState.alpha).set();
            drawLineLoop(m_boxGeo+1, 47);
        } else {
            // stroke circle + fill circle in bg color
            AGStyle::frameBackgroundColor().withAlpha(m_renderState.alpha).set();
            drawTriangleFan(m_boxGeo, 48);
            AGStyle::lightColor().withAlpha(m_renderState.alpha).set();
            drawLineLoop(m_boxGeo+1, 47);
        }
    }
    
    if(isPressed() && !(m_latch && m_blink.isActive()))
        AGStyle::darkColor().withAlpha(m_renderState.alpha).set();
    else if (m_blink.isActive())
        m_blink.foregroundColor().withAlpha(m_renderState.alpha).set();
    else
        AGStyle::lightColor().withAlpha(m_renderState.alpha).set();
    
    if(m_iconGeo.size())
        drawGeometry(m_iconGeo.data(), m_iconGeo.size(), m_iconGeoType);
    else
        drawGeometry(m_iconInfo.geo, m_iconInfo.numVertex, m_iconInfo.geoType);
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
    for(auto action : m_actions)
        Block_release(action);
    m_actions.clear();
}

void AGUIButtonGroup::addButton(AGUIButton *button, void (^action)(), bool isDefault)
{
    button->setLatched(isDefault);
    m_buttons.push_back(button);
    m_actions.push_back(Block_copy(action));
    addChild(button);
    
    button->setAction(^{
        itmap(m_buttons, ^(AGUIButton *&_b) {
            if(_b == button)
                _b->setLatched(true);
            else
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
    m_tex = loadOrRetrieveTexture("trash.png");
    
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
    AGRenderObject::update(t, dt);
    
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
    GLKMatrix4 modelView = GLKMatrix4Translate(AGNode::fixedModelViewMatrix(), m_pos.x, m_pos.y, m_pos.z);
    modelView = GLKMatrix4Scale(modelView, m_scale, m_scale, m_scale);
    
    AGGenericShader &shader = AGTextureShader::instance();
    
    shader.useProgram();
    
    shader.setProjectionMatrix(proj);
    shader.setModelViewMatrix(modelView);
    shader.setNormalMatrix(GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL));
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    GLcolor4f color;
    if(m_active)
        color = AGStyle::errorColor();
    else
        color = AGStyle::foregroundColor();
    color.a = m_renderState.alpha;

    glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
    color.set();
    
    glEnable(GL_TEXTURE_2D);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, m_tex);
    glVertexAttribPointer(AGVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLvertex2f), m_uv);
    glEnableVertexAttribArray(AGVertexAttribTexCoord0);
    
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
    if((t-m_pos).magnitudeSquared() < m_radius*m_radius)
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
    m_renderInfo.color = AGStyle::foregroundColor();
    m_renderInfo.lineWidth = 4.0;
    
    m_renderList.push_back(&m_renderInfo);
}

void AGUITrace::addPoint(const GLvertex3f &v)
{
    m_traceGeo.push_back(v);
    m_renderInfo.numVertex = (int) m_traceGeo.size();
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
: m_text(text)
{
    setPosition(position);
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
    
    GLcolor4f valueColor = AGStyle::foregroundColor().withAlpha(m_renderState.alpha);
    
    GLKMatrix4 valueMV = modelView;
    valueMV = GLKMatrix4Translate(valueMV, m_pos.x, m_pos.y, m_pos.z);
    valueMV = GLKMatrix4Translate(valueMV, -m_textSize.x/2, -m_textSize.y/2, 0);
    valueMV = GLKMatrix4Scale(valueMV, AGUILabel_TextScale, AGUILabel_TextScale, AGUILabel_TextScale);
    text->render(m_text, valueColor, valueMV, proj);
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


