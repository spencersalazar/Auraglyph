//
//  AGAboutBox.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/5/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGAboutBox.h"
#include "AGViewController.h"

static const float AGABOUTBOX_RADIUS = 0.066;

static const float AGUIOpen_squeezeHeight = 0.00125;
static const float AGUIOpen_animTimeX = 0.4;
static const float AGUIOpen_animTimeY = 0.15;

//------------------------------------------------------------------------------
// ### AGAboutBox ###
//------------------------------------------------------------------------------
#pragma mark - AGAboutBox

TexFont *AGAboutBox::s_text = NULL;

AGAboutBox::AGAboutBox(const GLvertex3f &pos) :
m_pos(pos),
m_done(false),
m_closeAction(NULL)
{
    if(s_text == NULL)
    {
        const char *fontPath = [[AGViewController styleFontPath] UTF8String];
        s_text = new TexFont(fontPath, 64);
    }
    
    m_geoSize = 4;
    
    m_radius = AGABOUTBOX_RADIUS;
    
    // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
    m_geo[0] = GLvertex3f(-m_radius, m_radius, 0);
    m_geo[1] = GLvertex3f(-m_radius, -m_radius, 0);
    m_geo[2] = GLvertex3f(m_radius, -m_radius, 0);
    m_geo[3] = GLvertex3f(m_radius, m_radius, 0);
    
    m_xScale = lincurvef(AGUIOpen_animTimeX, AGUIOpen_squeezeHeight, 1);
    m_yScale = lincurvef(AGUIOpen_animTimeY, AGUIOpen_squeezeHeight, 1);
    
    m_lines.push_back("HANDWRITTEN COMPUTER MUSIC");
    m_lines.push_back("");
    m_lines.push_back("");
    m_lines.push_back("by Spencer Salazar");
    m_lines.push_back("Stanford University | CCRMA");
    m_lines.push_back("https://ccrma.stanford.edu/~spencer");
    m_lines.push_back("Copyright 2014");
    m_lines.push_back("All rights reserved");
    m_lines.push_back("");
    m_lines.push_back("");
    m_lines.push_back("Orbitron font");
    m_lines.push_back("Copyright Matt McInerney");
    m_lines.push_back("SIL Open Font License, 1.1");
}

AGAboutBox::~AGAboutBox()
{
    //[m_closeAction;
    m_closeAction = NULL;
}

void AGAboutBox::update(float t, float dt)
{
    AGInteractiveObject::update(t, dt);
    
    m_modelView = AGNode::fixedModelViewMatrix();
    m_projection = AGNode::projectionMatrix();
    
    m_modelView = GLKMatrix4Translate(m_modelView, m_pos.x, m_pos.y, m_pos.z);
    
    if(m_yScale <= AGUIOpen_squeezeHeight) m_xScale.update(dt);
    if(m_xScale >= 0.99f) m_yScale.update(dt);
    
    m_modelView = GLKMatrix4Scale(m_modelView,
                                  m_yScale <= AGUIOpen_squeezeHeight ? (float)m_xScale : 1.0f,
                                  m_xScale >= 0.99f ? (float)m_yScale : AGUIOpen_squeezeHeight,
                                  1);
}

void AGAboutBox::render()
{
    AGInteractiveObject::render();
    
    glDisable(GL_TEXTURE_2D);
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    /* draw bounding box */
    
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setProjectionMatrix(m_projection);
    shader.setModelViewMatrix(m_modelView);
    shader.setNormalMatrix(GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_modelView), NULL));
    
    glDisableVertexAttribArray(GLKVertexAttribColor);
    glDisableVertexAttribArray(GLKVertexAttribNormal);
    glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    
    // stroke
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, m_geoSize);
    
    // fill
    GLcolor4f blackA = GLcolor4f(0, 0, 0, 0.75);
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &blackA);
    glDrawArrays(GL_TRIANGLE_FAN, 0, m_geoSize);
    
    float titleScale = 2;
    float titleHeight = m_radius-s_text->height()*titleScale*1.5;
    string title = "AURAGLYPH";
    GLKMatrix4 titleMV = GLKMatrix4Translate(m_modelView, -s_text->width(title)*titleScale/2, titleHeight, 0);
    titleMV = GLKMatrix4Scale(titleMV, titleScale, titleScale, titleScale);
    s_text->render(title, GLcolor4f::white, titleMV, m_projection);
    
    float lineHeight = s_text->height()*1.4;
    GLKMatrix4 lineMV = GLKMatrix4Translate(m_modelView, 0, titleHeight - lineHeight, 0);
    
    for(int i = 0; i < m_lines.size(); i++)
    {
        if(m_lines[i].length())
        {
            GLKMatrix4 textMV = GLKMatrix4Translate(lineMV, -s_text->width(m_lines[i])/2, 0, 0);
            s_text->render(m_lines[i], GLcolor4f::white, textMV, m_projection);
        }
        
        lineMV = GLKMatrix4Translate(lineMV, 0, -lineHeight, 0);
    }
}

AGInteractiveObject *AGAboutBox::hitTest(const GLvertex3f &t)
{
    AGInteractiveObject *hit = AGInteractiveObject::hitTest(t);
    if(hit != this) m_closeAction();
    return this;
}

void AGAboutBox::renderOut()
{
    m_xScale = lincurvef(AGUIOpen_animTimeX/2, 1, AGUIOpen_squeezeHeight);
    m_yScale = lincurvef(AGUIOpen_animTimeY/2, 1, AGUIOpen_squeezeHeight);
}

bool AGAboutBox::finishedRenderingOut()
{
    return m_xScale <= AGUIOpen_squeezeHeight;
}

void AGAboutBox::setCloseAction(void (^closeAction)())
{
    m_closeAction = [closeAction copy];
}


