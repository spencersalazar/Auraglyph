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
#include "AGSlider.h"
#include "AGAudioNode.h" // for sample rate
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
    m_doneEditing(false),
    m_pullTabDistance(0.5, GLvertex2f(0,0)),
    m_pullTabCapture(false)
    {
        m_width = (node->numSteps()+0.5f)*AGUISequencerEditor_stepSize;
        m_height = (node->numSequences()+1.0f)*AGUISequencerEditor_stepSize;
        m_pullTabSize = AGUISequencerEditor_stepSize/2;
        
        string ucname = m_node->title();
        for(int i = 0; i < ucname.length(); i++)
            ucname[i] = toupper(ucname[i]);
        m_title = ucname;
        
        GeoGen::makeRect(m_defaultBoxGeo, m_width, m_height);
        
        m_boxGeo[0] = m_defaultBoxGeo[0];
        m_boxGeo[1] = m_defaultBoxGeo[1];
        m_boxGeo[2] = m_defaultBoxGeo[2];
        m_boxGeo[3] = m_defaultBoxGeo[3];
        
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
        
        TexFont *text = AGStyle::standardFont64();
        float bpmSliderX = 10+text->width("bpm")*0.61+5+m_width/7/2;
        m_bpmSlider = new AGSlider(GLvertex3f(-m_width/2+bpmSliderX, m_height/2-AGUISequencerEditor_stepSize/2, 0));
        m_bpmSlider->init();
        
        m_bpmSlider->setSize(GLvertex2f(m_width/7, AGUISequencerEditor_stepSize*0.6));
        m_bpmSlider->setType(AGSlider::DISCRETE);
        m_bpmSlider->setScale(AGSlider::LINEAR);
        m_bpmSlider->setValue(m_node->bpm());
        m_bpmSlider->onUpdate([this] (float value) {
            m_node->setBpm(value);
        });
        m_bpmSlider->setValidator([] (float _old, float _new) -> float {
            if(_new < 1)
                return 1;
            return _new;
        });
        addChild(m_bpmSlider);
    }
    
    ~AGUISequencerEditor()
    {
    }
    
    virtual void update(float t, float dt)
    {
        //        AGInteractiveObject::update(t, dt);
        
        m_squeeze.update(t, dt);
        
        m_renderState.alpha = 1.0;
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
        
        m_pullTabDistance.interp();
        
        m_boxGeo[0] = m_defaultBoxGeo[0];
        m_boxGeo[1] = m_defaultBoxGeo[1];
        m_boxGeo[2] = m_defaultBoxGeo[2];
        m_boxGeo[3] = m_defaultBoxGeo[3];
        
        m_boxGeo[1] = m_boxGeo[1]+GLvertex2f(0, ((GLvertex2f)m_pullTabDistance).y);
        m_boxGeo[2] = m_boxGeo[2]+GLvertex2f(((GLvertex2f)m_pullTabDistance).x, ((GLvertex2f)m_pullTabDistance).y);
        m_boxGeo[3] = m_boxGeo[3]+GLvertex2f(((GLvertex2f)m_pullTabDistance).x, 0);
        
//        m_bpmSlider->update(t, dt);
    }
    
    virtual void render()
    {
        TexFont *text = AGStyle::standardFont64();
        int step = m_lastStep;
        int numSeq = m_node->numSequences();
        int numStep = m_node->numSteps();
//        int previousStep = step > 0 ? step-1 : numStep-1;
        
        float distX = ((GLvertex2f)m_pullTabDistance).x/AGUISequencerEditor_stepSize;
        float distY = -((GLvertex2f)m_pullTabDistance).y/AGUISequencerEditor_stepSize;
        int newStep = (int) ceilf(distX);
        int newSeq = (int) ceilf(distY);
        float stepAlpha = 1-(newStep-distX);
        float seqAlpha = 1-(newSeq-distY);
        
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
        GLcolor4f stepColor = AGStyle::lightColor();
        GLcolor4f shadeColor = GLcolor4f(stepColor.r*0.5f, stepColor.g*0.5f, stepColor.b*0.5f, stepColor.a);
        
        for(int i = 0; i < numSeq+newSeq; i++)
        {
            for(int j = 0; j < numStep+newStep; j++)
            {
                float alpha = 1;
                if(i >= numSeq || j >= numStep)
                {
                    alpha = 0.5;
                    if(i == numSeq+newSeq-1)
                        alpha *= seqAlpha;
                    if(j == numStep+newStep-1)
                        alpha *= stepAlpha;
                }
                
                stepColor.a = alpha;
                shadeColor.a = alpha;
                
                float stepVal = 0;
                float stepLength = 1;
                if(i < numSeq && j < numStep)
                {
                    stepVal = m_node->getStepValue(i, j);
                    stepLength = m_node->getStepLength(i, j);
                }
                assert(stepVal >= 0 && stepVal <= 1);
                assert(stepLength >= 0 && stepLength <= 1);
                
                GLKMatrix4 stepMV = GLKMatrix4MakeTranslation(-m_width/2+AGUISequencerEditor_stepSize*0.75+AGUISequencerEditor_stepSize*j,
                                                              m_height/2-AGUISequencerEditor_stepSize*1.375-AGUISequencerEditor_stepSize*i,
                                                              0);
                stepMV = GLKMatrix4Scale(stepMV, G_RATIO-1, G_RATIO-1, G_RATIO-1);
                
                // render step background
                glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &shadeColor);
                
                drawTriangleFan((GLvertex3f[]) {
                    { -AGUISequencerEditor_stepSize/2+AGUISequencerEditor_stepSize*stepLength, -AGUISequencerEditor_stepSize/2, 0 },
                    {  AGUISequencerEditor_stepSize/2, -AGUISequencerEditor_stepSize/2, 0 },
                    {  AGUISequencerEditor_stepSize/2, -AGUISequencerEditor_stepSize/2+AGUISequencerEditor_stepSize*stepVal, 0 },
                    { -AGUISequencerEditor_stepSize/2+AGUISequencerEditor_stepSize*stepLength, -AGUISequencerEditor_stepSize/2+AGUISequencerEditor_stepSize*stepVal, 0 },
                }, 4, stepMV);

                glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &stepColor);
                
                // render fill
                stepMV = GLKMatrix4MakeTranslation(-m_width/2+AGUISequencerEditor_stepSize*0.75+AGUISequencerEditor_stepSize*j,
                                                   m_height/2-AGUISequencerEditor_stepSize*1.375-AGUISequencerEditor_stepSize*i,
                                                   0);
                stepMV = GLKMatrix4Scale(stepMV, G_RATIO-1, G_RATIO-1, G_RATIO-1);
                
                drawTriangleFan((GLvertex3f[]) {
                    { -AGUISequencerEditor_stepSize/2, -AGUISequencerEditor_stepSize/2, 0 },
                    { -AGUISequencerEditor_stepSize/2+AGUISequencerEditor_stepSize*stepLength, -AGUISequencerEditor_stepSize/2, 0 },
                    { -AGUISequencerEditor_stepSize/2+AGUISequencerEditor_stepSize*stepLength, -AGUISequencerEditor_stepSize/2+AGUISequencerEditor_stepSize*stepVal, 0 },
                    { -AGUISequencerEditor_stepSize/2, -AGUISequencerEditor_stepSize/2+AGUISequencerEditor_stepSize*stepVal, 0 },
                }, 4, stepMV);
                
                // render outline
                drawLineLoop((GLvertex3f[]) {
                    { -AGUISequencerEditor_stepSize/2, -AGUISequencerEditor_stepSize/2, 0 },
                    {  AGUISequencerEditor_stepSize/2, -AGUISequencerEditor_stepSize/2, 0 },
                    {  AGUISequencerEditor_stepSize/2,  AGUISequencerEditor_stepSize/2, 0 },
                    { -AGUISequencerEditor_stepSize/2,  AGUISequencerEditor_stepSize/2, 0 },
                }, 4, stepMV);

            }
        }
        
        /* render outer box */
        renderPrimitive(&m_boxOuterInfo);
        
        /* render bpm text */
        proj = m_renderState.projection;
        
        titleMV = GLKMatrix4Translate(m_renderState.modelview,
                                      -m_width/2+10,
                                      m_height/2-AGUISequencerEditor_stepSize/2-text->height()*0.61/2,
                                      0);
        titleMV = GLKMatrix4Scale(titleMV, 0.61, 0.61, 0.61);
        text->render("bpm", GLcolor4f::white, titleMV, proj);
        
        /* render pull tab */
        
        GLcolor4f::white.set();
        drawTriangleFan((GLvertex3f[]) {
            m_boxGeo[2],
            m_boxGeo[2]+GLvertex3f(-m_pullTabSize, 0, 0),
            m_boxGeo[2]+GLvertex3f( 0, m_pullTabSize, 0),
        }, 3);
        
        renderChildren();
        
        debug_renderBounds();
    }
    
    virtual void touchDown(const AGTouchInfo &t)
    {
        AGInteractiveObject::touchDown(t);
        
        if(pointInTriangle(t.position.xy(),
                           (position() + (GLvertex2f)m_pullTabDistance + m_boxGeo[2]).xy(),
                           (position() + (GLvertex2f)m_pullTabDistance + m_boxGeo[2] + GLvertex3f(-m_pullTabSize, 0, 0)).xy(),
                           (position() + (GLvertex2f)m_pullTabDistance + m_boxGeo[2] + GLvertex3f( 0, m_pullTabSize, 0)).xy()))
        {
            m_pullTabCapture = true;
            m_pullTabStartTouch = t;
            m_pullTabDistance = GLvertex2f(0, 0);
        }
        else
        {
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
                        m_touchCapture[t.touchId] = {
                            .seq = i, .step = j,
                            .startPos = t.position,
                            .startValue = m_node->getStepValue(i, j),
                            .startLength = m_node->getStepLength(i, j),
                            .passedClearance = false
                        };
                        // NSLog(@"caught %i %i", i, j);
                    }
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
                float length = touch.startLength + (t.position.x - touch.startPos.x)*AGUISequencerEditor_adjustmentScale;
                length = clampf(length, 0, 1);
                m_node->setStepLength(touch.seq, touch.step, length);
//                NSLog(@"step value: %f", value);
            }
            else if((touch.startPos - t.position).magnitudeSquared() > AGUISequencerEditor_minClearance*AGUISequencerEditor_minClearance)
            {
                m_touchCapture[t.touchId].passedClearance = true;
                m_touchCapture[t.touchId].startPos = t.position;
            }
        }
        
        if(m_pullTabCapture && t.touchId == m_pullTabStartTouch.touchId)
        {
            m_pullTabDistance.reset(t.position.xy() - m_pullTabStartTouch.position.xy());
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
        
        if(m_pullTabCapture && t.touchId == m_pullTabStartTouch.touchId)
        {
            //GLvertex2f distance = t.position.xy() - m_pullTabStartTouch.position.xy();
            GLvertex2f origBRCorner = m_defaultBoxGeo[2].xy();
            
            float distX = ((GLvertex2f)m_pullTabDistance).x/AGUISequencerEditor_stepSize;
            float distY = -((GLvertex2f)m_pullTabDistance).y/AGUISequencerEditor_stepSize;
            int newStep = (int) roundf(distX);
            int newSeq = (int) roundf(distY);
            
            int numSteps = m_node->numSteps();
            int numSeqs = m_node->numSequences();
            
            m_node->setNumSteps(numSteps+newStep);
            m_node->setNumSequences(numSeqs+newSeq);
            
            float xdiff = AGUISequencerEditor_stepSize*(m_node->numSteps()-numSteps);
            float ydiff = -AGUISequencerEditor_stepSize*(m_node->numSequences()-numSeqs);
            m_defaultBoxGeo[1].y += ydiff;
            m_defaultBoxGeo[2].x += xdiff;
            m_defaultBoxGeo[2].y += ydiff;
            m_defaultBoxGeo[3].x += xdiff;
            
            m_pullTabCapture = false;
            m_pullTabDistance.reset(m_pullTabDistance-(m_defaultBoxGeo[2].xy()-origBRCorner));
            m_pullTabDistance = GLvertex2f(0, 0);
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
    
    virtual GLvrectf effectiveBounds()
    {
        return GLvrectf(position()+m_boxGeo[1], position()+m_boxGeo[3]);
    }
    
private:
    
    AGControlSequencerNode * const m_node;
    
    string m_title;
    
    float m_width, m_height;
    float m_pullTabSize;
    AGRenderInfoV m_boxOuterInfo, m_boxInnerInfo;
    GLvertex3f m_defaultBoxGeo[4];
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
        float startLength;
        bool passedClearance;
    };
    
    map<TouchID, TouchCapture> m_touchCapture;
    
    bool m_pullTabCapture = false;
    AGTouchInfo m_pullTabStartTouch;
    slew<GLvertex2f> m_pullTabDistance;
    
    int m_lastStep;
    expcurvef m_lastStepAlpha;
    
    AGSlider *m_bpmSlider;
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
        { PARAM_ADVANCE, "advance", true, true, .doc = "Triggers step to advance by one." },
        { PARAM_BPM, "bpm", true, true, 120, 0, AGFloat_Max, .doc = "BPM of sequencer." },
    };
};

