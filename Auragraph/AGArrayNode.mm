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
#include "AGGenericShader.h"
#include "AGUINodeEditor.h"

#include "GeoGenerator.h"

#include <sstream>


//------------------------------------------------------------------------------
// ### AGUINumberInput ###
//------------------------------------------------------------------------------
#pragma mark - AGUINumberInput

class AGUINumberInput : public AGInteractiveObject
{
public:
    AGUINumberInput(const GLvertex3f &pos, const GLvertex2f &size) :
    m_pos(pos), m_size(size), m_action(NULL), m_decimal(false),
    m_lastTraceWasRecognized(false)
    {
        GeoGen::makeRect(m_geo, size.x, size.y);
        
        // inner background box
        m_boxInnerInfo.geo = m_geo;
        m_boxInnerInfo.geoType = GL_TRIANGLE_FAN;
        m_boxInnerInfo.numVertex = 4;
        m_boxInnerInfo.color = AGStyle::frameBackgroundColor();
        m_renderList.push_back(&m_boxInnerInfo);
        
        // outer outline box
        m_boxOuterInfo.geo = m_geo;
        m_boxOuterInfo.geoType = GL_LINE_LOOP;
        m_boxOuterInfo.numVertex = 4;
        m_boxOuterInfo.color = AGStyle::lightColor();
        m_renderList.push_back(&m_boxOuterInfo);
        
        // undo button
        float buttonSize = 0.0062f*AGStyle::globalScale;
        AGRenderInfoV m_undoInfo;
        m_undoInfo.geoType = GL_LINES;
        m_undoInfo.numVertex = 6;
        m_undoGeo[0] = GLvertex3f(-buttonSize*0.1, buttonSize*0.3, 0);
        m_undoGeo[1] = GLvertex3f(-buttonSize*0.3, 0, 0);
        m_undoGeo[2] = GLvertex3f(-buttonSize*0.3, 0, 0);
        m_undoGeo[3] = GLvertex3f(-buttonSize*0.1, -buttonSize*0.3, 0);
        m_undoGeo[4] = GLvertex3f(-buttonSize*0.3, 0, 0);
        m_undoGeo[5] = GLvertex3f( buttonSize*0.3, 0, 0);
        m_undoInfo.geo = m_undoGeo;
        AGUIButton *undoButton = new AGUIIconButton(GLvertex3f(-size.x, size.y, 0)*0.5f+GLvertex3f(buttonSize/2, -buttonSize/2, 0),
                                                    GLvertex2f(buttonSize, buttonSize),
                                                    m_undoInfo);
        undoButton->setAction(^{ undo(); });
        addChild(undoButton);
        
        // cancel button
        AGRenderInfoV m_cancelInfo;
        m_cancelInfo.geoType = GL_LINES;
        m_cancelInfo.numVertex = 4;
        m_cancelGeo[0] = GLvertex3f(-buttonSize*0.3,  buttonSize*0.3, 0);
        m_cancelGeo[1] = GLvertex3f( buttonSize*0.3, -buttonSize*0.3, 0);
        m_cancelGeo[2] = GLvertex3f(-buttonSize*0.3, -buttonSize*0.3, 0);
        m_cancelGeo[3] = GLvertex3f( buttonSize*0.3,  buttonSize*0.3, 0);
        m_cancelInfo.geo = m_cancelGeo;
        AGUIButton *cancelButton = new AGUIIconButton(size*0.5f+GLvertex3f(-buttonSize/2 -buttonSize*1.25, -buttonSize/2, 0),
                                                      GLvertex2f(buttonSize, buttonSize),
                                                      m_cancelInfo);
        cancelButton->setAction(^{ cancel(); });
        addChild(cancelButton);
        
        // ok button
        AGRenderInfoV m_okInfo;
        m_okInfo.geoType = GL_LINE_STRIP;
        m_okInfo.numVertex = 3;
        m_okGeo[0] = GLvertex3f(-buttonSize*0.3, 0, 0);
        m_okGeo[1] = GLvertex3f( 0, -buttonSize*0.3, 0);
        m_okGeo[2] = GLvertex3f( buttonSize*0.3, buttonSize*0.3, 0);
        m_okInfo.geo = m_okGeo;
        AGUIButton *okButton = new AGUIIconButton(size*0.5f+GLvertex3f(-buttonSize/2, -buttonSize/2, 0),
                                                  GLvertex2f(buttonSize, buttonSize),
                                                  m_okInfo);
        okButton->setAction(^{ accept(); });
        addChild(okButton);
        
        m_squeeze.open();
    }
    
    ~AGUINumberInput()
    {
        AGBlock_release(m_action);
        m_action = NULL;
    }
    
