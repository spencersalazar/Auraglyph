//
//  AGControlSequencerNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 3/12/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGControlSequencerNode.h"
#include "AGUINodeEditor.h"
#include "AGStyle.h"
#include "GeoGenerator.h"
#include "AGTimer.h"

#include <string>

//------------------------------------------------------------------------------
// ### AGUISequencerEditor ###
//------------------------------------------------------------------------------
#pragma mark - AGUISequencerEditor

class AGUISequencerEditor : public AGUINodeEditor
{
public:

    static void initializeNodeEditor();
    
    AGUISequencerEditor(AGControlSequencerNode *node) :
    m_node(node),
    m_doneEditing(false)
    {
        m_width = 0.08f;
        m_height = 0.06f;
        
        string ucname = m_node->title();
        for(int i = 0; i < ucname.length(); i++)
            ucname[i] = toupper(ucname[i]);
        m_title = ucname;
        
        GeoGen::makeRect(m_boxGeo, m_width, m_height);
        
        m_boxOuterInfo.geo = m_boxGeo;
        m_boxOuterInfo.geoType = GL_LINE_LOOP;
        m_boxOuterInfo.numVertex = 4;
        m_boxOuterInfo.color = AGStyle::lightColor();
        m_renderList.push_back(&m_boxOuterInfo);
        
        m_boxInnerInfo.geo = m_boxGeo;
        m_boxInnerInfo.geoType = GL_TRIANGLE_FAN;
        m_boxInnerInfo.numVertex = 4;
        m_boxInnerInfo.color = AGStyle::frameBackgroundColor();
        m_renderList.push_back(&m_boxInnerInfo);
        
        m_squeeze.open();
    }
    
    ~AGUISequencerEditor()
    {
    }
    
    virtual void update(float t, float dt)
    {
        //        AGInteractiveObject::update(t, dt);
        
        m_squeeze.update(t, dt);
        
        m_modelView = AGNode::globalModelViewMatrix();
        m_renderState.projection = AGNode::projectionMatrix();
        
        m_modelView = GLKMatrix4Translate(m_modelView, m_node->position().x, m_node->position().y, m_node->position().z);
        
        m_modelView = GLKMatrix4Multiply(m_modelView, m_squeeze.matrix());
        
        m_renderState.modelview = m_modelView;
        m_renderState.normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_modelView), NULL);
        
        updateChildren(t, dt);
    }
    
    virtual void render()
    {
        renderPrimitive(&m_boxInnerInfo);
        
        TexFont *text = AGStyle::standardFont64();

        /* render title */
        GLKMatrix4 proj = m_renderState.projection;
        
        GLKMatrix4 titleMV = GLKMatrix4Translate(m_renderState.modelview,
                                                 -m_width/2+AGStyle::editor_titleInset.x,
                                                 m_height/2-AGStyle::editor_titleInset.y,
                                                 0);
        titleMV = GLKMatrix4Scale(titleMV, 0.61, 0.61, 0.61);
        text->render(m_title, GLcolor4f::white, titleMV, proj);
        
        /* render content */
        if(m_squeeze.isHorzOpen())
        {
            renderPrimitive(&m_boxOuterInfo);
            renderChildren();
        }
        else
        {
            renderChildren();
            renderPrimitive(&m_boxOuterInfo);
        }
        
        debug_renderBounds();
    }
    
    virtual void touchDown(const AGTouchInfo &t)
    {
        AGInteractiveObject::touchDown(t);
    }
    
    virtual void touchMove(const AGTouchInfo &t)
    {
        AGInteractiveObject::touchMove(t);
    }
    
    virtual void touchUp(const AGTouchInfo &t)
    {
        AGInteractiveObject::touchUp(t);
    }
    
    void renderOut()
    {
        m_squeeze.close();
        
        AGInteractiveObject::renderOut();
    }
    
    bool finishedRenderingOut()
    {
        return m_squeeze.finishedClosing();
    }
    
    virtual bool doneEditing() { return m_doneEditing; }
    
    virtual GLvertex3f position() { return m_node->position(); }
    virtual GLvertex2f size() { return GLvertex2f(m_width, m_height); }
    