vector<AGPortInfo> AGControlSequencerNode::Manifest::_editPortInfo() const
{
    return {
        { PARAM_BPM, "bpm", true, true, 120, 0, AGFloat_Max, .doc = "BPM of sequencer." },
    };
};

// XXX TODO: not sure how to handle this b/c the sequencer handles multiple outputs differently
vector<AGPortInfo> AGControlSequencerNode::Manifest::_outputPortInfo() const { return { }; };

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

void AGControlSequencerNode::initFinal()
{
    m_numSteps = 8;
    m_pos = 0;
    // add default sequence
    m_sequence.push_back(std::vector<Step>(m_numSteps));
    for(auto i = m_sequence.begin(); i != m_sequence.end(); i++)
        for(auto j = i->begin(); j != i->end(); j++)
            *j = Step(Random::unit(), 0.5);
    
    // apparently Block_copy is necessary since ARC doesn't work in C++(?)
//    m_timer = AGTimer(60.0f/param(PARAM_BPM).getFloat(), Block_copy(^(AGTimer *) {
//        if(numInputsForPort(PARAM_ADVANCE) == 0)
//            updateStep();
//    }));
    AGAudioManager_::instance().addAudioRateProcessor(this);
}

void AGControlSequencerNode::deserializeFinal(const AGDocument::Node &docNode)
{
    if(docNode.params.count("seq_steps"))
        m_numSteps = docNode.params.at("seq_steps").i;
    else
        m_numSteps = 8;
    m_pos = 0;
    
    if(docNode.params.count("num_seqs"))
    {
        int num_seqs = docNode.params.at("num_seqs").i;
        m_sequence.clear();
        for(int seq = 0; seq < num_seqs; seq++)
        {
            m_sequence.push_back(std::vector<Step>(m_numSteps));
            
            string seqkey = "seq" + std::to_string(seq);
            if(docNode.params.count(seqkey))
            {
                auto stepValue = docNode.params.at(seqkey).fa.begin();
                for(int step = 0; step < numSteps(); step++)
                    m_sequence[seq][step].value = *stepValue++;
            }
            
            string seqlenkey = "seq" + std::to_string(seq) + "len";
            if(docNode.params.count(seqlenkey))
            {
                auto stepValue = docNode.params.at(seqlenkey).fa.begin();
                for(int step = 0; step < numSteps(); step++)
                    m_sequence[seq][step].length = *stepValue++;
            }
        }
    }
    else
    {
        m_sequence.push_back(std::vector<Step>(m_numSteps));
    }
}

