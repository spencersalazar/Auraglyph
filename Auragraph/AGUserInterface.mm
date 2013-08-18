//
//  AGUserInterface.mm
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "AGUserInterface.h"
#import "AGNode.h"
#import "ES2Render.h"
#import "ShaderHelper.h"
#import "AGGenericShader.h"
#import "TexFont.h"
#import <sstream>


static const float AGNODESELECTOR_RADIUS = 0.02;

static const float AGUIOpen_squeezeHeight = 0.00125;
float AGUIOpen_animTimeX = 0.4;
float AGUIOpen_animTimeY = 0.15;


bool AGUINodeSelector::s_initNodeSelector = false;
GLuint AGUINodeSelector::s_vertexArray = 0;
GLuint AGUINodeSelector::s_vertexBuffer = 0;
GLuint AGUINodeSelector::s_geoSize = 0;
GLvertex3f * AGUINodeSelector::s_geo = NULL;

//------------------------------------------------------------------------------
// ### AGUINodeSelector ###
//------------------------------------------------------------------------------
#pragma mark AGUINodeSelector

void AGUINodeSelector::initializeNodeSelector()
{
    if(!s_initNodeSelector)
    {
        s_initNodeSelector = true;
        
        s_geoSize = 4;
        s_geo = new GLvertex3f[s_geoSize];
        
        float radius = AGNODESELECTOR_RADIUS;
        
        // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
        s_geo[0] = GLvertex3f(-radius, radius, 0);
        s_geo[1] = GLvertex3f(-radius, -radius, 0);
        s_geo[2] = GLvertex3f(radius, -radius, 0);
        s_geo[3] = GLvertex3f(radius, radius, 0);
        
        genVertexArrayAndBuffer(s_geoSize, s_geo, s_vertexArray, s_vertexBuffer);
    }
}

AGUINodeSelector::AGUINodeSelector(const GLvertex3f &pos) :
m_pos(pos),
m_audioNode(pos),
m_hit(-1),
m_t(0)
{
    initializeNodeSelector();
}

void AGUINodeSelector::update(float t, float dt)
{
    m_modelView = AGNode::globalModelViewMatrix();
    GLKMatrix4 projection = AGNode::projectionMatrix();
    
    m_modelView = GLKMatrix4Translate(m_modelView, m_pos.x, m_pos.y, m_pos.z);
    
    float squeezeHeight = AGUIOpen_squeezeHeight;
    float animTimeX = AGUIOpen_animTimeX;
    float animTimeY = AGUIOpen_animTimeY;
    
    if(m_t < animTimeX)
        m_modelView = GLKMatrix4Scale(m_modelView, squeezeHeight+(m_t/animTimeX)*(1-squeezeHeight), squeezeHeight, 1);
    else if(m_t < animTimeX+animTimeY)
        m_modelView = GLKMatrix4Scale(m_modelView, 1.0, squeezeHeight+((m_t-animTimeX)/animTimeY)*(1-squeezeHeight), 1);

    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, m_modelView);
    
    m_audioNode.update(t, dt);
    
    m_t += dt;
}

void AGUINodeSelector::render()
{
    /* draw blank audio node */
    m_audioNode.render();

    
    /* draw bounding box */
    
    glBindVertexArrayOES(s_vertexArray);
    
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    
    AGGenericShader::instance().useProgram();
    
    AGGenericShader::instance().setMVPMatrix(m_modelViewProjectionMatrix);
    AGGenericShader::instance().setNormalMatrix(m_normalMatrix);
    
    glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &GLcolor4f::white);
    
    // stroke
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    
    GLcolor4f blackA = GLcolor4f(0, 0, 0, 0.75);
    glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &blackA);

    // fill
    glDrawArrays(GL_TRIANGLE_FAN, 0, s_geoSize);
    
    
    /* draw node types */
    
    float radius = AGNODESELECTOR_RADIUS;
    GLvertex3f startPos(-radius/2, -radius/2, 0);
    GLvertex3f xInc(radius, 0, 0);
    GLvertex3f yInc(0, radius, 0);
    
    GLKMatrix4 projection = AGNode::projectionMatrix();
    
    const std::vector<AGAudioNodeManager::AudioNodeType *> nodeTypes = AGAudioNodeManager::instance().audioNodeTypes();
    for(int i = 0; i < nodeTypes.size(); i++)
    {
        GLvertex3f iconPos = startPos + (xInc*(i%2)) + (yInc*(i/2));
        
        GLKMatrix4 modelView = GLKMatrix4Translate(m_modelView, iconPos.x, iconPos.y, iconPos.z);
        GLKMatrix3 normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
        GLKMatrix4 mvp = GLKMatrix4Multiply(projection, modelView);
        
        if(i == m_hit)
        {
            // draw highlight background
            GLKMatrix4 hitModelView = GLKMatrix4Scale(modelView, 0.5, 0.5, 0.5);
            GLKMatrix3 hitNormal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
            GLKMatrix4 hitMvp = GLKMatrix4Multiply(projection, hitModelView);
            
            GLcolor4f whiteA = GLcolor4f::white;
            whiteA.a = 0.75;
            
            AGGenericShader::instance().setMVPMatrix(hitMvp);
            AGGenericShader::instance().setNormalMatrix(hitNormal);
            glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &whiteA);
            
            glBindVertexArrayOES(s_vertexArray);
            
            glDrawArrays(GL_TRIANGLE_FAN, 0, s_geoSize);
            
            glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &GLcolor4f::black);
        }
        else
        {
            glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &GLcolor4f::white);
        }
        
        AGGenericShader::instance().setMVPMatrix(mvp);
        AGGenericShader::instance().setNormalMatrix(normal);
        
        glLineWidth(4.0f);
        AGAudioNodeManager::instance().renderNodeTypeIcon(nodeTypes[i]);
    }
}

