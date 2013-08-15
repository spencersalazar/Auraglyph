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


static const float AGNODESELECTOR_RADIUS = 0.02;


bool AGUINodeSelector::s_initNodeSelector = false;
GLuint AGUINodeSelector::s_vertexArray = 0;
GLuint AGUINodeSelector::s_vertexBuffer = 0;
GLuint AGUINodeSelector::s_geoSize = 0;
GLvncprimf * AGUINodeSelector::s_geo = NULL;
GLuint AGUINodeSelector::s_geoOutlineOffset = 0;
GLuint AGUINodeSelector::s_geoOutlineSize = 0;
GLuint AGUINodeSelector::s_geoFillOffset = 0;
GLuint AGUINodeSelector::s_geoFillSize = 0;
GLuint AGUINodeSelector::s_program = 0;
GLint AGUINodeSelector::s_uniformMVPMatrix = 0;
GLint AGUINodeSelector::s_uniformNormalMatrix = 0;
GLint AGUINodeSelector::s_uniformColor2 = 0;

void AGUINodeSelector::initializeNodeSelector()
{
    if(!s_initNodeSelector)
    {
        s_initNodeSelector = true;
        
        s_geoSize = 4 + 4; // outline + fill
        s_geo = new GLvncprimf[s_geoSize];
        s_geoOutlineOffset = 0;
        s_geoOutlineSize = 4;
        s_geoFillOffset = s_geoOutlineOffset + s_geoOutlineSize;
        s_geoFillSize = 4;
        
        float radius = AGNODESELECTOR_RADIUS;
        
        // stroke GL_LINE_STRIP
        s_geo[0].vertex = GLvertex3f(-radius, radius, 0);
        s_geo[1].vertex = GLvertex3f(-radius, -radius, 0);
        s_geo[2].vertex = GLvertex3f(radius, -radius, 0);
        s_geo[3].vertex = GLvertex3f(radius, radius, 0);
        // fill GL_TRIANGLE_STRIP S-shape
        s_geo[4].vertex = GLvertex3f(-radius, -radius, 0);
        s_geo[5].vertex = GLvertex3f(radius, -radius, 0);
        s_geo[6].vertex = GLvertex3f(-radius, radius, 0);
        s_geo[7].vertex = GLvertex3f(radius, radius, 0);
        
        for(int i = 0; i < s_geoSize; i++)
        {
            s_geo[i].normal = GLvertex3f(0, 0, 1);
            s_geo[i].color = GLcolor4f(1, 1, 1, 1);
        }
        
        genVertexArrayAndBuffer(s_geoSize, s_geo, s_vertexArray, s_vertexBuffer);
        
        s_program = [ShaderHelper createProgramForVertexShader:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"]
                                                fragmentShader:[[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"]];
        s_uniformMVPMatrix = glGetUniformLocation(s_program, "modelViewProjectionMatrix");
        s_uniformNormalMatrix = glGetUniformLocation(s_program, "normalMatrix");
        s_uniformColor2 = glGetUniformLocation(s_program, "color2");
    }
}

AGUINodeSelector::AGUINodeSelector(const GLvertex3f &pos) :
m_pos(pos),
m_audioNode(pos),
m_hit(-1)
{
    initializeNodeSelector();
}

void AGUINodeSelector::update(float t, float dt)
{
    GLKMatrix4 modelView = AGNode::globalModelViewMatrix();
    GLKMatrix4 projection = AGNode::projectionMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
    
    m_audioNode.update(t, dt);
}

void AGUINodeSelector::render()
{
    // draw blank audio node
    m_audioNode.render();
    
    // draw bounding box
    glBindVertexArrayOES(s_vertexArray);
    
    glUseProgram(s_program);
    
    glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, m_modelViewProjectionMatrix.m);
    glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, m_normalMatrix.m);
    glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::white());
    
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, s_geoOutlineOffset, s_geoOutlineSize);
    
    GLcolor4f blackA = GLcolor4f::black();
    blackA.a = 0.75;
    glUniform4fv(s_uniformColor2, 1, (float*) &blackA);
    
    glDrawArrays(GL_TRIANGLE_STRIP, s_geoFillOffset, s_geoFillSize);
    
    
    // draw node types
    
    float radius = AGNODESELECTOR_RADIUS;
    GLvertex3f startPos(-radius/2, -radius/2, 0);
    GLvertex3f xInc(radius, 0, 0);
    GLvertex3f yInc(0, radius, 0);
    
    GLKMatrix4 baseModelView = AGNode::globalModelViewMatrix();
    GLKMatrix4 projection = AGNode::projectionMatrix();
    baseModelView = GLKMatrix4Translate(baseModelView, m_pos.x, m_pos.y, m_pos.z);
    
    const std::vector<AGAudioNodeManager::AudioNodeType *> nodeTypes = AGAudioNodeManager::instance().audioNodeTypes();
    for(int i = 0; i < nodeTypes.size(); i++)
    {
        GLvertex3f iconPos = startPos + (xInc*(i%2)) + (yInc*(i/2));
        
        GLKMatrix4 modelView = GLKMatrix4Translate(baseModelView, iconPos.x, iconPos.y, iconPos.z);
        GLKMatrix3 normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
        GLKMatrix4 mvp = GLKMatrix4Multiply(projection, modelView);
        
        if(i == m_hit)
        {
            // draw highlight background
            GLKMatrix4 hitModelView = GLKMatrix4Scale(modelView, 0.5, 0.5, 0.5);
            GLKMatrix3 hitNormal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
            GLKMatrix4 hitMvp = GLKMatrix4Multiply(projection, hitModelView);
            
            GLcolor4f whiteA = GLcolor4f::white();
            whiteA.a = 0.75;
            
            glUniform4fv(s_uniformColor2, 1, (float*) &whiteA);
            glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, hitMvp.m);
            glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, hitNormal.m);
            
            glBindVertexArrayOES(s_vertexArray);
            
            glDrawArrays(GL_TRIANGLE_STRIP, s_geoFillOffset, s_geoFillSize);
            
            glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::black());
        }
        else
        {
            glUniform4fv(s_uniformColor2, 1, (float*) &GLcolor4f::white());
        }
        
        glUniformMatrix4fv(s_uniformMVPMatrix, 1, 0, mvp.m);
        glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, normal.m);
        
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


