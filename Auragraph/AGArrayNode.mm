//
//  AGArrayNode.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGArrayNode.h"
#include "AGUserInterface.h"
#include "AGStyle.h"
#include "AGHandwritingRecognizer.h"

#include "GeoGenerator.h"

#include <sstream>

//------------------------------------------------------------------------------
// ### AGUIArrayEditor ###
//------------------------------------------------------------------------------
#pragma mark - AGUIArrayEditor

//------------------------------------------------------------------------------
// ### AGUIArrayEditor ###
//------------------------------------------------------------------------------
#pragma mark - AGUIArrayEditor

class AGUIArrayEditor : public AGUINodeEditor
{
public:
    
    class Element : public AGInteractiveObject
    {
    public:
        Element(AGUIArrayEditor * arrayEditor, const GLvertex3f &pos, const GLvertex2f &size) :
        m_arrayEditor(arrayEditor), m_pos(pos), m_size(size), m_hasValue(false),
        m_lastTraceWasRecognized(false), m_decimal(false), m_decimalFactor(1)
        {
            float inset = 0.8;
            float yHeight = 0.2;
            m_geo[0] = GLvertex3f(-size.x/2.0f*inset, -size.y/2.0f*inset*(1-yHeight), 0);
            m_geo[1] = GLvertex3f(-size.x/2.0f*inset, -size.y/2.0f*inset, 0);
            m_geo[2] = GLvertex3f( size.x/2.0f*inset, -size.y/2.0f*inset, 0);
            m_geo[3] = GLvertex3f( size.x/2.0f*inset, -size.y/2.0f*inset*(1-yHeight), 0);
            
            m_renderInfo.geo = m_geo;
            m_renderInfo.geoType = GL_LINE_STRIP;
            m_renderInfo.numVertex = 4;
            m_renderInfo.color = lerp(0.5, GLcolor4f(0, 0, 0, 1), AGStyle::lightColor());
            m_renderList.push_back(&m_renderInfo);
        }
        
        virtual void update(float t, float dt)
        {
            AGInteractiveObject::update(t, dt);
            
            m_renderState.projection = projectionMatrix();
            m_renderState.modelview = GLKMatrix4Translate(parent()->m_renderState.modelview, m_pos.x, m_pos.y, m_pos.z);
            m_renderState.normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_renderState.modelview), NULL);
            