void AGUINodeSelector::touchDown(const GLvertex3f &t)
{
    float radius = AGNODESELECTOR_RADIUS;
    m_hit = -1;
    
    // check if in entire bounds
    if(t.x > m_pos.x-radius && t.x < m_pos.x+radius &&
       t.y > m_pos.y-radius && t.y < m_pos.y+radius)
    {
        const std::vector<AGAudioNodeManager::AudioNodeType *> nodeTypes = AGAudioNodeManager::instance().audioNodeTypes();
        GLvertex3f startPos = m_pos + GLvertex3f(-radius/2, -radius/2, 0);
        GLvertex3f xInc(radius, 0, 0);
        GLvertex3f yInc(0, radius, 0);
        float iconRadius = radius/2;
        
        for(int i = 0; i < nodeTypes.size(); i++)
        {
            GLvertex3f iconPos = startPos + (xInc*(i%2)) + (yInc*(i/2));
            
            if(t.x > iconPos.x-iconRadius && t.x < iconPos.x+iconRadius &&
               t.y > iconPos.y-iconRadius && t.y < iconPos.y+iconRadius)
            {
                m_hit = i;
                break;
            }
        }
    }
}

void AGUINodeSelector::touchMove(const GLvertex3f &t)
{
    touchDown(t);
}

void AGUINodeSelector::touchUp(const GLvertex3f &t)
{
    touchDown(t);
}

AGAudioNode *AGUINodeSelector::createNode()
{
    if(m_hit >= 0)
    {
        const std::vector<AGAudioNodeManager::AudioNodeType *> nodeTypes = AGAudioNodeManager::instance().audioNodeTypes();
        return AGAudioNodeManager::instance().createNodeType(nodeTypes[m_hit], m_pos);
    }
    else
    {
        return NULL;
    }
}


//------------------------------------------------------------------------------
// ### AGUINodeEditor ###
//------------------------------------------------------------------------------
#pragma mark AGUINodeEditor

static const int NODEEDITOR_ROWCOUNT = 5;


bool AGUINodeEditor::s_init = false;
TexFont *AGUINodeEditor::s_text = NULL;
float AGUINodeEditor::s_radius = 0;
GLuint AGUINodeEditor::s_geoSize = 0;
GLvertex3f * AGUINodeEditor::s_geo = NULL;
GLuint AGUINodeEditor::s_boundingOffset = 0;
GLuint AGUINodeEditor::s_innerboxOffset = 0;

void AGUINodeEditor::initializeNodeEditor()
{
    if(!s_init)
    {
        s_init = false;
        
        const char *fontPath = [[[NSBundle mainBundle] pathForResource:@"Perfect DOS VGA 437.ttf" ofType:@""] UTF8String];
        s_text = new TexFont(fontPath, 64);
        
        s_geoSize = 8;
        s_geo = new GLvertex3f[s_geoSize];
        
        s_radius = AGNODESELECTOR_RADIUS;
        float radius = s_radius;
        
        // outer box
        // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
        s_geo[0] = GLvertex3f(-radius, radius, 0);
        s_geo[1] = GLvertex3f(-radius, -radius, 0);
        s_geo[2] = GLvertex3f(radius, -radius, 0);
        s_geo[3] = GLvertex3f(radius, radius, 0);
        
        // inner box(es)
        // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
        s_geo[4] = GLvertex3f(-radius*0.95, radius/NODEEDITOR_ROWCOUNT, 0);
        s_geo[5] = GLvertex3f(-radius*0.95, -radius/NODEEDITOR_ROWCOUNT, 0);
        s_geo[6] = GLvertex3f(radius*0.95, -radius/NODEEDITOR_ROWCOUNT, 0);
        s_geo[7] = GLvertex3f(radius*0.95, radius/NODEEDITOR_ROWCOUNT, 0);
        
        s_boundingOffset = 0;
        s_innerboxOffset = 4;
    }
}

AGUINodeEditor::AGUINodeEditor(AGNode *node) :
m_node(node),
m_hit(-1),
m_t(0),
m_doneEditing(false)
{
    initializeNodeEditor();
}