    virtual void update(float t, float dt)
    {
        m_squeeze.update(t, dt);
        
        m_renderState.projection = projectionMatrix();
        m_renderState.modelview = GLKMatrix4Translate(parent()->m_renderState.modelview, m_pos.x, m_pos.y, m_pos.z);
        m_renderState.modelview = GLKMatrix4Multiply(m_renderState.modelview, m_squeeze.matrix());
        m_renderState.normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_renderState.modelview), NULL);
        
        updateChildren(t, dt);
    }
    
    virtual void render()
    {
        renderPrimitives();
        
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
        
        if(m_drawline.size() > 0)
        {
            TexFont *text = AGStyle::standardFont64();
            
            GLKMatrix4 valueMV = GLKMatrix4Translate(m_renderState.modelview, -text->width(m_currentValue)/2.0f, -m_size.y/4.0f, 0);
            
            text->render(m_currentValue, AGStyle::lightColor(), valueMV, m_renderState.projection);
        }
        
        renderChildren();
        
        debug_renderBounds();
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
                case AG_FIGURE_PERIOD:
                    if(!m_decimal)
                        m_currentValue += figure;
                    m_decimal = true;
                    break;
                    
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
                    // append to string
                    m_currentValue += figure;
                    break;
                    
                default:
                    m_lastTraceWasRecognized = false;
            }
        }
    }
    
    virtual GLvertex3f position() { return m_pos; }
    virtual GLvertex2f size() { return m_size; }
    
    void undo()
    {
        m_currentValue.erase(--m_currentValue.end());
    }
    
    void cancel()
    {
        if(m_action) m_action(false, 0);
    }
    
    void accept()
    {
        if(m_action) m_action(true, ::atof(m_currentValue.c_str()));
    }
    
    void setAction(void (^action)(bool accepted, float value))
    {
        m_action = AGBlock_copy(action);
    }

