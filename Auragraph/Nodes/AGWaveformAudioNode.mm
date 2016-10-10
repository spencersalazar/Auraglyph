//
//  AGWaveformAudioNode.mm
//  Auragraph
//
//  Created by Spencer Salazar on 9/28/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGWaveformAudioNode.h"
#include "AGUINodeEditor.h"
#include "AGGenericShader.h"
#include "AGSlider.h"

#include "GeoGenerator.h"
#include "spdsp.h"

class AGWaveformEditor : public AGUINodeEditor
{
private:
    AGAudioWaveformNode * const m_node;
    float m_width, m_height;
    
    AGSqueezeAnimation m_squeeze;
    bool m_doneEditing;
    
    GLvertex2f m_waveformPos;
    GLvertex2f m_waveformSize;
    
    int m_lastModifiedPos;
    
public:
    AGWaveformEditor(AGAudioWaveformNode *node) :
    m_node(node), m_doneEditing(false)
    {
        m_squeeze.open();
        m_width = 425;
        m_height = m_width*0.5f;
        
        m_waveformPos = GLvertex2f( 0, -m_height*0.1f );
        m_waveformSize = GLvertex2f( m_width*0.9f, m_height*0.7f );
        
        AGUILabel *titleLabel = new AGUILabel(GLvertex3f(0, 0, 0), "WAVEFORM");
        titleLabel->init();
        titleLabel->setSize(titleLabel->naturalSize());
        titleLabel->setPosition(GLvertex2f(-m_width/2, m_height/2)+titleLabel->size()/2);
        addChild(titleLabel);
        
        float hmargin = 10;
        float labelWidth = 40;
        float sliderWidth = 80;
        float sliderHeight = 32;
        float pos = -m_width/2;
        
        // freq label
        pos += hmargin + labelWidth/2;
        
        AGUILabel *freqLabel = new AGUILabel(GLvertex3f(pos, m_height/2-sliderHeight/2, 0), "freq");
        freqLabel->init();
        freqLabel->setSize(GLvertex2f(labelWidth, sliderHeight));
        addChild(freqLabel);
        
        // freq slider
        pos += hmargin + labelWidth/2 + sliderWidth/2;
        
        AGSlider *freqSlider = new AGSlider(GLvertex3f(pos, m_height/2-sliderHeight/2, 0));
        freqSlider->init();
        
        freqSlider->setSize(GLvertex2f(sliderWidth, sliderHeight));
        freqSlider->setType(AGSlider::CONTINUOUS);
        freqSlider->setScale(AGSlider::EXPONENTIAL);
        freqSlider->setAlignment(AGSlider::ALIGN_LEFT);
        freqSlider->setValue(m_node->param(AGAudioWaveformNode::PARAM_FREQ));
        freqSlider->onUpdate([this] (float value) {
            m_node->setParam(AGAudioWaveformNode::PARAM_FREQ, value);
        });
        freqSlider->setValidator([this] (float _old, float _new) -> float {
            return m_node->validateParam(AGAudioWaveformNode::PARAM_FREQ, _new);
        });
        addChild(freqSlider);
        
        // dur label
        pos += sliderWidth/2 + hmargin*2 + labelWidth/2;
        
        AGUILabel *durLabel = new AGUILabel(GLvertex3f(pos, m_height/2-sliderHeight/2, 0), "dur");
        durLabel->init();
        durLabel->setSize(GLvertex2f(labelWidth, sliderHeight));
        addChild(durLabel);
        
        pos += labelWidth/2 + hmargin + sliderWidth/2;
        
        // dur slider
        AGSlider *durSlider = new AGSlider(GLvertex3f(pos, m_height/2-sliderHeight/2, 0));
        durSlider->init();
        
        durSlider->setSize(GLvertex2f(sliderWidth, sliderHeight));
        durSlider->setType(AGSlider::CONTINUOUS);
        durSlider->setScale(AGSlider::EXPONENTIAL);
        durSlider->setAlignment(AGSlider::ALIGN_LEFT);
        durSlider->setValue(m_node->param(AGAudioWaveformNode::PARAM_DURATION));
        durSlider->onUpdate([this] (float value) {
            m_node->setParam(AGAudioWaveformNode::PARAM_DURATION, value);
        });
        durSlider->setValidator([this] (float _old, float _new) -> float {
            return m_node->validateParam(AGAudioWaveformNode::PARAM_DURATION, _new);
        });
        addChild(durSlider);
        
        // gain label
        pos += sliderWidth/2 + hmargin*2 + labelWidth/2;
        
        AGUILabel *gainLabel = new AGUILabel(GLvertex3f(pos, m_height/2-sliderHeight/2, 0), "gain");
        gainLabel->init();
        gainLabel->setSize(GLvertex2f(labelWidth, sliderHeight));
        addChild(gainLabel);
        
        pos += labelWidth/2 + hmargin + sliderWidth/2;
        
        // gain slider
        AGSlider *gainSlider = new AGSlider(GLvertex3f(pos, m_height/2-sliderHeight/2, 0));
        gainSlider->init();
        
        gainSlider->setSize(GLvertex2f(sliderWidth, sliderHeight));
        gainSlider->setType(AGSlider::CONTINUOUS);
        gainSlider->setScale(AGSlider::EXPONENTIAL);
        gainSlider->setAlignment(AGSlider::ALIGN_LEFT);
        gainSlider->setValue(m_node->param(AGAudioWaveformNode::AUDIO_PARAM_GAIN));
        gainSlider->onUpdate([this] (float value) {
            m_node->setParam(AGAudioWaveformNode::AUDIO_PARAM_GAIN, value);
        });
        gainSlider->setValidator([this] (float _old, float _new) -> float {
            return m_node->validateParam(AGAudioWaveformNode::AUDIO_PARAM_GAIN, _new);
        });
        addChild(gainSlider);
    }
    