void AGUINodeEditor::update(float t, float dt)
{
    m_modelView = AGNode::globalModelViewMatrix();
    GLKMatrix4 projection = AGNode::projectionMatrix();
    
    m_modelView = GLKMatrix4Translate(m_modelView, m_node->position().x, m_node->position().y, m_node->position().z);
    
    float squeezeHeight = AGUIOpen_squeezeHeight;
    float animTimeX = AGUIOpen_animTimeX;
    float animTimeY = AGUIOpen_animTimeY;
    
    if(m_t < animTimeX)
        m_modelView = GLKMatrix4Scale(m_modelView, squeezeHeight+(m_t/animTimeX)*(1-squeezeHeight), squeezeHeight, 1);
    else if(m_t < animTimeX+animTimeY)
        m_modelView = GLKMatrix4Scale(m_modelView, 1.0, squeezeHeight+((m_t-animTimeX)/animTimeY)*(1-squeezeHeight), 1);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, m_modelView);
    
    m_t += dt;
}

void AGUINodeEditor::render()
{
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    /* draw bounding box */
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_geo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(GLKVertexAttribNormal);
    
    AGGenericShader::instance().useProgram();
    
    AGGenericShader::instance().setMVPMatrix(m_modelViewProjectionMatrix);
    AGGenericShader::instance().setNormalMatrix(m_normalMatrix);
    
    // stroke
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, s_boundingOffset, 4);
    
    GLcolor4f blackA = GLcolor4f(0, 0, 0, 0.75);
    glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &blackA);
    
    // fill
    glDrawArrays(GL_TRIANGLE_FAN, s_boundingOffset, 4);
    
    
    /* draw title */
    
    float rowCount = NODEEDITOR_ROWCOUNT;
    GLKMatrix4 proj = AGNode::projectionMatrix();
    
    GLKMatrix4 titleMV = GLKMatrix4Translate(m_modelView, -s_radius*0.9, s_radius - s_radius*2.0/rowCount, 0);
    titleMV = GLKMatrix4Scale(titleMV, 0.61, 0.61, 0.61);
    s_text->render("EDIT", GLcolor4f::white, titleMV, proj);
    
    
    /* draw items */

    int numPorts = m_node->numInputPorts();
    
    for(int i = 0; i < numPorts; i++)
    {
        float y = s_radius - s_radius*2.0*(i+2)/rowCount;
        GLcolor4f nameColor(0.61, 0.61, 0.61, 1);
        GLcolor4f valueColor = GLcolor4f::white;
    
        if(i == m_hit)
        {
            glBindVertexArrayOES(0);
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            
            /* draw hit box */
            
            glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_geo);
            glEnableVertexAttribArray(GLKVertexAttribPosition);
            glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
            glDisableVertexAttribArray(GLKVertexAttribColor);
            glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
            glDisableVertexAttribArray(GLKVertexAttribNormal);
            
            AGGenericShader::instance().useProgram();
            GLKMatrix4 hitMVP = GLKMatrix4Multiply(proj, GLKMatrix4Translate(m_modelView, 0, y + s_radius/rowCount, 0));
            AGGenericShader::instance().setMVPMatrix(hitMVP);
            AGGenericShader::instance().setNormalMatrix(m_normalMatrix);
            
            // fill
            glDrawArrays(GL_TRIANGLE_FAN, s_innerboxOffset, 4);
            
            // invert colors
            nameColor = GLcolor4f(1-nameColor.r, 1-nameColor.g, 1-nameColor.b, 1);
            valueColor = GLcolor4f(1-valueColor.r, 1-valueColor.g, 1-valueColor.b, 1);
        }
        
        GLKMatrix4 nameMV = GLKMatrix4Translate(m_modelView, -s_radius*0.9, y, 0);
        nameMV = GLKMatrix4Scale(nameMV, 0.61, 0.61, 0.61);
        s_text->render(m_node->inputPortInfo(i).name, nameColor, nameMV, proj);
        
        GLKMatrix4 valueMV = GLKMatrix4Translate(m_modelView, s_radius*0.1, y, 0);
        valueMV = GLKMatrix4Scale(valueMV, 0.61, 0.61, 0.61);
        std::stringstream ss;
        float v = 0;
        m_node->getInputPortValue(i, v);
        ss << v;
        s_text->render(ss.str(), valueColor, valueMV, proj);
    }
}


void AGUINodeEditor::touchDown(const GLvertex3f &t)
{
    m_hit = -1;
    float rowCount = NODEEDITOR_ROWCOUNT;

    GLvertex3f pos = m_node->position();
    
    // check if in entire bounds
    if(t.x > pos.x-s_radius && t.x < pos.x+s_radius &&
       t.y > pos.y-s_radius && t.y < pos.y+s_radius)
    {
        int numPorts = m_node->numInputPorts();

        for(int i = 0; i < numPorts; i++)
        {
            float y_max = pos.y + s_radius - s_radius*2.0*(i+1)/rowCount;
            float y_min = pos.y + s_radius - s_radius*2.0*(i+2)/rowCount;
            if(t.y > y_min && t.y < y_max)
            {
                m_hit = i;
                break;
            }
        }
    }
    else
    {
        m_doneEditing = true;
    }
}

void AGUINodeEditor::touchMove(const GLvertex3f &t)
{
    touchDown(t);
}

void AGUINodeEditor::touchUp(const GLvertex3f &t)
{
    touchDown(t);
}



