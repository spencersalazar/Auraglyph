//
//  AGUserInterface.mm
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "AGUserInterface.h"
#import "AGNode.h"
#import "AGAudioNode.h"
#import "ES2Render.h"
#import "ShaderHelper.h"
#import "AGGenericShader.h"
#import "TexFont.h"
#import "AGHandwritingRecognizer.h"
#import "Texture.h"

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
#pragma mark -
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
m_audioNode(new AGAudioNode(pos)),
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
    
    m_audioNode->update(t, dt);
    
    m_t += dt;
}

void AGUINodeSelector::render()
{
    /* draw blank audio node */
    m_audioNode->render();

    
    /* draw bounding box */
    
    glBindVertexArrayOES(s_vertexArray);
    
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    
    AGClipShader &shader = AGClipShader::instance();
    
    shader.useProgram();
    
    shader.setMVPMatrix(m_modelViewProjectionMatrix);
    shader.setNormalMatrix(m_normalMatrix);
    
    float radius = AGNODESELECTOR_RADIUS;
    shader.setClip(GLvertex2f(-radius, -radius), GLvertex2f(radius*2, radius*2));
    shader.setLocalMatrix(GLKMatrix4Identity);
    
    glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &GLcolor4f::white);
    
    // stroke
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    
    GLcolor4f blackA = GLcolor4f(0, 0, 0, 0.75);
    glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &blackA);

    // fill
    glDrawArrays(GL_TRIANGLE_FAN, 0, s_geoSize);
    
    
    /* draw node types */
    
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
            shader.setLocalMatrix(GLKMatrix4Scale(GLKMatrix4MakeTranslation(iconPos.x, iconPos.y, iconPos.z), 0.5, 0.5, 0.5));
            GLKMatrix3 hitNormal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
            GLKMatrix4 hitMvp = GLKMatrix4Multiply(projection, hitModelView);
            
            GLcolor4f whiteA = GLcolor4f::white;
            whiteA.a = 0.75;
            
            shader.setMVPMatrix(hitMvp);
            shader.setNormalMatrix(hitNormal);
            glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &whiteA);
            
            glBindVertexArrayOES(s_vertexArray);
            
            glDrawArrays(GL_TRIANGLE_FAN, 0, s_geoSize);
            
            glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &GLcolor4f::black);
        }
        else
        {
            glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &GLcolor4f::white);
        }
        
        shader.setMVPMatrix(mvp);
        shader.setNormalMatrix(normal);
        shader.setLocalMatrix(GLKMatrix4MakeTranslation(iconPos.x, iconPos.y, iconPos.z));
        
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
#pragma mark -
#pragma mark AGUINodeEditor

static const int NODEEDITOR_ROWCOUNT = 5;


bool AGUINodeEditor::s_init = false;
TexFont *AGUINodeEditor::s_text = NULL;
float AGUINodeEditor::s_radius = 0;
GLuint AGUINodeEditor::s_geoSize = 0;
GLvertex3f * AGUINodeEditor::s_geo = NULL;
GLuint AGUINodeEditor::s_boundingOffset = 0;
GLuint AGUINodeEditor::s_innerboxOffset = 0;
GLuint AGUINodeEditor::s_buttonBoxOffset = 0;
GLuint AGUINodeEditor::s_itemEditBoxOffset = 0;