protected:
    GLvertex3f m_geo[4];
    AGRenderInfoV m_boxOuterInfo;
    AGRenderInfoV m_boxInnerInfo;
    
    GLvertex2f m_size;
    GLvertex3f m_pos;
    AGSqueezeAnimation m_squeeze;
    
    std::list< std::vector<GLvertex3f> > m_drawline;
    LTKTrace m_currentTrace;
    
    string m_currentValue;
    bool m_lastTraceWasRecognized;
    bool m_decimal;
    
    GLvertex3f m_undoGeo[6];
    GLvertex3f m_cancelGeo[4];
    GLvertex3f m_okGeo[3];
    
    void (^m_action)(bool accepted, float value);
};


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
        m_pressed(false), m_numInput(NULL), m_editAction(NULL), m_valueRef(NULL)
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
        
        ~Element()
        {
            AGBlock_release(m_action);
            m_editAction = NULL;
        }
        
        virtual void update(float t, float dt)
        {
            AGInteractiveObject::update(t, dt);
            
            m_renderState.projection = projectionMatrix();
            m_renderState.modelview = GLKMatrix4Translate(parent()->m_renderState.modelview, m_pos.x, m_pos.y, m_pos.z);
            m_renderState.normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_renderState.modelview), NULL);
            
            if(m_pressed)
                m_renderInfo.color = lerp(0.5, GLcolor4f(1, 1, 1, 1), AGStyle::lightColor());
            else if(m_hasValue)
                m_renderInfo.color = AGStyle::lightColor();
            else
                m_renderInfo.color = lerp(0.5, GLcolor4f(0, 0, 0, 1), AGStyle::lightColor());
        }
        
        virtual void render()
        {
            float width;
            if(m_pressed)
            {
                glGetFloatv(GL_LINE_WIDTH, &width);
                glLineWidth(8.0);
            }
            
            if(m_pressed)
                glLineWidth(width);

            if(m_hasValue)
            {
                TexFont *text = AGStyle::standardFont64();
                
                stringstream ss;
                ss << m_value;
                
                GLKMatrix4 valueMV = GLKMatrix4Translate(m_renderState.modelview, -text->width(ss.str())/2.0f, -m_size.y/4.0f, 0);

                text->render(ss.str(), AGStyle::lightColor(), valueMV, m_renderState.projection);
            }
            
            AGInteractiveObject::render();
            
            debug_renderBounds();
        }
        
        virtual void touchDown(const AGTouchInfo &t)
        {
            m_pressed = true;
        }
        
        virtual void touchMove(const AGTouchInfo &t)
        {
            if(effectiveBounds().contains(t.position))
                m_pressed = true;
            else
                m_pressed = false;
        }
        
        virtual void touchUp(const AGTouchInfo &t)
        {
            if(effectiveBounds().contains(t.position))
            {
                // open number editor
                GLvertex2f size(m_size.x*2, m_size.y*G_RATIO);
                m_numInput = new AGUINumberInput(m_arrayEditor->position()+m_pos, size);
                m_numInput->setAction(^(bool accepted, float value) { numberInputAction(accepted, value); });
                addChild(m_numInput);
            }
            
            m_pressed = false;
        }
        
        
        void setEditAction(void (^editAction)(Element *e))
        {
            m_editAction = AGBlock_copy(editAction);
        }

        float value() { return m_value; }
        void setValueRef(float *valueRef)
        {
            if(valueRef)
            {
                m_hasValue = true;
                m_value = *valueRef;
            }
            
            m_valueRef = valueRef;
        }
        
        virtual GLvertex3f position() { return m_arrayEditor->position()+m_pos; }
        virtual GLvertex2f size() { return m_size; }

    protected:
        GLvertex3f m_geo[4];
        AGRenderInfoV m_renderInfo;
        
        GLvertex2f m_size;
        GLvertex3f m_pos;
        
        AGUIArrayEditor * const m_arrayEditor;
        
        bool m_hasValue;
        bool m_pressed;
        
        float m_value;
        float *m_valueRef;
        void (^m_editAction)(Element *e);
        
        AGUINumberInput *m_numInput;
        
        void numberInputAction(bool accepted, float value)
        {
            if(accepted)
            {
                m_hasValue = true;
                m_value = value;
                if(m_valueRef) *m_valueRef = m_value;
                if(m_editAction) m_editAction(this);
            }
            
            removeChild(m_numInput);
            delete m_numInput;
            m_numInput = NULL;
        }
    };
    
    static void initializeNodeEditor();
    
    AGUIArrayEditor(AGControlArrayNode *node) :
    m_node(node),
    m_doneEditing(false)
    {
        m_width = 0.08f*AGStyle::globalScale;
        m_height = 0.02f*AGStyle::globalScale;
        
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
        
        m_editAction = ^(Element *e){
            if(e == m_ghostElement)
            {
                m_node->m_items.push_back(e->value());
                e->setValueRef(&(m_node->m_items.back()));
                
                int len = m_node->m_items.size();
                m_ghostElement = new Element(this, GLvertex3f(-m_width/3.0f + m_width/3.0*len, 0.0f, 0.0f), GLvertex2f(m_width/3.0f, m_height));
                m_ghostElement->setValueRef(NULL);
                m_ghostElement->setEditAction(m_editAction);
                addChild(m_ghostElement);
            }
        };
        
        int j = 0;
        for(list<float>::iterator i = m_node->m_items.begin(); i != m_node->m_items.end(); i++)
        {
            Element *e = new Element(this, GLvertex3f(-m_width/3.0f + m_width/3.0*j, 0.0f, 0.0f), GLvertex2f(m_width/3.0f, m_height));
            e->setValueRef(&*i);
            e->setEditAction(m_editAction);
            addChild(e);
            j++;
        }
        
        m_ghostElement = new Element(this, GLvertex3f(-m_width/3.0f + m_width/3.0*j, 0.0f, 0.0f), GLvertex2f(m_width/3.0f, m_height));
        m_ghostElement->setValueRef(NULL);
        m_ghostElement->setEditAction(m_editAction);
        addChild(m_ghostElement);
    }
    
    ~AGUIArrayEditor()
    {
        m_editAction = NULL;
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
    
    AGControlArrayNode * const m_node;
    
    string m_title;
    
    float m_width, m_height;
    AGRenderInfoV m_boxOuterInfo, m_boxInnerInfo;
    GLvertex3f m_boxGeo[4];
    
    GLKMatrix4 m_modelView;
    AGSqueezeAnimation m_squeeze;

    bool m_doneEditing;
    
    //vector<Element *> m_elements;
    Element *m_ghostElement;
    void (^m_editAction)(Element *e);
    
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
    
    s_nodeInfo->type = "Array";
    
    float radius = 0.0057*AGStyle::globalScale;
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
AGControlNode(pos, s_nodeInfo)
{
    m_lastTime = 0;
    m_position = m_items.begin();
}

AGControlArrayNode::AGControlArrayNode(const AGDocument::Node &docNode) : AGControlNode(docNode, s_nodeInfo)
{
    m_lastTime = 0;
    m_position = m_items.begin();
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

void AGControlArrayNode::receiveControl(int port, AGControl *control)
{
    switch(port)
    {
        case 0: // iterate
            if(m_items.size())
            {
                m_control.v = *m_position;
                m_position++;
                if(m_position == m_items.end()) m_position = m_items.begin();
                
                pushControl(0, &m_control);
            }
            break;
    }
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