            if(m_hasValue)
                m_renderInfo.color = AGStyle::lightColor();
            else
                m_renderInfo.color = lerp(0.5, GLcolor4f(0, 0, 0, 1), AGStyle::lightColor());
        }
        
        virtual void render()
        {
            AGInteractiveObject::render();
            
            if(m_hasValue)
            {
                TexFont *text = AGStyle::standardFont64();
                
                stringstream ss;
                ss << m_currentValue;
                if(m_decimal && floorf(m_currentValue) == m_currentValue) ss << "."; // show decimal point if user has drawn it
                
                GLKMatrix4 valueMV = GLKMatrix4Translate(m_renderState.modelview, -text->width(ss.str())/2.0f, -m_size.y/4.0f, 0);

                text->render(ss.str(), AGStyle::lightColor(), valueMV, m_renderState.projection);
            }
            
            if(m_drawline.size())
            {
                AGGenericShader::instance().useProgram();
                AGGenericShader::instance().setNormalMatrix(m_renderState.normal);
                AGGenericShader::instance().setModelViewMatrix(AGNode::globalModelViewMatrix());
                AGGenericShader::instance().setProjectionMatrix(AGNode::projectionMatrix());
                
                // draw traces
                list<std::vector<GLvertex3f> >::iterator last = m_drawline.size() ? --m_drawline.end() : m_drawline.begin();
                for(list<std::vector<GLvertex3f> >::iterator i = m_drawline.begin(); i != m_drawline.end(); i++)
                {
                    vector<GLvertex3f> geo = *i;
                    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), geo.data());
                    glEnableVertexAttribArray(GLKVertexAttribPosition);
                    if(i == last && !m_lastTraceWasRecognized)
                        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &AGStyle::errorColor());
                    else
                        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &AGStyle::lightColor());
                    glDisableVertexAttribArray(GLKVertexAttribColor);
                    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
                    glDisableVertexAttribArray(GLKVertexAttribNormal);
                    
                    glDrawArrays(GL_LINE_STRIP, 0, geo.size());
                }
            }
        }
        
        virtual void touchDown(const AGTouchInfo &t)
        {
            if(!m_lastTraceWasRecognized && m_drawline.size())
                m_drawline.remove(m_drawline.back());
            m_lastTraceWasRecognized = true;
            
            m_drawline.push_back(std::vector<GLvertex3f>());
            m_currentTrace = LTKTrace();
            
            m_drawline.back().push_back(t.position);
            
            floatVector point;
            point.push_back(t.screenPosition.x);
            point.push_back(t.screenPosition.y);
            m_currentTrace.addPoint(point);
        }
        
        virtual void touchMove(const AGTouchInfo &t)
        {
            m_drawline.back().push_back(t.position);
            
            floatVector point;
            point.push_back(t.screenPosition.x);
            point.push_back(t.screenPosition.y);
            m_currentTrace.addPoint(point);
        }
        
        virtual void touchUp(const AGTouchInfo &t)
        {
            if(m_currentTrace.getNumberOfPoints() > 0)
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
                        if(m_decimal)
                        {
                            m_currentValue = m_currentValue + (figure-'0')*m_decimalFactor;
                            m_decimalFactor *= 0.1;
                        }
                        else
                            m_currentValue = m_currentValue*10 + (figure-'0');
                        m_lastTraceWasRecognized = true;
                        break;
                        
                    case AG_FIGURE_PERIOD:
                        if(m_decimal)
                            m_lastTraceWasRecognized = false;
                        else
                        {
                            m_decimalFactor = 0.1;
                            m_lastTraceWasRecognized = true;
                            m_decimal = true;
                        }
                        break;
                        
                    default:
                        m_lastTraceWasRecognized = false;
                }
            }
            
            m_hasValue = m_lastTraceWasRecognized;
        }
        
    protected:
        GLvertex3f m_geo[4];
        AGRenderInfoV m_renderInfo;
        
        GLvertex2f m_size;
        GLvertex3f m_pos;
        
        AGUIArrayEditor * const m_arrayEditor;
        
        virtual GLvrectf effectiveBounds()
        {
            return GLvrectf(m_arrayEditor->position()+m_pos-m_size, m_arrayEditor->position()+m_pos+m_size);
        }
        
        bool m_hasValue;
        
        std::list< std::vector<GLvertex3f> > m_drawline;
        LTKTrace m_currentTrace;
        
        float m_currentValue;
        bool m_lastTraceWasRecognized;
        bool m_decimal;
        float m_decimalFactor;
    };
    
    static void initializeNodeEditor();
    
    AGUIArrayEditor(AGControlArrayNode *node) :
    m_node(node),
    m_doneEditing(false)
    {
        m_width = 0.08f;
        m_height = 0.02f;
        
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
        
        m_xScale = lincurvef(AGStyle::open_animTimeX, AGStyle::open_squeezeHeight, 1);
        m_yScale = lincurvef(AGStyle::open_animTimeY, AGStyle::open_squeezeHeight, 1);
        
        Element *e = new Element(this, GLvertex3f(-m_width/3.0f, 0.0f, 0.0f), GLvertex2f(m_width/3.0f, m_height));
        addChild(e);
    }
    
    virtual void update(float t, float dt)
    {
//        AGInteractiveObject::update(t, dt);
        
        m_modelView = AGNode::globalModelViewMatrix();
        m_renderState.projection = AGNode::projectionMatrix();
        
        m_modelView = GLKMatrix4Translate(m_modelView, m_node->position().x, m_node->position().y, m_node->position().z);
        
        if(m_yScale <= AGStyle::open_squeezeHeight) m_xScale.update(dt);
        if(m_xScale >= 0.99f) m_yScale.update(dt);
        
        m_modelView = GLKMatrix4Scale(m_modelView,
                                      m_yScale <= AGStyle::open_squeezeHeight ? (float)m_xScale : 1.0f,
                                      m_xScale >= 0.99f ? (float)m_yScale : AGStyle::open_squeezeHeight,
                                      1);
        
        m_renderState.modelview = m_modelView;
        m_renderState.normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_modelView), NULL);
        
        updateChildren(t, dt);
    }
    
    virtual void render()
    {
        renderPrimitive(&m_boxInnerInfo);
        renderChildren();
        renderPrimitive(&m_boxOuterInfo);
    }
    
