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
#include "AGGenericShader.h"
#include "AGStyle.h"
#include "spRandom.h"

#include <string>

//------------------------------------------------------------------------------
// ### AGUISequencerEditor ###
//------------------------------------------------------------------------------
#pragma mark - AGUISequencerEditor

static const float AGUISequencerEditor_stepSize = 0.01f*AGStyle::oldGlobalScale;
static const float AGUISequencerEditor_minClearance = AGUISequencerEditor_stepSize/20;
static const float AGUISequencerEditor_adjustmentScale = 75/AGStyle::oldGlobalScale;

class AGUISequencerEditor : public AGUINodeEditor
{
public:

    static void initializeNodeEditor();
    
    AGUISequencerEditor(AGControlSequencerNode *node) :
    m_node(node),
    m_doneEditing(false)
    {
        m_width = (node->numSteps()+0.5f)*AGUISequencerEditor_stepSize;
        m_height = (node->numSequences()+1.0f)*AGUISequencerEditor_stepSize;
        
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
        
        GeoGen::makeRect(m_stepGeo, AGUISequencerEditor_stepSize, AGUISequencerEditor_stepSize);
        
        m_squeeze.open();
        
        m_lastStep = 0;
        m_lastStepAlpha = expcurvef(1, 0, 4, 2);
        m_lastStepAlpha.finish();
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
        
        int step = m_node->currentStep();
        
        if(step != m_lastStep)
        {
            m_lastStepAlpha.reset();
        }
        
        m_lastStep = step;
        
        m_lastStepAlpha.update(dt);
    }
    
    virtual void render()
    {
        TexFont *text = AGStyle::standardFont64();
        int step = m_lastStep;
        int numSeq = m_node->numSequences();
        int numStep = m_node->numSteps();
//        int previousStep = step > 0 ? step-1 : numStep-1;
        
        /* render inner box */
        renderPrimitive(&m_boxInnerInfo);
        
        /* render title */
        GLKMatrix4 proj = m_renderState.projection;
        
        GLKMatrix4 titleMV = GLKMatrix4Translate(m_renderState.modelview,
                                                 -m_width/2+AGStyle::editor_titleInset.x,
                                                 m_height/2-AGStyle::editor_titleInset.y,
                                                 0);
        titleMV = GLKMatrix4Scale(titleMV, 0.61, 0.61, 0.61);
        text->render(m_title, GLcolor4f::white, titleMV, proj);
        
        /* render step indicator */
        
        AGRenderInfoV counterInfo;
        counterInfo.numVertex = 4;
        counterInfo.geoOffset = 0;
        counterInfo.geoType = GL_LINE_LOOP;
        counterInfo.geo = m_stepGeo;
        counterInfo.color = AGStyle::lightColor();
        counterInfo.color.a = 0.5f;
        
        GLKMatrix4 posMV = GLKMatrix4Translate(m_renderState.modelview,
                                               -m_width/2+AGUISequencerEditor_stepSize*0.75f+AGUISequencerEditor_stepSize*step,
                                               m_height/2-AGUISequencerEditor_stepSize*1.375f-AGUISequencerEditor_stepSize*(numSeq-1)/2.0f,
                                               0);
        posMV = GLKMatrix4Scale(posMV, 1, numSeq, 1);
        
        counterInfo.shader->useProgram();
        counterInfo.shader->setMVPMatrix(GLKMatrix4Multiply(m_renderState.projection, posMV));
        counterInfo.shader->setNormalMatrix(m_renderState.normal);
        
        counterInfo.set(m_renderState);
        
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        
        /* render previous step indicator */
        
//        counterInfo.color.a = 0.5f*m_lastStepAlpha;
//        
//        posMV = GLKMatrix4Translate(m_renderState.modelview,
//                                    -m_width/2+AGUISequencerEditor_stepSize*0.75f+AGUISequencerEditor_stepSize*previousStep,
//                                    m_height/2-AGUISequencerEditor_stepSize*1.375f-AGUISequencerEditor_stepSize*numSeq/4.0f,
//                                    0);
//        posMV = GLKMatrix4Scale(posMV, 1, m_node->numSequences(), 1);
//        
//        counterInfo.shader->useProgram();
//        counterInfo.shader->setMVPMatrix(GLKMatrix4Multiply(m_renderState.projection, posMV));
//        counterInfo.shader->setNormalMatrix(m_renderState.normal);
//        
//        counterInfo.set(m_renderState);
//        
//        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

        /* render step grid */
        AGRenderInfoV stepInfo;
        stepInfo.numVertex = 4;
        stepInfo.geoOffset = 0;
        stepInfo.geoType = GL_LINE_LOOP;
        stepInfo.geo = m_stepGeo;
        stepInfo.color = AGStyle::lightColor();
        
        for(int i = 0; i < numSeq; i++)
        {
            for(int j = 0; j < numStep; j++)
            {
                // render outline
                GLKMatrix4 stepMV = GLKMatrix4Translate(m_renderState.modelview,
                                                        -m_width/2+AGUISequencerEditor_stepSize*0.75+AGUISequencerEditor_stepSize*j,
                                                        m_height/2-AGUISequencerEditor_stepSize*1.375-AGUISequencerEditor_stepSize*i,
                                                        0);
                stepMV = GLKMatrix4Scale(stepMV, G_RATIO-1, G_RATIO-1, G_RATIO-1);
                
                stepInfo.shader->useProgram();
                stepInfo.shader->setMVPMatrix(GLKMatrix4Multiply(m_renderState.projection, stepMV));
                stepInfo.shader->setNormalMatrix(m_renderState.normal);
                stepInfo.geoType = GL_LINE_LOOP;
                stepInfo.set(m_renderState);
                
                glDrawArrays(GL_LINE_LOOP, 0, 4);
                
                // render fill
                float stepVal = m_node->getStepValue(i, j);
                
                stepMV = GLKMatrix4Translate(m_renderState.modelview,
                                             -m_width/2+AGUISequencerEditor_stepSize*0.75+AGUISequencerEditor_stepSize*j,
                                             m_height/2-AGUISequencerEditor_stepSize*1.375-AGUISequencerEditor_stepSize*i,
                                             0);
                stepMV = GLKMatrix4Scale(stepMV, G_RATIO-1, G_RATIO-1, G_RATIO-1);
                stepMV = GLKMatrix4Translate(stepMV, 0, -AGUISequencerEditor_stepSize*(1.0f-stepVal)/2.0, 0);
                stepMV = GLKMatrix4Scale(stepMV, 1, stepVal, 1);
                
                stepInfo.shader->useProgram();
                stepInfo.shader->setMVPMatrix(GLKMatrix4Multiply(m_renderState.projection, stepMV));
                stepInfo.shader->setNormalMatrix(m_renderState.normal);
                stepInfo.geoType = GL_TRIANGLE_FAN;
                stepInfo.set(m_renderState);
                
                glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
            }
        }
        
        /* render outer box */
        renderPrimitive(&m_boxOuterInfo);
        
        debug_renderBounds();
    }
    