void AGUINodeEditor::initializeNodeEditor()
{
    if(!s_init)
    {
        s_init = true;
        
        const char *fontPath = [[[NSBundle mainBundle] pathForResource:@"Perfect DOS VGA 437.ttf" ofType:@""] UTF8String];
        s_text = new TexFont(fontPath, 64);
        
        s_geoSize = 16;
        s_geo = new GLvertex3f[s_geoSize];
        
        s_radius = AGNODESELECTOR_RADIUS;
        float radius = s_radius;
        
        // outer box
        // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
        s_geo[0] = GLvertex3f(-radius, radius, 0);
        s_geo[1] = GLvertex3f(-radius, -radius, 0);
        s_geo[2] = GLvertex3f(radius, -radius, 0);
        s_geo[3] = GLvertex3f(radius, radius, 0);
        
        // inner selection box
        // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
        s_geo[4] = GLvertex3f(-radius*0.95, radius/NODEEDITOR_ROWCOUNT, 0);
        s_geo[5] = GLvertex3f(-radius*0.95, -radius/NODEEDITOR_ROWCOUNT, 0);
        s_geo[6] = GLvertex3f(radius*0.95, -radius/NODEEDITOR_ROWCOUNT, 0);
        s_geo[7] = GLvertex3f(radius*0.95, radius/NODEEDITOR_ROWCOUNT, 0);
        
        // button box
        // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
        s_geo[8] = GLvertex3f(-radius*0.9*0.60, radius/NODEEDITOR_ROWCOUNT * 0.95, 0);
        s_geo[9] = GLvertex3f(-radius*0.9*0.60, -radius/NODEEDITOR_ROWCOUNT * 0.95, 0);
        s_geo[10] = GLvertex3f(radius*0.9*0.60, -radius/NODEEDITOR_ROWCOUNT * 0.95, 0);
        s_geo[11] = GLvertex3f(radius*0.9*0.60, radius/NODEEDITOR_ROWCOUNT * 0.95, 0);
        
        // item edit bounding box
        // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
        s_geo[12] = GLvertex3f(-radius*1.05, radius, 0);
        s_geo[13] = GLvertex3f(-radius*1.05, -radius, 0);
        s_geo[14] = GLvertex3f(radius*3.45, -radius, 0);
        s_geo[15] = GLvertex3f(radius*3.45, radius, 0);
        
        s_boundingOffset = 0;
        s_innerboxOffset = 4;
        s_buttonBoxOffset = 8;
        s_itemEditBoxOffset = 12;
    }
}