//    virtual AGInteractiveObject *hitTest(const GLvertex3f &t)
//    {
//        AGInteractiveObject *hit = AGInteractiveObject::hitTest(t);
////        if(hit != this || (hit && hit->parent() != this))
////            m_doneEditing = true;
//        return this;
//    }
    
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
    
    GLvertex3f position()
    {
        return m_node->position();
    }
    
    void renderOut()
    {
        m_xScale = lincurvef(AGStyle::open_animTimeX/2, 1, AGStyle::open_squeezeHeight);
        m_yScale = lincurvef(AGStyle::open_animTimeY/2, 1, AGStyle::open_squeezeHeight);
    }
    
    bool finishedRenderingOut()
    {
        return m_xScale <= AGStyle::open_squeezeHeight;
    }
    
    virtual bool doneEditing() { return m_doneEditing; }
    
protected:
    virtual GLvrectf effectiveBounds()
    {
        return GLvrectf(m_node->position()-GLvertex3f(m_width/2, m_height/2, 0), m_node->position()+GLvertex3f(m_width/2, m_height/2, 0));
    }
    
private:
    
    AGControlArrayNode * const m_node;
    
    string m_title;
    
    float m_width, m_height;
    AGRenderInfoV m_boxOuterInfo, m_boxInnerInfo;
    GLvertex3f m_boxGeo[4];
    
    GLKMatrix4 m_modelView;
    lincurvef m_xScale;
    lincurvef m_yScale;

    bool m_doneEditing;
    
//    int hitTest(const GLvertex3f &t, bool *inBbox);
};


//------------------------------------------------------------------------------
// ### AGControlArrayNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlArrayNode

AGNodeInfo *AGControlArrayNode::s_nodeInfo = NULL;

void AGControlArrayNode::initialize()
{
    s_nodeInfo = new AGNodeInfo;
    
    float radius = 0.0057;
    int numBoxes = 5;
    float boxWidth = radius*2.0f/((float)numBoxes);
    float boxHeight = radius/2.5f;
    s_nodeInfo->iconGeoSize = (numBoxes*3+1)*2;
    s_nodeInfo->iconGeoType = GL_LINES;
    s_nodeInfo->iconGeo = new GLvertex3f[s_nodeInfo->iconGeoSize];
    
    for(int i = 0; i < numBoxes; i++)
    {
        s_nodeInfo->iconGeo[i*6+0] = GLvertex3f(-radius+i*boxWidth,  boxHeight, 0);
        s_nodeInfo->iconGeo[i*6+1] = GLvertex3f(-radius+i*boxWidth, -boxHeight, 0);
        s_nodeInfo->iconGeo[i*6+2] = GLvertex3f(-radius+i*boxWidth,  boxHeight, 0);
        s_nodeInfo->iconGeo[i*6+3] = GLvertex3f(-radius+i*boxWidth+boxWidth,  boxHeight, 0);
        s_nodeInfo->iconGeo[i*6+4] = GLvertex3f(-radius+i*boxWidth, -boxHeight, 0);
        s_nodeInfo->iconGeo[i*6+5] = GLvertex3f(-radius+i*boxWidth+boxWidth, -boxHeight, 0);
    }
    
    s_nodeInfo->iconGeo[numBoxes*6+0] = GLvertex3f(-radius+numBoxes*boxWidth, -boxHeight, 0);
    s_nodeInfo->iconGeo[numBoxes*6+1] = GLvertex3f(-radius+numBoxes*boxWidth,  boxHeight, 0);
    
    s_nodeInfo->inputPortInfo.push_back({ "iterate", true, true });
}

AGControlArrayNode::AGControlArrayNode(const GLvertex3f &pos) :
AGControlNode(pos)
{
    m_nodeInfo = s_nodeInfo;
    m_lastTime = 0;
}

void AGControlArrayNode::setEditPortValue(int port, float value)
{
    switch(port)
    {
    }
}

void AGControlArrayNode::getEditPortValue(int port, float &value) const
{
    switch(port)
    {
    }
}

AGUINodeEditor *AGControlArrayNode::createCustomEditor()
{
    return new AGUIArrayEditor(this);
}

AGControl *AGControlArrayNode::renderControl(sampletime t)
{
    if(t > m_lastTime)
    {
        m_control = 0;
    }
    
    return &m_control;
}

void AGControlArrayNode::renderIcon()
{
    // render icon
    glBindVertexArrayOES(0);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_nodeInfo->iconGeo);
    
    glLineWidth(2.0);
    glDrawArrays(s_nodeInfo->iconGeoType, 0, s_nodeInfo->iconGeoSize);
}

AGControlNode *AGControlArrayNode::create(const GLvertex3f &pos)
{
    return new AGControlArrayNode(pos);
}