AGControlSequencerNode::~AGControlSequencerNode()
{
    AGAudioManager_::instance().removeAudioRateProcessor(this);
}

AGUINodeEditor *AGControlSequencerNode::createCustomEditor()
{
    return new AGUISequencerEditor(this);
}

int AGControlSequencerNode::numOutputPorts() const
{
    return m_sequence.size();
}

void AGControlSequencerNode::process(sampletime _t)
{
    float t = ((float)_t)/AGAudioNode::sampleRate();
    
    if(m_t == -1)
    {
        m_t = t;
        m_lastStep = t;
        
        return;
    }
    
    // don't automatically advance if there is an advance input
    if(numInputsForPort(PARAM_ADVANCE))
        return;
    
    float bpm = param(PARAM_BPM);
    float stepLength = 60.0/bpm;
    float stepTime = t-m_lastStep;
    if(stepTime >= stepLength)
    {
        updateStep();
        m_lastStep = t;
    }
    else
    {
        m_seqLock.lock();
        
        for(int seq = 0; seq < m_sequence.size(); seq++)
        {
            if(stepTime > m_sequence[seq][m_pos].length*stepLength)
            {
                pushControl(seq, 0);
            }
        }
        
        m_seqLock.unlock();
    }
    
    m_t = t;
}

void AGControlSequencerNode::receiveControl(int port, const AGControl &control)
{
    if(port == m_param2InputPort[PARAM_ADVANCE] && control.getFloat() > 0)
        updateStep();
    else if (port == m_param2InputPort[PARAM_BPM])
        setBpm(control.getFloat());
}