    virtual void touchDown(const AGTouchInfo &t)
    {
        AGInteractiveObject::touchDown(t);
        
        int numSeq = m_node->numSequences();
        int numStep = m_node->numSteps();

        for(int i = 0; i < numSeq; i++)
        {
            for(int j = 0; j < numStep; j++)
            {
                GLvertex2f stepPos = GLvertex2f(m_node->position().x-m_width/2+AGUISequencerEditor_stepSize*0.75+AGUISequencerEditor_stepSize*j,
                                                m_node->position().y+m_height/2-AGUISequencerEditor_stepSize*1.375-AGUISequencerEditor_stepSize*i);
                GLvertex2f stepSize = GLvertex2f(AGUISequencerEditor_stepSize, AGUISequencerEditor_stepSize);
                
                if(pointInRectangle(t.position.xy(),
                                    stepPos-stepSize/2.0f,
                                    stepPos+stepSize/2.0f))
                {
                    m_touchCapture[t.touchId] = { i, j, t.position, m_node->getStepValue(i, j), false };
//                    NSLog(@"caught %i %i", i, j);
                }
            }
        }
    }
    
    virtual void touchMove(const AGTouchInfo &t)
    {
        AGInteractiveObject::touchMove(t);
        
        if(m_touchCapture.count(t.touchId))
        {
            TouchCapture touch = m_touchCapture[t.touchId];
            if(touch.passedClearance)
            {
                float value = touch.startValue + (t.position.y - touch.startPos.y)*AGUISequencerEditor_adjustmentScale;
                value = clampf(value, 0, 1);
                m_node->setStepValue(touch.seq, touch.step, value);
//                NSLog(@"step value: %f", value);
            }
            else if(fabsf(touch.startPos.y - t.position.y) > AGUISequencerEditor_minClearance)
            {
                m_touchCapture[t.touchId].passedClearance = true;
                m_touchCapture[t.touchId].startPos = t.position;
            }
        }
    }
    