private:
    
    AGControlSequencerNode * const m_node;
    
    string m_title;
    
    float m_width, m_height;
    AGRenderInfoV m_boxOuterInfo, m_boxInnerInfo;
    GLvertex3f m_boxGeo[4];
    
    GLKMatrix4 m_modelView;
    AGSqueezeAnimation m_squeeze;
    
    bool m_doneEditing;
};


//------------------------------------------------------------------------------
// ### AGControlSequencerNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlSequencerNode

AGNodeInfo *AGControlSequencerNode::s_nodeInfo = NULL;

void AGControlSequencerNode::initialize()
{
    s_nodeInfo = new AGNodeInfo;
    
    s_nodeInfo->type = "Sequencer";
    
    float radius = 0.005;
    int gridSize = 5;
    s_nodeInfo->iconGeoSize = gridSize*4;
    s_nodeInfo->iconGeoType = GL_LINES;
    s_nodeInfo->iconGeo = new GLvertex3f[s_nodeInfo->iconGeoSize];
    
    // horizontal grid lines
    for(int i = 0; i < gridSize; i++)
    {
        float y = radius*2*i/(gridSize-1);
        s_nodeInfo->iconGeo[i*2+0] = GLvertex3f(-radius, radius-y, 0);
        s_nodeInfo->iconGeo[i*2+1] = GLvertex3f( radius, radius-y, 0);
    }
    
    // vertical grid lines
    for(int i = 0; i < gridSize; i++)
    {
        float x = radius*2*i/(gridSize-1);
        s_nodeInfo->iconGeo[gridSize*2+i*2+0] = GLvertex3f(-radius+x,  radius, 0);
        s_nodeInfo->iconGeo[gridSize*2+i*2+1] = GLvertex3f(-radius+x, -radius, 0);
    }
    
    // TODO: filled-in grid squares
    
    s_nodeInfo->editPortInfo.push_back({ "bpm", true, true });
    s_nodeInfo->inputPortInfo.push_back({ "bpm", true, true });
}

AGControlSequencerNode::AGControlSequencerNode(const GLvertex3f &pos) :
AGControlNode(pos, s_nodeInfo)
{
    m_bpm = 120;
    m_numSteps = 8;
    // add default sequence
    m_sequence.push_back(std::vector<float>(m_numSteps, 0));
    m_control.v = 0;
    
    m_timer = new AGTimer(60.0/m_bpm, ^(AGTimer *) {
        updateStep();
    });
}

AGControlSequencerNode::AGControlSequencerNode(const AGDocument::Node &docNode) : AGControlNode(docNode, s_nodeInfo)
{
    m_bpm = 120;
    m_numSteps = 8;
    // add default sequence
    m_sequence.push_back(std::vector<float>(m_numSteps, 0));
    m_control.v = 0;
    
    m_timer = new AGTimer(60.0/m_bpm, ^(AGTimer *) {
        updateStep();
    });
}

AGControlSequencerNode::~AGControlSequencerNode()
{
    delete m_timer;
    m_timer = NULL;
}

void AGControlSequencerNode::update(float t, float dt)
{
    AGControlNode::update(t, dt);
}

void AGControlSequencerNode::render()
{
    AGControlNode::render();
}

AGUINodeEditor *AGControlSequencerNode::createCustomEditor()
{
    return new AGUISequencerEditor(this);
}


int AGControlSequencerNode::currentStep()
{
    return m_pos;
}

int AGControlSequencerNode::numSequences()
{
    return m_sequence.size();
}

int AGControlSequencerNode::numSteps()
{
    return m_numSteps;
}

void AGControlSequencerNode::updateStep()
{
    m_pos = (m_pos + 1) % m_numSteps;
    
    m_control.v = m_sequence[0][m_pos];
    pushControl(0, &m_control);
}

void AGControlSequencerNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
        case 0: m_bpm = value; m_timer->setInterval(60.0/m_bpm); break;
    }
}

void AGControlSequencerNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
        case 0: value = m_bpm; break;
    }
}

void AGControlSequencerNode::renderIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_nodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_nodeInfo->iconGeoType, 0, s_nodeInfo->iconGeoSize);
}

AGNode *AGControlSequencerNode::create(const GLvertex3f &pos)
{
    return new AGControlTimerNode(pos);
}



