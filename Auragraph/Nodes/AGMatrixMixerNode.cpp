//
//  AGMatrixMixerNode.cpp
//  Auragraph
//
//  Created by Andrew Piepenbrink on 7/13/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGMatrixMixerNode.h"
#include "AGUINodeEditor.h"
#include "AGSlider.h"

#include "GeoGenerator.h"

class AGMatrixMixerEditor : public AGUINodeEditor
{
private:
    AGAudioMatrixMixerNode * const m_node;
    float m_width, m_height;
    
    AGSqueezeAnimation m_squeeze;
    bool m_doneEditing;
    
    std::vector<GLvertex3f> m_pinInfoGeo;
    AGUIIconButton *m_pinButton;
    
public:
    AGMatrixMixerEditor(AGAudioMatrixMixerNode *node) :
    m_node(node), m_doneEditing(false)
    {
        m_squeeze.open();
        
        m_width = 425;
        m_height = m_width/2;        
        float hmargin = 10;
        float sliderWidth = 80;
        float sliderHeight = 32;
        
        AGUILabel *titleLabel = new AGUILabel(GLvertex3f(0, 0, 0), "MATRIX MIXER");
        titleLabel->init();
        titleLabel->setSize(titleLabel->naturalSize());
        GLvertex2f offset = GLvertex2f(titleLabel->size().x/2+hmargin, -titleLabel->size().y/2-hmargin);
        titleLabel->setPosition(GLvertex2f(-m_width/2, m_height/2)+offset);
        addChild(titleLabel);
        
        GLvertex3f sliderPos = titleLabel->position()+GLvertex3f(-sliderWidth/2, -titleLabel->size().y*2, 0);
        
        float m_step_x = m_width / 4;
        float m_step_y = m_height / 5;
        
        for(int i = 0; i < 4; i++) // For every row (i.e. a given output)
        {
            for(int j = 0; j < 4; j++) // For every column (i.e. a given input)
            {
                AGSlider *slider = new AGSlider(sliderPos + GLvertex3f(m_step_x*j, -m_step_y*i, 0));
                
                slider->init();
                slider->setSize(GLvertex2f(sliderWidth, sliderHeight));
                slider->setType(AGSlider::CONTINUOUS);
                slider->setScale(AGSlider::EXPONENTIAL);
                slider->setAlignment(AGSlider::ALIGN_LEFT);
                
                int port = (i * 4) + j;
                AGParamValue val = 0;
                m_node->getEditPortValue(port, val);
                slider->setValue(val);
                
                slider->onUpdate([this, port] (float value) {
                    m_node->setEditPortValue(port, value);
                });
                slider->setValidator([this, port] (float _old, float _new) -> float {
                    return m_node->validateEditPortValue(port, _new);
                });
                addChild(slider);
            }
        }
        
        float pinButtonWidth = 20;
        float pinButtonHeight = 20;
        float pinButtonX = m_width/2-hmargin-pinButtonWidth/2;
        float pinButtonY = m_height/2-hmargin-pinButtonHeight/2;
        AGRenderInfoV pinInfo;
        float pinRadius = (pinButtonWidth*0.9)/2;
        m_pinInfoGeo = std::vector<GLvertex3f>({{ pinRadius, pinRadius, 0 }, { -pinRadius, -pinRadius, 0 }});
        pinInfo.geo = m_pinInfoGeo.data();
        pinInfo.numVertex = 2;
        pinInfo.geoType = GL_LINES;
        pinInfo.color = AGStyle::foregroundColor();
        m_pinButton = new AGUIIconButton(GLvertex3f(pinButtonX, pinButtonY, 0),
                                         GLvertex2f(pinButtonWidth, pinButtonHeight),
                                         pinInfo);
        m_pinButton->init();
        m_pinButton->setInteractionType(AGUIButton::INTERACTION_LATCH);
        m_pinButton->setIconMode(AGUIIconButton::ICONMODE_SQUARE);
        m_pinButton->setAction(^{
            pin(m_pinButton->isPressed());
        });
        addChild(m_pinButton);
    }
    
    virtual void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        
        m_renderState.modelview = GLKMatrix4Translate(m_renderState.modelview,
                                                      position().x, position().y, 0);
        
        m_squeeze.update(t, dt);
        m_renderState.modelview = m_squeeze.apply(m_renderState.modelview);
        
        updateChildren(t, dt);
    }
    
    virtual void render() override
    {
        GLvertex3f box[4];
        GeoGen::makeRect(box, m_width, m_height);
        
        // fill frame
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &AGStyle::frameBackgroundColor());
        drawTriangleFan(box, 4);
        
        // stroke frame
        glLineWidth(2.0f);
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &GLcolor4f::white);
        drawLineLoop(box, 4);

        AGRenderObject::render();
        renderChildren();
    }
    
    void renderOut() override
    {
        m_squeeze.close();
        
        AGInteractiveObject::renderOut();
    }
    
    bool finishedRenderingOut() override
    {
        return m_squeeze.finishedClosing();
    }
    
    virtual bool doneEditing() override { return m_doneEditing; }
    
    virtual GLvertex3f position() override { return m_node->position(); }
    virtual GLvertex2f size() override { return GLvertex2f(m_width, m_height); }
};

void AGAudioMatrixMixerNode::renderAudio(sampletime t, float *input, float *output, int nFrames, int chanNum, int nChans)
{
    if(t <= m_lastTime) { renderLast(output, nFrames, chanNum); return; }
    m_lastTime = t;
    pullInputPorts(t, nFrames);
    
    float gains[4][4]; // [outputChannel][inputChannel]
    
    for(int i = 0; i < 4; i++) // For every row (i.e. output channel)
    {
        for(int j = 0; j < 4; j++) // For every column (i.e. input channel)
        {
            gains[i][j] = param(m_manifest->editPortInfo()[(i*4)+j].portId);
        }
    }
    
    for(int i = 0; i < 4; i++) // For every output channel
    {
        for(int k = 0; k < nFrames; k++) // Zero out buffer
        {
            m_outputBuffer[i][k] = 0;
        }
        
        for(int j = 0; j < 4; j++) // For every input
        {
            for(int k = 0; k < nFrames; k++) // For every frame
            {
                m_outputBuffer[i][k] += m_inputPortBuffer[j][k] * gains[i][j];
            }
        }
    }
        
    for(int i = 0; i < nFrames; i++) // Accumulate to our output buffer
    {
        output[i] += m_outputBuffer[chanNum][i];
    }
}

AGUINodeEditor *AGAudioMatrixMixerNode::createCustomEditor()
{
    AGUINodeEditor *editor = new AGMatrixMixerEditor(this);
    editor->init();
    return editor;
}