AGUINodeEditor::AGUINodeEditor(AGNode *node) :
m_node(node),
m_hit(-1),
m_editingPort(-1),
m_t(0),
m_doneEditing(false),
m_hitAccept(false),
m_startedInAccept(false),
m_hitDiscard(false),
m_startedInDiscard(false),
m_lastTraceWasRecognized(true)
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
        
        GLKMatrix4 nameMV = GLKMatrix4Translate(m_modelView, -s_radius*0.9, y + s_radius/rowCount*0.1, 0);
        nameMV = GLKMatrix4Scale(nameMV, 0.61, 0.61, 0.61);
        s_text->render(m_node->inputPortInfo(i).name, nameColor, nameMV, proj);
        
        GLKMatrix4 valueMV = GLKMatrix4Translate(m_modelView, s_radius*0.1, y + s_radius/rowCount*0.1, 0);
        valueMV = GLKMatrix4Scale(valueMV, 0.61, 0.61, 0.61);
        std::stringstream ss;
        float v = 0;
        m_node->getInputPortValue(i, v);
        ss << v;
        s_text->render(ss.str(), valueColor, valueMV, proj);
    }
    
    
    /* draw item editor */
    
    if(m_editingPort >= 0)
    {
        glBindVertexArrayOES(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_geo);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        glDisableVertexAttribArray(GLKVertexAttribColor);
        glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
        glDisableVertexAttribArray(GLKVertexAttribNormal);
        
        float y = s_radius - s_radius*2.0*(m_editingPort+2)/rowCount;
        
        AGGenericShader::instance().useProgram();
        AGGenericShader::instance().setNormalMatrix(m_normalMatrix);
        
        // bounding box
        GLKMatrix4 bbMVP = GLKMatrix4Multiply(proj, GLKMatrix4Translate(m_modelView, 0, y - s_radius + s_radius*2/rowCount, 0));
        AGGenericShader::instance().setMVPMatrix(bbMVP);
        
        // stroke
        glDrawArrays(GL_LINE_LOOP, s_itemEditBoxOffset, 4);
        
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &blackA);
        
        // fill
        glDrawArrays(GL_TRIANGLE_FAN, s_itemEditBoxOffset, 4);
        
        
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);

        // accept button
        GLKMatrix4 buttonMVP = GLKMatrix4Multiply(proj, GLKMatrix4Translate(m_modelView, s_radius*1.65, y + s_radius/rowCount, 0));
        AGGenericShader::instance().setMVPMatrix(buttonMVP);
        if(m_hitAccept)
            // stroke
            glDrawArrays(GL_LINE_LOOP, s_buttonBoxOffset, 4);
        else
            // fill
            glDrawArrays(GL_TRIANGLE_FAN, s_buttonBoxOffset, 4);
        
        // discard button
        buttonMVP = GLKMatrix4Multiply(proj, GLKMatrix4Translate(m_modelView, s_radius*1.65 + s_radius*1.2, y + s_radius/rowCount, 0));
        AGGenericShader::instance().setMVPMatrix(buttonMVP);
        // fill
        if(m_hitDiscard)
            // stroke
            glDrawArrays(GL_LINE_LOOP, s_buttonBoxOffset, 4);
        else
            // fill
            glDrawArrays(GL_TRIANGLE_FAN, s_buttonBoxOffset, 4);
        
        // text
        GLKMatrix4 textMV = GLKMatrix4Translate(m_modelView, s_radius*1.2, y + s_radius/rowCount*0.1, 0);
        textMV = GLKMatrix4Scale(textMV, 0.5, 0.5, 0.5);
        if(m_hitAccept)
            s_text->render("Accept", GLcolor4f::white, textMV, proj);
        else
            s_text->render("Accept", GLcolor4f::black, textMV, proj);
        
        
        textMV = GLKMatrix4Translate(m_modelView, s_radius*1.2 + s_radius*1.2, y + s_radius/rowCount*0.1, 0);
        textMV = GLKMatrix4Scale(textMV, 0.5, 0.5, 0.5);
        if(m_hitDiscard)
            s_text->render("Discard", GLcolor4f::white, textMV, proj);
        else
            s_text->render("Discard", GLcolor4f::black, textMV, proj);
        
        // text name + value
        GLKMatrix4 nameMV = GLKMatrix4Translate(m_modelView, -s_radius*0.9, y + s_radius/rowCount*0.1, 0);
        nameMV = GLKMatrix4Scale(nameMV, 0.61, 0.61, 0.61);
        s_text->render(m_node->inputPortInfo(m_editingPort).name, GLcolor4f::white, nameMV, proj);
        
        GLKMatrix4 valueMV = GLKMatrix4Translate(m_modelView, s_radius*0.1, y + s_radius/rowCount*0.1, 0);
        valueMV = GLKMatrix4Scale(valueMV, 0.61, 0.61, 0.61);
        std::stringstream ss;
        ss << m_currentValue;
        s_text->render(ss.str(), GLcolor4f::white, valueMV, proj);
        
        AGGenericShader::instance().useProgram();
        AGGenericShader::instance().setNormalMatrix(m_normalMatrix);
        AGGenericShader::instance().setMVPMatrix(GLKMatrix4Multiply(proj, AGNode::globalModelViewMatrix()));

        // draw traces
        for(std::list<std::vector<GLvertex3f> >::iterator i = m_drawline.begin(); i != m_drawline.end(); i++)
        {
            std::vector<GLvertex3f> geo = *i;
            glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), geo.data());
            glEnableVertexAttribArray(GLKVertexAttribPosition);
            glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
            glDisableVertexAttribArray(GLKVertexAttribColor);
            glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
            glDisableVertexAttribArray(GLKVertexAttribNormal);
            
            glDrawArrays(GL_LINE_STRIP, 0, geo.size());
        }
    }
}