    virtual void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        
        m_renderState.modelview = GLKMatrix4Translate(m_renderState.modelview,
                                                      position().x, position().y, 0);
        
        m_squeeze.update(t, dt);
        m_renderState.modelview = m_squeeze.apply(m_renderState.modelview);
    }
    
    virtual void render() override
    {
        GLvertex3f box[4];
        GeoGen::makeRect(box, m_width, m_height);
        
        // fill frame
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::black);
        drawTriangleFan(box, 4);
        
        // stroke frame
        glLineWidth(2.0f);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        drawLineLoop(box, 4);
        
        // draw y-axis
        glLineWidth(1.0f);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        drawLineStrip((GLvertex2f[]) {
            m_waveformPos + GLvertex2f{ -m_waveformSize.x*0.5f,  m_waveformSize.y*0.5f },
            m_waveformPos + GLvertex2f{ -m_waveformSize.x*0.5f, -m_waveformSize.y*0.5f },
        }, 2);
        
        // draw x-axis
        glLineWidth(1.0f);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        drawLineStrip((GLvertex2f[]) {
            m_waveformPos + GLvertex2f{ -m_waveformSize.x*0.5f, 0 },
            m_waveformPos + GLvertex2f{  m_waveformSize.x*0.5f, 0 },
        }, 2);
        
        // draw waveform
        glLineWidth(3.0f);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        drawWaveform(m_node->m_waveform.data(), m_node->m_waveform.size(),
                     m_waveformPos+GLvertex2f(-m_waveformSize.x*0.5f, 0),
                     m_waveformPos+GLvertex2f( m_waveformSize.x*0.5f, 0),
                     1.0f, m_waveformSize.y*0.5f);
        
        // draw phase