int AGControlSequencerNode::currentStep()
{
    return m_pos;
}

int AGControlSequencerNode::numSequences()
{
    return m_sequence.size();
}

void AGControlSequencerNode::setNumSequences(int num)
{
    m_seqLock.lock();
    
    if(num < 1)
        num = 1;
    
    if(num < m_sequence.size())
        m_sequence.resize(num);
    else if(num > m_sequence.size())
        m_sequence.resize(num, std::vector<Step>(m_numSteps));
    
    m_seqLock.unlock();
}

int AGControlSequencerNode::numSteps()
{
    return m_numSteps;
}

void AGControlSequencerNode::setNumSteps(int num)
{
    m_seqLock.lock();
    
    if(num < 4)
        num = 4;
    
    if(m_numSteps != num)
    {
        for(int i = 0; i < m_sequence.size(); i++)
            m_sequence[i].resize(num);
        m_numSteps = num;
    }
    
    m_seqLock.unlock();
}


float AGControlSequencerNode::bpm()
{
    return param(PARAM_BPM);
}

void AGControlSequencerNode::setBpm(float bpm)
{
    setParam(PARAM_BPM, validateParam(PARAM_BPM, bpm));
    m_timer.setInterval(60.0/param(PARAM_BPM).getFloat());
}

void AGControlSequencerNode::updateStep()
{
    m_seqLock.lock();
    
    m_pos = (m_pos + 1) % m_numSteps;
    
    for(int seq = 0; seq < m_sequence.size(); seq++)
        pushControl(seq, AGControl(m_sequence[seq][m_pos].value));
    
    m_seqLock.unlock();
}