    virtual void touchUp(const AGTouchInfo &t)
    {
        AGInteractiveObject::touchUp(t);
        
//        NSLog(@"touchUp %i %f %f %f", t.touchId, t.position.x, t.position.y, t.position.z);

        if(m_touchCapture.count(t.touchId))
        {
            TouchCapture touch = m_touchCapture[t.touchId];
            if(!touch.passedClearance)
                // flip it
                m_node->setStepValue(touch.seq, touch.step, touch.startValue > 0.1f ? 0.0f : 1.0f);
            m_touchCapture.erase(t.touchId);
        }
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
    
    GLvertex3f m_stepGeo[4];
    
    GLKMatrix4 m_modelView;
    AGSqueezeAnimation m_squeeze;
    
    bool m_doneEditing;
    
    struct TouchCapture
    {
        int seq;
        int step;
        GLvertex3f startPos;
        float startValue;
        bool passedClearance;
    };
    
    map<TouchID, TouchCapture> m_touchCapture;
    
    int m_lastStep;
    expcurvef m_lastStepAlpha;
};


//------------------------------------------------------------------------------
// ### AGControlSequencerNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlSequencerNode

string AGControlSequencerNode::Manifest::_type() const { return "Sequencer"; };
string AGControlSequencerNode::Manifest::_name() const { return "Sequencer"; };

vector<AGPortInfo> AGControlSequencerNode::Manifest::_inputPortInfo() const
{
    return {
        { "bpm", true, true }
    };
};

vector<AGPortInfo> AGControlSequencerNode::Manifest::_editPortInfo() const { return { }; };

vector<GLvertex3f> AGControlSequencerNode::Manifest::_iconGeo() const
{
    float radius = 0.005*AGStyle::oldGlobalScale;
    int gridSize = 5;
    int NUM_PTS = gridSize*4;
    vector<GLvertex3f> iconGeo(NUM_PTS);
    
    // horizontal grid lines
    for(int i = 0; i < gridSize; i++)
    {
        float y = radius*2*i/(gridSize-1);
        iconGeo[i*2+0] = GLvertex3f(-radius, radius-y, 0);
        iconGeo[i*2+1] = GLvertex3f( radius, radius-y, 0);
    }
    
    // vertical grid lines
    for(int i = 0; i < gridSize; i++)
    {
        float x = radius*2*i/(gridSize-1);
        iconGeo[gridSize*2+i*2+0] = GLvertex3f(-radius+x,  radius, 0);
        iconGeo[gridSize*2+i*2+1] = GLvertex3f(-radius+x, -radius, 0);
    }
    
    // TODO: filled-in grid squares
    
    return iconGeo;
};

GLuint AGControlSequencerNode::Manifest::_iconGeoType() const { return GL_LINES; };


AGControlSequencerNode::AGControlSequencerNode(const AGNodeManifest *mf, const GLvertex3f &pos) :
AGControlNode(mf, pos)
{
    m_bpm = 120;
    m_numSteps = 8;
    m_pos = 0;
    // add default sequence
    m_sequence.push_back(std::vector<float>(m_numSteps, 0));
//    m_sequence.push_back(std::vector<float>(m_numSteps, 0));
    for(auto i = m_sequence.begin(); i != m_sequence.end(); i++)
        for(auto j = i->begin(); j != i->end(); j++)
            *j = Random::unit();
//    m_control.v = 0;
    
    m_timer = new AGTimer(60.0/m_bpm, ^(AGTimer *) {
        updateStep();
    });
}

AGControlSequencerNode::AGControlSequencerNode(const AGNodeManifest *mf, const AGDocument::Node &docNode) :
AGControlNode(mf, docNode)
{
    m_bpm = 120;
    m_numSteps = 8;
    m_pos = 0;
    // add default sequence
    m_sequence.push_back(std::vector<float>(m_numSteps, 0));
    m_sequence.push_back(std::vector<float>(m_numSteps, 0));
    for(auto i = m_sequence.begin(); i != m_sequence.end(); i++)
        for(auto j = i->begin(); j != i->end(); j++)
            *j = Random::unit();
//    m_control.v = 0;
    
    m_timer = new AGTimer(60.0/m_bpm, ^(AGTimer *) {
        updateStep();
    });
}

AGControlSequencerNode::~AGControlSequencerNode()
{
    delete m_timer;
    m_timer = NULL;
}

AGUINodeEditor *AGControlSequencerNode::createCustomEditor()
{
    return new AGUISequencerEditor(this);
}

int AGControlSequencerNode::numOutputPorts() const
{
    return m_sequence.size();
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
    
//    m_control.v = m_sequence[0][m_pos];
    pushControl(0, AGControl(m_sequence[0][m_pos]));
}

void AGControlSequencerNode::setStepValue(int seq, int step, float value)
{
    m_sequence[seq][step] = value;
}

float AGControlSequencerNode::getStepValue(int seq, int step)
{
    return m_sequence[seq][step];
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