//        glLineWidth(1.0f);
//        float phaseOffset = (m_node->m_phase-0.5f);
//        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
//        drawLineStrip((GLvertex2f[]) {
//            m_waveformPos + GLvertex2f{ phaseOffset*m_waveformSize.x,  m_waveformSize.y*0.5f },
//            m_waveformPos + GLvertex2f{ phaseOffset*m_waveformSize.x, -m_waveformSize.y*0.5f },
//        }, 2);
        
        AGRenderObject::render();
    }
    
    virtual void touchDown(const AGTouchInfo &t) override
    {
        if(pointInRectangle(t.position.xy(), position().xy()+m_waveformPos-m_waveformSize*0.5f, position().xy()+m_waveformPos+m_waveformSize*0.5f))
        {
            GLvertex2f posInWaveform = t.position.xy()-position().xy()-m_waveformPos;
            // normalize x to [0,1]
            float normX = (posInWaveform.x+(m_waveformSize.x*0.5f))/m_waveformSize.x;
            // normalize y to [-1,1]
            float normY = posInWaveform.y/m_waveformSize.y*2;
            
            dbgprint("posInWaveform %f %f\n", posInWaveform.x, posInWaveform.y);
            dbgprint("norm %f %f\n", normX, normY);
            
            int pos = (int) roundf(normX*m_node->m_waveform.size());
            m_node->m_waveform[pos] = normY;
            
            m_lastModifiedPos = pos;
        }
    }
    
    virtual void touchMove(const AGTouchInfo &t) override
    {
        if(pointInRectangle(t.position.xy(), position().xy()+m_waveformPos-m_waveformSize*0.5f, position().xy()+m_waveformPos+m_waveformSize*0.5f))
        {
            GLvertex2f posInWaveform = t.position.xy()-position().xy()-m_waveformPos;
            // normalize x to [0,1]
            float normX = (posInWaveform.x+(m_waveformSize.x*0.5f))/m_waveformSize.x;
            // normalize y to [-1,1]
            float normY = posInWaveform.y/m_waveformSize.y*2;
            
            dbgprint_off("posInWaveform %f %f\n", posInWaveform.x, posInWaveform.y);
            dbgprint_off("norm %f %f\n", normX, normY);

            int pos = (int) roundf(normX*m_node->m_waveform.size());
            m_node->m_waveform[pos] = normY;
            
            // interpolate from last point
            if(pos != m_lastModifiedPos)
            {
                int from, to;
                if(pos > m_lastModifiedPos)
                {
                    from = m_lastModifiedPos;
                    to = pos;
                }
                else
                {
                    from = pos;
                    to = m_lastModifiedPos;
                }
                
                // interpolate
                float fromVal = m_node->m_waveform[from];
                float toVal = m_node->m_waveform[to];
                float size = to-from;
                dbgprint("from/to %i %i\n", from, to);
                for(int i = 1; i < size; i++)
                {
                    dbgprint("from/to scale %f %f\n", (1.0f-i/size), (i/size));
                    m_node->m_waveform[from+i] = fromVal*(1.0f-i/size) + toVal*(i/size);
                }
                
                m_lastModifiedPos = pos;
            }
        }
    }
    
    virtual void touchUp(const AGTouchInfo &t) override
    {
        
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

void AGAudioWaveformNode::deserializeFinal(const AGDocument::Node &docNode)
{
    m_waveform.resize(1024, 0);
    for(int i = 0; i < m_waveform.size(); i++)
        m_waveform[i] = sinf(2*M_PI*((float)i)/m_waveform.size());
    
    docNode.loadParam("waveform", m_waveform);
}

void AGAudioWaveformNode::initFinal()
{
    m_phase = 0;
}

float AGAudioWaveformNode::get(float phase)
{
    double pos = ((double)phase)*m_waveform.size();
    int whole = (int)floor(pos);
    double fract = fmod(pos, 1.0f);
    
    // linear interpolation
    return m_waveform[whole]*(1-fract) + m_waveform[(whole+1)%m_waveform.size()]*(fract);
}

void AGAudioWaveformNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    if(t <= m_lastTime) { renderLast(output, nFrames); return; }
    pullInputPorts(t, nFrames);
    
    float *gainv = inputPortVector(AUDIO_PARAM_GAIN);
    float *freqv = inputPortVector(PARAM_FREQ);
    
    for(int i = 0; i < nFrames; i++)
    {
        m_outputBuffer[i] = get(m_phase) * gainv[i];
        output[i] += m_outputBuffer[i];
        
        m_phase = clipunit(m_phase + freqv[i]/sampleRate());
    }
    
    m_lastTime = t;
}

void AGAudioWaveformNode::_renderIcon()
{
    float insetScale = G_RATIO-1;
    float xInset = 0.01*AGStyle::oldGlobalScale*insetScale;
    float yScale = 0.01*AGStyle::oldGlobalScale*insetScale/G_RATIO;
    drawWaveform(m_waveform.data(), m_waveform.size(), GLvertex2f(-xInset, 0), GLvertex2f(xInset, 0), 1, yScale);
    
    float radius = 25;
    float w = radius*1.3, h = w*0.3, t = h*0.75, rot = -M_PI*0.8f;
    GLvertex2f offset(-w/2,0);
    
    drawLineStrip((GLvertex2f[]) {
        rotateZ(offset+GLvertex2f( w/2,      0), rot),
        rotateZ(offset+GLvertex2f( w/2-t,  h/2), rot),
        rotateZ(offset+GLvertex2f(-w/2,    h/2), rot),
        rotateZ(offset+GLvertex2f(-w/2,   -h/2), rot),
        rotateZ(offset+GLvertex2f( w/2-t, -h/2), rot),
        rotateZ(offset+GLvertex2f( w/2,      0), rot),
    }, 6);
}

AGUINodeEditor *AGAudioWaveformNode::createCustomEditor()
{
    AGUINodeEditor *editor = new AGWaveformEditor(this);
    editor->init();
    return editor;
}

AGDocument::Node AGAudioWaveformNode::serialize()
{
    AGDocument::Node docNode = AGNode::serialize();
    
    docNode.saveParam("waveform", m_waveform);
    
    return std::move(docNode);
}