void AGControlSequencerNode::setStepValue(int seq, int step, float value)
{
    m_seqLock.lock();
    
    m_sequence[seq][step].value = value;
    
    m_seqLock.unlock();
}

void AGControlSequencerNode::setStepLength(int seq, int step, float length)
{
    m_seqLock.lock();
    
    m_sequence[seq][step].length = length;
    
    m_seqLock.unlock();
}

float AGControlSequencerNode::getStepValue(int seq, int step)
{
    return m_sequence[seq][step].value;
}

float AGControlSequencerNode::getStepLength(int seq, int step)
{
    return m_sequence[seq][step].length;
}

void AGControlSequencerNode::editPortValueChanged(int paramId)
{
    if(paramId == PARAM_BPM)
        m_timer.setInterval(60.0/param(PARAM_BPM).getFloat());
}

AGDocument::Node AGControlSequencerNode::serialize()
{
    AGDocument::Node docNode = AGNode::serialize();
    
    docNode.params["seq_steps"] = AGDocument::ParamValue(numSteps());
    docNode.params["num_seqs"] = AGDocument::ParamValue(numSequences());
    
    for(int seq = 0; seq < numSequences(); seq++)
    {
        string seqkey = "seq" + std::to_string(seq);
        docNode.params[seqkey].type = AGDocument::ParamValue::FLOAT_ARRAY;
        string seqlenkey = "seq" + std::to_string(seq) + "len";
        docNode.params[seqlenkey].type = AGDocument::ParamValue::FLOAT_ARRAY;
        for(int step = 0; step < numSteps(); step++)
        {
            docNode.params[seqkey].fa.push_back(getStepValue(seq, step));
            docNode.params[seqlenkey].fa.push_back(getStepLength(seq, step));
        }
    }
    
    return std::move(docNode);
}