int AGUINodeEditor::hitTest(const GLvertex3f &t, bool *inBbox)
{
    float rowCount = NODEEDITOR_ROWCOUNT;
    
    *inBbox = false;
    
    GLvertex3f pos = m_node->position();
    
    if(m_editingPort >= 0)
    {
        float y = s_radius - s_radius*2.0*(m_editingPort+2)/rowCount;
        
        float bb_center = y - s_radius + s_radius*2/rowCount;
        if(t.x > pos.x+s_geo[s_itemEditBoxOffset].x && t.x < pos.x+s_geo[s_itemEditBoxOffset+2].x &&
           t.y > pos.y+bb_center+s_geo[s_itemEditBoxOffset+2].y && t.y < pos.y+bb_center+s_geo[s_itemEditBoxOffset].y)
        {
            *inBbox = true;
            
            GLvertex3f acceptCenter = pos + GLvertex3f(s_radius*1.65, y + s_radius/rowCount, pos.z);
            GLvertex3f discardCenter = pos + GLvertex3f(s_radius*1.65 + s_radius*1.2, y + s_radius/rowCount, pos.z);
            
            if(t.x > acceptCenter.x+s_geo[s_buttonBoxOffset].x && t.x < acceptCenter.x+s_geo[s_buttonBoxOffset+2].x &&
               t.y > acceptCenter.y+s_geo[s_buttonBoxOffset+2].y && t.y < acceptCenter.y+s_geo[s_buttonBoxOffset].y)
                return 1;
            if(t.x > discardCenter.x+s_geo[s_buttonBoxOffset].x && t.x < discardCenter.x+s_geo[s_buttonBoxOffset+2].x &&
               t.y > discardCenter.y+s_geo[s_buttonBoxOffset+2].y && t.y < discardCenter.y+s_geo[s_buttonBoxOffset].y)
                return 0;
        }
    }
    
    // check if in entire bounds
    else if(t.x > pos.x-s_radius && t.x < pos.x+s_radius &&
            t.y > pos.y-s_radius && t.y < pos.y+s_radius)
    {
        *inBbox = true;
        
        int numPorts = m_node->numInputPorts();
        
        for(int i = 0; i < numPorts; i++)
        {
            float y_max = pos.y + s_radius - s_radius*2.0*(i+1)/rowCount;
            float y_min = pos.y + s_radius - s_radius*2.0*(i+2)/rowCount;
            if(t.y > y_min && t.y < y_max)
            {
                return i;
            }
        }
    }
    
    return -1;
}


void AGUINodeEditor::touchDown(const GLvertex3f &t, const CGPoint &screen)
{
    if(m_editingPort < 0)
    {
        m_hit = -1;
        bool inBBox = false;
        
        // check if in entire bounds
        m_hit = hitTest(t, &inBBox);
        
        m_doneEditing = !inBBox;
    }
    else
    {
        m_hitAccept = false;
        m_startedInAccept = false;
        m_hitDiscard = false;
        m_startedInDiscard = false;
        
        bool inBBox = false;
        int hit = hitTest(t, &inBBox);
        
        if(hit == 0)
        {
            m_hitDiscard = true;
            m_startedInDiscard = true;
        }
        else if(hit == 1)
        {
            m_hitAccept = true;
            m_startedInAccept = true;
        }
        else if(inBBox)
        {
            if(!m_lastTraceWasRecognized && m_drawline.size())
                m_drawline.remove(m_drawline.back());
            m_drawline.push_back(std::vector<GLvertex3f>());
            m_currentTrace = LTKTrace();
            
            m_drawline.back().push_back(t);
            floatVector point;
            point.push_back(screen.x);
            point.push_back(screen.y);
            m_currentTrace.addPoint(point);
        }
    }
}

