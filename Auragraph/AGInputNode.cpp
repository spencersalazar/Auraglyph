//
//  AGInputNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 4/13/15.
//  Copyright (c) 2015 Spencer Salazar. All rights reserved.
//

#include "AGInputNode.h"
#include "spstl.h"
#include "AGStyle.h"
#include "AGGenericShader.h"
#include "ES2Render.h"


//------------------------------------------------------------------------------
// ### AGInputNode ###
//------------------------------------------------------------------------------
#pragma mark - AGInputNode

bool AGInputNode::s_init = false;
GLuint AGInputNode::s_vertexArray = 0;
GLuint AGInputNode::s_vertexBuffer = 0;
GLvncprimf *AGInputNode::s_geo = NULL;
GLuint AGInputNode::s_geoSize = 0;
float AGInputNode::s_radius = 0;

void AGInputNode::initializeInputNode()
{
    initalizeNode();
    
    if(!s_init)
    {
        s_init = true;
        
        // generate triangle
        s_geoSize = 3;
        s_geo = new GLvncprimf[s_geoSize];
        float radius = AGNode::s_sizeFactor/1.15;
        
        // equilateral triangle pointing down
        float H = radius*2*sqrtf(0.75);         // height from base to tip
        float up = (H*H - radius*radius)/(2*H); // vertical distance from 2d centroid to base
        up = (up+H/2.0f)/2.0f;                  // average with vertical midpoint for better aesthetics
        float down = H - up;                    // vertical distance from center position to tip
        
        s_geo[0].vertex = GLvertex3f(-radius, up, 0);
        s_geo[1].vertex = GLvertex3f(radius, up, 0);
        s_geo[2].vertex = GLvertex3f(0, -down, 0);
        
        glGenVertexArraysOES(1, &s_vertexArray);
        glBindVertexArrayOES(s_vertexArray);
        
        glGenBuffers(1, &s_vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, s_vertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, s_geoSize*sizeof(GLvncprimf), s_geo, GL_STATIC_DRAW);
        
        glEnableVertexAttribArray(AGVertexAttribPosition);
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(0));
        glEnableVertexAttribArray(AGVertexAttribNormal);
        glVertexAttribPointer(AGVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(sizeof(GLvertex3f)));
        glEnableVertexAttribArray(AGVertexAttribColor);
        glVertexAttribPointer(AGVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(2*sizeof(GLvertex3f)));
        
        glBindVertexArrayOES(0);
    }
}

AGInputNode::AGInputNode(const AGNodeManifest *mf, const GLvertex3f &pos) :
AGNode(mf, pos)
{
    initializeInputNode();
}

AGInputNode::AGInputNode(const AGNodeManifest *mf, const AGDocument::Node &docNode) :
AGNode(mf, docNode)
{
    initializeInputNode();
}

void AGInputNode::update(float t, float dt)
{
    AGNode::update(t, dt);
    
    GLKMatrix4 projection = projectionMatrix();
    GLKMatrix4 modelView = globalModelViewMatrix();
    
    modelView = GLKMatrix4Translate(modelView, m_pos.x, m_pos.y, m_pos.z);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, modelView);
    m_renderState.modelview = modelView;
    m_renderState.projection = projection;
}

void AGInputNode::render()
{
    glBindVertexArrayOES(s_vertexArray);
    
    GLcolor4f color = GLcolor4f::white;
    color.a = m_fadeOut;
    glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &color);
    glDisableVertexAttribArray(AGVertexAttribColor);
    
    // TODO
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setMVPMatrix(m_modelViewProjectionMatrix);
    shader.setNormalMatrix(m_normalMatrix);
    
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, 0, s_geoSize);
    
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    AGNode::render();
}


AGNode::HitTestResult AGInputNode::hit(const GLvertex3f &hit)
{
    return HIT_NONE;
}

void AGInputNode::unhit()
{
    
}

AGInteractiveObject *AGInputNode::hitTest(const GLvertex3f &t)
{
    GLvertex2f posxy = m_pos.xy();
    if(pointInTriangle(t.xy(), s_geo[0].vertex.xy()+posxy,
                       s_geo[1].vertex.xy()+posxy,
                       s_geo[2].vertex.xy()+posxy))
        return this;
    return _hitTestConnections(t);
}

GLvertex3f AGInputNode::relativePositionForOutputPort(int port) const
{
    float radius = AGNode::s_sizeFactor/1.15;
    
    // equilateral triangle pointing down
    float H = radius*2*sqrtf(0.75);         // height from base to tip
    float up = (H*H - radius*radius)/(2*H); // vertical distance from 2d centroid to base
    up = (up+H/2.0f)/2.0f;                  // average with vertical midpoint for better aesthetics
    float down = H - up;                    // vertical distance from center position to tip
    
    return GLvertex3f(0, -down, 0);
}


//------------------------------------------------------------------------------
// ### AGSliderNode ###
//------------------------------------------------------------------------------

class AGSliderNode : public AGInputNode
{
public:
    class Manifest : public AGStandardNodeManifest<AGSliderNode>
    {
    public:
        string _type() const override { return "Slider"; };
        string _name() const override { return "Slider"; };
        string _description() const override { return "Continuous control input slider."; };

        vector<AGPortInfo> _inputPortInfo() const override { return {}; };
        vector<AGPortInfo> _editPortInfo() const override { return {}; };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 0.002*AGStyle::oldGlobalScale;
            float height = 0.003*AGStyle::oldGlobalScale;
            int circleSize = 48;
            vector<GLvertex3f> iconGeo(circleSize);
            
            for(int i = 0; i < circleSize; i++)
            {
                float y_offset = height;
                if(i >= circleSize/2)
                    y_offset = -height;
                float theta0 = 2*M_PI*((float)i)/((float)(circleSize));
                iconGeo[i] = GLvertex3f(radius*cosf(theta0), radius*sinf(theta0)+y_offset, 0);
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINE_LOOP; };
    };
    
    using AGInputNode::AGInputNode;
};


//------------------------------------------------------------------------------
// ### AGNodeManager ###
//------------------------------------------------------------------------------
#pragma mark - AGNodeManager

const AGNodeManager &AGNodeManager::inputNodeManager()
{
    if(s_inputNodeManager == NULL)
    {
        s_inputNodeManager = new AGNodeManager();
        
        vector<const AGNodeManifest *> &nodeTypes = s_inputNodeManager->m_nodeTypes;
        
        nodeTypes.push_back(new AGSliderNode::Manifest);
        
        for(const AGNodeManifest *const &mf : nodeTypes)
            mf->initialize();
    }
    
    return *s_inputNodeManager;
}