void AGUINodeEditor::touchMove(const GLvertex3f &t, const CGPoint &screen)
{
    if(!m_doneEditing)
    {
        if(m_editingPort >= 0)
        {
            bool inBBox = false;
            int hit = hitTest(t, &inBBox);
            
            m_hitAccept = false;
            m_hitDiscard = false;
            
            if(hit == 0 && m_startedInDiscard)
            {
                m_hitDiscard = true;
            }
            else if(hit == 1 && m_startedInAccept)
            {
                m_hitAccept = true;
            }
            else if(inBBox && !m_startedInDiscard && !m_startedInAccept)
            {
                m_drawline.back().push_back(t);
                floatVector point;
                point.push_back(screen.x);
                point.push_back(screen.y);
                m_currentTrace.addPoint(point);
            }
        }
        else
        {
            bool inBBox = false;
            m_hit = hitTest(t, &inBBox);
        }
    }
}

void AGUINodeEditor::touchUp(const GLvertex3f &t, const CGPoint &screen)
{
    if(!m_doneEditing)
    {
        if(m_editingPort >= 0)
        {
            if(m_hitAccept)
            {
//                m_doneEditing = true;
                m_node->setInputPortValue(m_editingPort, m_currentValue);
                m_editingPort = -1;
                m_hitAccept = false;
                m_drawline.clear();
            }
            else if(m_hitDiscard)
            {
//                m_doneEditing = true;
                m_editingPort = -1;
                m_hitDiscard = false;
                m_drawline.clear();
            }
            else if(m_currentTrace.getNumberOfPoints() > 0 && !m_startedInDiscard && !m_startedInAccept)
            {
                // attempt recognition
                AGHandwritingRecognizerFigure figure = [[AGHandwritingRecognizer instance] recognizeNumeral:m_currentTrace];
                
                switch(figure)
                {
                    case AG_FIGURE_0:
                    case AG_FIGURE_1:
                    case AG_FIGURE_2:
                    case AG_FIGURE_3:
                    case AG_FIGURE_4:
                    case AG_FIGURE_5:
                    case AG_FIGURE_6:
                    case AG_FIGURE_7:
                    case AG_FIGURE_8:
                    case AG_FIGURE_9:
                        m_currentValue = (figure-'0') + m_currentValue*10;
                        m_lastTraceWasRecognized = true;
                        break;
                        
                    default:
                        m_lastTraceWasRecognized = false;
                }
            }
        }
        else
        {
            bool inBBox = false;
            m_hit = hitTest(t, &inBBox);
            
            if(m_hit >= 0)
            {
                m_editingPort = m_hit;
                m_hit = -1;
                m_currentValue = 0;
                //m_node->getInputPortValue(m_editingPort, m_currentValue);
            }
        }
    }
}


//------------------------------------------------------------------------------
// ### AGUIButton ###
//------------------------------------------------------------------------------
#pragma mark - AGUIButton

TexFont *AGUIButton::s_text = NULL;

AGUIButton::AGUIButton(const std::string &title, const GLvertex3f &pos, const GLvertex3f &size) :
m_action(nil)
{
    if(s_text == NULL)
    {
        const char *fontPath = [[[NSBundle mainBundle] pathForResource:@"Perfect DOS VGA 437.ttf" ofType:@""] UTF8String];
        s_text = new TexFont(fontPath, 64);
    }
    
    m_hit = m_hitOnTouchDown = false;
    
    m_title = title;
    
    m_pos = pos;
    m_size = size;
    m_geo[0] = GLvertex3f(0, 0, 0);
    m_geo[1] = GLvertex3f(size.x, 0, 0);
    m_geo[2] = GLvertex3f(size.x, size.y, 0);
    m_geo[3] = GLvertex3f(0, size.y, 0);
    
    float stripeInset = 0.0002;
    
    m_geo[4] = GLvertex3f(stripeInset, stripeInset, 0);
    m_geo[5] = GLvertex3f(size.x-stripeInset, stripeInset, 0);
    m_geo[6] = GLvertex3f(size.x-stripeInset, size.y-stripeInset, 0);
    m_geo[7] = GLvertex3f(stripeInset, size.y-stripeInset, 0);
}

AGUIButton::~AGUIButton()
{
    m_action = nil;
}

void AGUIButton::update(float t, float dt)
{
}

void AGUIButton::render()
{
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    float textScale = 0.5;
    
    GLKMatrix4 proj = AGNode::projectionMatrix();
    GLKMatrix4 modelView = GLKMatrix4Translate(AGNode::globalModelViewMatrix(), m_pos.x, m_pos.y, m_pos.z);
    GLKMatrix4 textMV = GLKMatrix4Translate(modelView, m_size.x/2-s_text->width()*m_title.length()*textScale/2, m_size.y/2-s_text->height()*textScale/2*1.25, 0);
//    GLKMatrix4 textMV = modelView;
    textMV = GLKMatrix4Scale(textMV, textScale, textScale, textScale);
    
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setProjectionMatrix(proj);
    shader.setModelViewMatrix(modelView);
    shader.setNormalMatrix(GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL));
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(GLKVertexAttribNormal);
    
    if(m_hit)
    {
        glLineWidth(4.0);
        glDrawArrays(GL_LINE_LOOP, 0, 4);
        
        s_text->render(m_title, GLcolor4f::white, textMV, proj);
    }
    else
    {
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::black);
        glLineWidth(2.0);
        glDrawArrays(GL_LINE_LOOP, 4, 4);

        s_text->render(m_title, GLcolor4f::black, textMV, proj);
    }
}


void AGUIButton::touchDown(const GLvertex3f &t)
{
    m_hit = true;
    m_hitOnTouchDown = true;
}

void AGUIButton::touchMove(const GLvertex3f &t)
{
    m_hit = (m_hitOnTouchDown && hitTest(t) == this);
}

void AGUIButton::touchUp(const GLvertex3f &t)
{
    if(m_hit && m_action)
        m_action();
    
    m_hit = false;
}


AGUIObject *AGUIButton::hitTest(const GLvertex3f &t)
{
    if(t.x > m_pos.x && t.x < m_pos.x+m_size.x &&
       t.y > m_pos.y && t.y < m_pos.y+m_size.y)
    {
        return this;
    }
    
    return NULL;
}

void AGUIButton::setAction(void (^action)())
{
    m_action = [action copy];
}


//------------------------------------------------------------------------------
// ### AGUITrash ###
//------------------------------------------------------------------------------
#pragma mark - AGUITrash

AGUITrash &AGUITrash::instance()
{
    static AGUITrash s_trash;
    
    return s_trash;
}

AGUITrash::AGUITrash()
{
    m_tex = loadOrRetrieveTexture(@"trash.png");
    
    m_radius = 0.005;
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
    m_scale.slew = 0.1;
}

AGUITrash::~AGUITrash()
{
    
}

void AGUITrash::update(float t, float dt)
{
    if(m_active)
        m_scale.target = 1.25;
    else
        m_scale.target = 1;
    
    m_scale.interp();
}

void AGUITrash::render()
{
    GLKMatrix4 proj = AGNode::projectionMatrix();
    GLKMatrix4 modelView = GLKMatrix4Translate(AGNode::globalModelViewMatrix(), m_position.x, m_position.y, m_position.z);
    modelView = GLKMatrix4Scale(modelView, m_scale, m_scale, m_scale);
    
    AGGenericShader &shader = AGTextureShader::instance();
    
    shader.useProgram();
    
    shader.setProjectionMatrix(proj);
    shader.setModelViewMatrix(modelView);
    shader.setNormalMatrix(GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL));
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    if(m_active)
        glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &GLcolor4f::red);
    else
        glVertexAttrib4fv(GLKVertexAttribColor, (const GLfloat *) &GLcolor4f::white);
    
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




