//
//  AGNodeEditor.mm
//  Auragraph
//
//  Created by Spencer Salazar on 1/14/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGUINodeEditor.h"
#include "AGNode.h"
#include "AGStyle.h"
#include "AGGenericShader.h"
#include "AGHandwritingRecognizer.h"
#include "AGSlider.h"
#include "AGFileBrowser.h"
#include "AGFileManager.h"
#include "AGUndoManager.h"
#include "AGAnalytics.h"
#include "TexFont.h"

static const float AGNODESELECTOR_RADIUS = 0.02*AGStyle::oldGlobalScale;

/*------------------------------------------------------------------------------
 - AGUINodeEditor -
 Abstract base class of node editors.
 -----------------------------------------------------------------------------*/
#pragma mark - AGUINodeEditor

AGUINodeEditor::AGUINodeEditor() : m_pinned(false)
{
    AGInteractiveObject::addTouchOutsideListener(this);
}

AGUINodeEditor::~AGUINodeEditor()
{
    AGInteractiveObject::removeTouchOutsideListener(this);
}

void AGUINodeEditor::pin(bool _pin)
{
    m_pinned = _pin;
}

void AGUINodeEditor::unpin()
{
    m_pinned = false;
}

void AGUINodeEditor::touchOutside()
{
    if(!m_pinned)
    {
        removeFromTopLevel();
        AGInteractiveObject::removeTouchOutsideListener(this);
    }
}


/*------------------------------------------------------------------------------
 - AGUIPicker -
 Pick 1 of a list of string values.
 -----------------------------------------------------------------------------*/
#pragma mark - AGUIPicker

class AGUIPicker : public AGInteractiveObject
{
public:
    AGUIPicker(const GLvertex3f &pos, const GLvertex2f &size) :
    m_size(size)
    {
        setPosition(pos);
    }
    
    ~AGUIPicker() { }
    
    void setValues(const vector<string> &values)
    {
        m_values = values;
    }
    
    void setCurrentValue(int current)
    {
        m_current = current;
    }
    
    void onValuePicked(const std::function<void (int)> &valuePicked)
    {
        m_valuePicked = valuePicked;
    }
    
    void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        m_renderState.modelview = GLKMatrix4Translate(modelview(), m_pos.x, m_pos.y, m_pos.z);
    }
    
    void render() override
    {
        TexFont *text = AGStyle::standardFont64();
        
        if(!m_open)
        {
            if(m_current >= 0)
            {
                GLKMatrix4 textModelView = GLKMatrix4Translate(modelview(), -m_size.x/2+MARGIN_LEFT, (-text->descender()-text->ascender()/2)*TEXT_SCALE, 0);
                textModelView = GLKMatrix4Scale(textModelView, TEXT_SCALE, TEXT_SCALE, TEXT_SCALE);
                text->render(m_values[m_current], AGStyle::foregroundColor(), textModelView, projection());
            }
            
            // debug: draw bounds
            AGStyle::foregroundColor().set();
            drawLineLoop((GLvertex2f[]) {
                { -m_size.x/2, -m_size.y/2 },
                {  m_size.x/2, -m_size.y/2 },
                {  m_size.x/2,  m_size.y/2 },
                { -m_size.x/2,  m_size.y/2 },
            }, 4);
        }
        else
        {
            int numBefore = m_current;
            int numAfter = (int) ((m_values.size()-1)-m_current);
            
            // draw frame background
            AGStyle::backgroundColor().set();
            drawTriangleFan((GLvertex2f[]) {
                { -m_size.x/2, -numAfter*m_size.y-m_size.y/2 },
                {  m_size.x/2, -numAfter*m_size.y-m_size.y/2 },
                {  m_size.x/2, numBefore*m_size.y+m_size.y/2 },
                { -m_size.x/2, numBefore*m_size.y+m_size.y/2 },
            }, 4);
            
            // draw frame
            AGStyle::foregroundColor().set();
            drawLineLoop((GLvertex2f[]) {
                { -m_size.x/2, -numAfter*m_size.y-m_size.y/2 },
                {  m_size.x/2, -numAfter*m_size.y-m_size.y/2 },
                {  m_size.x/2, numBefore*m_size.y+m_size.y/2 },
                { -m_size.x/2, numBefore*m_size.y+m_size.y/2 },
            }, 4);
            
            // draw text items
            float y = numBefore*m_size.y;
            for(int i = 0; i < m_values.size(); i++)
            {
                GLKMatrix4 textModelView = GLKMatrix4Translate(modelview(),
                                                               -m_size.x/2+MARGIN_LEFT,
                                                               y+(-text->descender()-text->ascender()/2)*TEXT_SCALE, 0);
                textModelView = GLKMatrix4Scale(textModelView, TEXT_SCALE, TEXT_SCALE, TEXT_SCALE);
                
                if(i == m_selected)
                {
                    // draw highlight
                    float inset = 3;
                    AGStyle::foregroundColor().set();
                    drawTriangleFan((GLvertex2f[]) {
                        { -m_size.x/2+inset, y-m_size.y/2+inset },
                        {  m_size.x/2-inset, y-m_size.y/2+inset },
                        {  m_size.x/2-inset, y+m_size.y/2-inset },
                        { -m_size.x/2+inset, y+m_size.y/2-inset },
                    }, 4);
                    
                    text->render(m_values[i], AGStyle::backgroundColor(), textModelView, projection());
                }
                else
                {
                    text->render(m_values[i], AGStyle::foregroundColor(), textModelView, projection());
                }
                
                y -= m_size.y;
            }
        }
    }
    
    GLvrectf effectiveBounds() override
    {
        return GLvrectf(m_pos-m_size, m_pos+m_size);
    }
    
    void touchDown(const AGTouchInfo &t) override
    {
        m_open = true;
        m_selected = _itemAtPoint(t.position);
    }
    
    void touchMove(const AGTouchInfo &t) override
    {
        m_selected = _itemAtPoint(t.position);
    }
    
    void touchUp(const AGTouchInfo &t) override
    {
        m_open = false;
        m_selected = _itemAtPoint(t.position);
        if(m_selected >= 0)
            m_valuePicked(m_selected);
    }
    
private:
    
    constexpr const static float MARGIN_LEFT = 5;
    constexpr const static float TEXT_SCALE = G_RATIO-1;
    
    int _itemAtPoint(const GLvertex3f &_pt)
    {
        GLvertex3f pt = _pt-m_pos;
        
        int numBefore = m_current;
        
        for(int i = 0; i < m_values.size(); i++)
        {
            float y = numBefore*m_size.y-i*m_size.y;
            if(pt.x > -m_size.x/2 && pt.x < m_size.x/2 &&
               pt.y > y-m_size.y/2 && pt.y < y+m_size.y/2)
                return i;
        }
        
        return -1;
    }
    
    GLvertex2f m_size;
    
    bool m_open = false;
    
    vector<string> m_values;
    int m_current = -1;
    int m_selected = -1;
    
    std::function<void (int)> m_valuePicked = [](int){};
};

//------------------------------------------------------------------------------
// ### AGUIStandardNodeEditor ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGUIStandardNodeEditor

static const int NODEEDITOR_ROWCOUNT = 5;

void AGUIStandardNodeEditor::initializeNodeEditor()
{
    m_geoSize = 16;
    m_geo = new GLvertex3f[m_geoSize];
    
    float radius = m_radius;
    
    // outer box
    // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
    m_geo[0] = GLvertex3f(-radius, m_radiusY, 0);
    m_geo[1] = GLvertex3f(-radius, -m_radiusY, 0);
    m_geo[2] = GLvertex3f(radius, -m_radiusY, 0);
    m_geo[3] = GLvertex3f(radius, m_radiusY, 0);
    
    // inner selection box
    // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
    m_geo[4] = GLvertex3f(-radius*0.95, radius/NODEEDITOR_ROWCOUNT, 0);
    m_geo[5] = GLvertex3f(-radius*0.95, -radius/NODEEDITOR_ROWCOUNT, 0);
    m_geo[6] = GLvertex3f(radius*0.95, -radius/NODEEDITOR_ROWCOUNT, 0);
    m_geo[7] = GLvertex3f(radius*0.95, radius/NODEEDITOR_ROWCOUNT, 0);
    
    // button box
    // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
    m_geo[8] = GLvertex3f(-radius*0.9*0.60, radius/NODEEDITOR_ROWCOUNT * 0.95, 0);
    m_geo[9] = GLvertex3f(-radius*0.9*0.60, -radius/NODEEDITOR_ROWCOUNT * 0.95, 0);
    m_geo[10] = GLvertex3f(radius*0.9*0.60, -radius/NODEEDITOR_ROWCOUNT * 0.95, 0);
    m_geo[11] = GLvertex3f(radius*0.9*0.60, radius/NODEEDITOR_ROWCOUNT * 0.95, 0);
    
    // item edit bounding box
    // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
    m_geo[12] = GLvertex3f(-radius*1.05, radius, 0);
    m_geo[13] = GLvertex3f(-radius*1.05, -radius, 0);
    m_geo[14] = GLvertex3f(radius*3.45, -radius, 0);
    m_geo[15] = GLvertex3f(radius*3.45, radius, 0);
    
    m_boundingOffset = 0;
    m_innerboxOffset = 4;
    m_buttonBoxOffset = 8;
    m_itemEditBoxOffset = 12;
}

AGUIStandardNodeEditor::AGUIStandardNodeEditor(AGNode *node) :
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
    m_radius = AGNODESELECTOR_RADIUS;
    
    float rowCount = NODEEDITOR_ROWCOUNT;
    float rowHeight = m_radius*2.0/rowCount;
    int numEditPorts = m_node->numEditPorts();
    
    if(numEditPorts <= 4)
        m_radiusY = m_radius;
    else
        m_radiusY = m_radius+rowHeight/2.0f*1.1f*(numEditPorts-4);

    initializeNodeEditor();
    
    string ucname = m_node->title();
    for(int i = 0; i < ucname.length(); i++)
        ucname[i] = toupper(ucname[i]);
    m_title = ucname;
    
    m_xScale = lincurvef(AGStyle::open_animTimeX, AGStyle::open_squeezeHeight, 1);
    m_yScale = lincurvef(AGStyle::open_animTimeY, AGStyle::open_squeezeHeight, 1);
    
    for(int port = 0; port < numEditPorts; port++)
    {
        AGPortInfo info = m_node->editPortInfo(port);
        AGControl::Type editPortType = info.type;
        AGPortInfo::EditorMode editorMode = info.editorMode;
        float y = m_radiusY-rowHeight*(port+2);

        AGParamValue v;
        m_node->getEditPortValue(port, v);
        
        if(editorMode == AGPortInfo::EDITOR_ENUM)
        {
            float y = m_radiusY-rowHeight*(port+2);
            
            AGUIPicker *picker = new AGUIPicker(GLvertex3f(m_radius/2, y+rowHeight/4, 0),
                                                GLvertex2f(m_radius*0.9, rowHeight*0.9));
            picker->init();
            
            vector<string> values;
            for(int i = 0; i < info.enumInfo.size(); i++)
            {
                values.push_back(info.enumInfo[i].name);
                if(v.getInt() == info.enumInfo[i].value)
                    picker->setCurrentValue(i);
            }
            picker->setValues(values);
            AGParamValue currentValue;
            m_node->getEditPortValue(port, currentValue);
            picker->setCurrentValue(currentValue);
            
            picker->onValuePicked([this, port, picker](int selected){
                m_node->setEditPortValue(port, selected);
                picker->setCurrentValue(selected);
            });
            
            addChild(picker);
        }
        // only use sliders for float/int
        else if(editPortType == AGControl::TYPE_NONE ||
                editPortType == AGControl::TYPE_FLOAT ||
                editPortType == AGControl::TYPE_INT)
        {
            AGSlider *slider = new AGSlider(GLvertex3f(m_radius/2, y+rowHeight/4, 0), v);
            slider->init();
            
            if(editPortType == AGControl::TYPE_FLOAT)
                slider->setType(AGSlider::CONTINUOUS);
            else if(editPortType == AGControl::TYPE_INT)
                slider->setType(AGSlider::DISCRETE);
            else
                slider->setType(AGSlider::CONTINUOUS);
            
            if(info.mode == AGPortInfo::LIN)
                slider->setScale(AGSlider::LINEAR);
            else if(info.mode == AGPortInfo::EXP)
                slider->setScale(AGSlider::EXPONENTIAL);
            else
                slider->setScale(AGSlider::EXPONENTIAL);
            
            slider->setSize(GLvertex2f(m_radius, rowHeight));
            
            slider->onUpdate([this, port] (float value) {
                m_node->setEditPortValue(port, value);
            });
            slider->onStartStopUpdating([this, port](float){},
            [this, port](float _old, float _new){
                AGAnalytics::instance().eventEditNodeParamSlider(m_node->type(), m_node->editPortInfo(port).name);
                // handle undo/redo
                AGUndoAction *action = AGUndoAction::editParamUndoAction(m_node, port, _old, _new);
                AGUndoManager::instance().pushUndoAction(action);
            });
            slider->setValidator([this, port] (float _old, float _new) {
                return m_node->validateEditPortValue(port, _new);
            });
            
            m_editSliders[port] = slider;
            this->addChild(slider);
        }
        else if(editPortType == AGControl::TYPE_BIT)
        {
            if(info.editorMode == AGPortInfo::EDITOR_ACTION)
            {
                GLvertex2f size = GLvertex2f(m_radius*2*(G_RATIO-1), rowHeight*(G_RATIO-1));
                AGUIButton *actionButton = new AGUIButton(info.name, GLvertex2f(-size.x/2, y), size);
                actionButton->init();
                actionButton->setAction(^{
                    m_node->setEditPortValue(port, AGControl(actionButton->isPressed()));
                });
                actionButton->setRenderFixed(false);
                
                addChild(actionButton);
            }
            else
            {
                AGUIButton *checkButton = AGUIButton::makeCheckButton();
                checkButton->setAction(^{
                    m_node->setEditPortValue(port, AGControl(checkButton->isPressed()));
                });
                float x = m_radius/2;
                checkButton->setPosition(GLvertex3f(x, y+checkButton->size().y*0.75f, 0));
                checkButton->setLatched(v.getBit());
                
                addChild(checkButton);
            }
        }
    }
    
    float pinButtonWidth = 20;
    float pinButtonHeight = 20;
    float pinButtonX = m_radius-10-pinButtonWidth/2;
    float pinButtonY = m_radiusY-10-pinButtonHeight/2;
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

AGUIStandardNodeEditor::~AGUIStandardNodeEditor()
{
    m_editSliders.clear();
    m_pinButton = NULL;
    // sliders are child objects, so they get deleted automatically by AGRenderObject
}

GLvertex3f AGUIStandardNodeEditor::position()
{
    return m_node->position();
}

void AGUIStandardNodeEditor::update(float t, float dt)
{
    m_renderState.modelview = AGNode::globalModelViewMatrix();
    m_renderState.projection = AGNode::projectionMatrix();
    
    m_renderState.modelview = GLKMatrix4Translate(m_renderState.modelview, position().x, position().y, position().z);
    
    //    float squeezeHeight = AGStyle::open_squeezeHeight;
    //    float animTimeX = AGStyle::open_animTimeX;
    //    float animTimeY = AGStyle::open_animTimeY;
    //
    //    if(m_t < animTimeX)
    //        m_modelView = GLKMatrix4Scale(m_modelView, squeezeHeight+(m_t/animTimeX)*(1-squeezeHeight), squeezeHeight, 1);
    //    else if(m_t < animTimeX+animTimeY)
    //        m_modelView = GLKMatrix4Scale(m_modelView, 1.0, squeezeHeight+((m_t-animTimeX)/animTimeY)*(1-squeezeHeight), 1);
    
    if(m_yScale <= AGStyle::open_squeezeHeight) m_xScale.update(dt);
    if(m_xScale >= 0.99f) m_yScale.update(dt);
    
    m_renderState.modelview = GLKMatrix4Scale(m_renderState.modelview,
                                              m_yScale <= AGStyle::open_squeezeHeight ? (float)m_xScale : 1.0f,
                                              m_xScale >= 0.99f ? (float)m_yScale : AGStyle::open_squeezeHeight,
                                              1);
    
    m_currentDrawlineAlpha.update(dt);
    
    updateChildren(t, dt);
    
    m_t += dt;
}

void AGUIStandardNodeEditor::render()
{
    TexFont *text = AGStyle::standardFont64();
    
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    /* draw bounding box */
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    AGStyle::foregroundColor().set();
    glDisableVertexAttribArray(AGVertexAttribColor);
    glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(AGVertexAttribNormal);
    
    AGGenericShader::instance().useProgram();
    
    AGGenericShader::instance().setModelViewMatrix(modelview());
    AGGenericShader::instance().setProjectionMatrix(projection());
    
    //    AGClipShader &shader = AGClipShader::instance();
    //
    //    shader.useProgram();
    //
    //    shader.setMVPMatrix(m_modelViewProjectionMatrix);
    //    shader.setNormalMatrix(m_normalMatrix);
    //    shader.setClip(GLvertex2f(-m_radius, -m_radius), GLvertex2f(m_radius*2, m_radius*2));
    //    shader.setLocalMatrix(GLKMatrix4Identity);
    //
    //    GLKMatrix4 localMatrix;
    
    // stroke
    glLineWidth(4.0f);
    glDrawArrays(GL_LINE_LOOP, m_boundingOffset, 4);
    
    GLcolor4f bg = AGStyle::frameBackgroundColor().withAlpha(0.75);
    bg.set();
    
    // fill
    glDrawArrays(GL_TRIANGLE_FAN, m_boundingOffset, 4);
    
    
    /* draw title */
    
    float rowCount = NODEEDITOR_ROWCOUNT;
    float textScale = 0.61;
    
    float textAscender = text->ascender();
    GLKMatrix4 titleMV = GLKMatrix4Translate(modelview(), -m_radius*0.9, m_radiusY-m_radius*2.0/rowCount+textAscender*textScale*0.5f, 0);
    titleMV = GLKMatrix4Scale(titleMV, textScale, textScale, textScale);
    text->render(m_title, AGStyle::foregroundColor(), titleMV, projection());
    
    /* draw items */
    
    int numPorts = m_node->numEditPorts();
    
    for(int i = 0; i < numPorts; i++)
    {
        AGPortInfo portInfo = m_node->editPortInfo(i);
        
        if(portInfo.editorMode == AGPortInfo::EDITOR_ACTION)
            // dont render for action button edit items
            continue;
        
        float y = m_radiusY - m_radius*2.0*(i+2)/rowCount;
        GLcolor4f nameColor = AGStyle::foregroundColor().blend(0.61, 0.61, 0.61);
        GLcolor4f valueColor = AGStyle::foregroundColor();
        
        if(i == m_hit)
        {
            glBindVertexArrayOES(0);
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            
            /* draw hit box */
            
            glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
            glEnableVertexAttribArray(AGVertexAttribPosition);
            AGStyle::foregroundColor().set();
            glDisableVertexAttribArray(AGVertexAttribColor);
            glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
            glDisableVertexAttribArray(AGVertexAttribNormal);
            
            AGGenericShader::instance().useProgram();
            GLKMatrix4 hitMV = GLKMatrix4Translate(modelview(), 0, y + m_radius/rowCount, 0);
            AGGenericShader::instance().setModelViewMatrix(hitMV);
            AGGenericShader::instance().setProjectionMatrix(projection());
            
            // fill
            glDrawArrays(GL_TRIANGLE_FAN, m_innerboxOffset, 4);
            
            // invert colors
            nameColor = GLcolor4f(1-nameColor.r, 1-nameColor.g, 1-nameColor.b, 1);
            valueColor = GLcolor4f(1-valueColor.r, 1-valueColor.g, 1-valueColor.b, 1);
        }
        
        GLKMatrix4 nameMV = GLKMatrix4Translate(modelview(), -m_radius*0.9, y + m_radius/rowCount*0.1, 0);
        nameMV = GLKMatrix4Scale(nameMV, 0.61, 0.61, 0.61);
        text->render(portInfo.name, nameColor, nameMV, projection());

        // TODO: figure out a way to communicate changes in params within a node
        // to the slider itself, and move this stuff out of the render function
        AGParamValue v;
        m_node->getEditPortValue(i, v);
        AGControl::Type t = m_node->editPortInfo(i).type;
        
        if((t == AGControl::TYPE_INT || t == AGControl::TYPE_FLOAT) &&
           m_node->editPortInfo(i).editorMode != AGPortInfo::EDITOR_ENUM)
        {
            m_editSliders.at(i)->setValue(v);
        }
        else if(t == AGControl::TYPE_STRING)
        {
            GLKMatrix4 valueMV = GLKMatrix4Translate(modelview(), m_radius*0.1, y + m_radius/rowCount*0.1, 0);
            valueMV = GLKMatrix4Scale(valueMV, 0.61, 0.61, 0.61);
            //AGParamValue v;
            //m_node->getEditPortValue(i, v);
            text->render(v, valueColor, valueMV, projection());
        }
    }
    
//    for(auto slider : m_editSliders)
//        slider->render();
//    
//    m_pinButton->render();
    
    renderChildren();
    
    /* draw item editor */
    
    if(m_editingPort >= 0)
    {
        glBindVertexArrayOES(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), m_geo);
        glEnableVertexAttribArray(AGVertexAttribPosition);
        AGStyle::foregroundColor().set();
        glDisableVertexAttribArray(AGVertexAttribColor);
        glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
        glDisableVertexAttribArray(AGVertexAttribNormal);
        
        float y = m_radiusY - m_radius*2.0*(m_editingPort+2)/rowCount;
        
        AGGenericShader::instance().useProgram();
        AGGenericShader::instance().setProjectionMatrix(projection());
        
        // bounding box
        GLKMatrix4 bbMV = GLKMatrix4Translate(modelview(), 0, y - m_radius + m_radius*2/rowCount, 0);
        AGGenericShader::instance().setModelViewMatrix(bbMV);
        
        // stroke
        glDrawArrays(GL_LINE_LOOP, m_itemEditBoxOffset, 4);
        
        bg.set();
        
        // fill
        glDrawArrays(GL_TRIANGLE_FAN, m_itemEditBoxOffset, 4);
        
        AGStyle::foregroundColor().set();
        
        // accept button
        GLKMatrix4 buttonMV = GLKMatrix4Translate(modelview(), m_radius*1.65, y + m_radius/rowCount, 0);
        AGGenericShader::instance().setModelViewMatrix(buttonMV);
        if(m_hitAccept)
            // stroke
            glDrawArrays(GL_LINE_LOOP, m_buttonBoxOffset, 4);
        else
            // fill
            glDrawArrays(GL_TRIANGLE_FAN, m_buttonBoxOffset, 4);
        
        // discard button
        buttonMV = GLKMatrix4Translate(modelview(), m_radius*1.65 + m_radius*1.2, y + m_radius/rowCount, 0);
        AGGenericShader::instance().setModelViewMatrix(buttonMV);
        // fill
        if(m_hitDiscard)
            // stroke
            glDrawArrays(GL_LINE_LOOP, m_buttonBoxOffset, 4);
        else
            // fill
            glDrawArrays(GL_TRIANGLE_FAN, m_buttonBoxOffset, 4);
        
        // text
        GLKMatrix4 textMV = GLKMatrix4Translate(modelview(), m_radius*1.2, y + m_radius/rowCount*0.1, 0);
        textMV = GLKMatrix4Scale(textMV, 0.5, 0.5, 0.5);
        if(m_hitAccept)
            text->render("Accept", AGStyle::foregroundColor(), textMV, projection());
        else
            text->render("Accept", AGStyle::frameBackgroundColor(), textMV, projection());
        
        
        textMV = GLKMatrix4Translate(modelview(), m_radius*1.2 + m_radius*1.2, y + m_radius/rowCount*0.1, 0);
        textMV = GLKMatrix4Scale(textMV, 0.5, 0.5, 0.5);
        if(m_hitDiscard)
            text->render("Discard", AGStyle::foregroundColor(), textMV, projection());
        else
            text->render("Discard", AGStyle::frameBackgroundColor(), textMV, projection());
        
        // text name + value
        GLKMatrix4 nameMV = GLKMatrix4Translate(modelview(), -m_radius*0.9, y + m_radius/rowCount*0.1, 0);
        nameMV = GLKMatrix4Scale(nameMV, 0.61, 0.61, 0.61);
        text->render(m_node->editPortInfo(m_editingPort).name, AGStyle::foregroundColor(), nameMV, projection());
        
        GLKMatrix4 valueMV = GLKMatrix4Translate(modelview(), m_radius*0.1, y + m_radius/rowCount*0.1, 0);
        valueMV = GLKMatrix4Scale(valueMV, 0.61, 0.61, 0.61);

        if(m_currentValueString.length() == 0)
            // show a 0 if there is no value yet
            text->render("0", AGStyle::foregroundColor(), valueMV, projection());
        else
            text->render(m_currentValueString, AGStyle::foregroundColor(), valueMV, projection());
        
        AGGenericShader::instance().useProgram();
        AGGenericShader::instance().setProjectionMatrix(projection());
        AGGenericShader::instance().setModelViewMatrix(AGNode::globalModelViewMatrix());
        
        // draw traces
        for(std::list<std::vector<GLvertex3f> >::iterator i = m_drawline.begin(); i != m_drawline.end(); i++)
        {
            std::vector<GLvertex3f> geo = *i;
            std::list<std::vector<GLvertex3f> >::iterator next = i;
            next++;
            
            glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), geo.data());
            glEnableVertexAttribArray(AGVertexAttribPosition);
            if(next == m_drawline.end())
                AGStyle::foregroundColor().withAlpha(m_currentDrawlineAlpha).set();
            else
                AGStyle::foregroundColor().set();
            glDisableVertexAttribArray(AGVertexAttribColor);
            glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
            glDisableVertexAttribArray(AGVertexAttribNormal);
            
            glDrawArrays(GL_LINE_STRIP, 0, (GLsizei) geo.size());
        }
    }
}


AGInteractiveObject *AGUIStandardNodeEditor::hitTest(const GLvertex3f &t)
{
    if(m_editingPort >= 0)
    {
        bool inBbox = false;
        hitTestX(t, &inBbox);
        if(inBbox)
            return this;
    }
    
    return AGInteractiveObject::hitTest(t);
}


int AGUIStandardNodeEditor::hitTestX(const GLvertex3f &t, bool *inBbox)
{
    float rowCount = NODEEDITOR_ROWCOUNT;

    *inBbox = false;
    
    GLvertex3f pos = m_node->position();
    
    if(m_editingPort >= 0)
    {
        float y = m_radiusY - m_radius*2.0*(m_editingPort+2)/rowCount;

        float bb_center = y - m_radius + m_radius*2/rowCount;
        if(t.x > pos.x+m_geo[m_itemEditBoxOffset].x && t.x < pos.x+m_geo[m_itemEditBoxOffset+2].x &&
           t.y > pos.y+bb_center+m_geo[m_itemEditBoxOffset+2].y && t.y < pos.y+bb_center+m_geo[m_itemEditBoxOffset].y)
        {
            *inBbox = true;
            
            GLvertex3f acceptCenter = pos + GLvertex3f(m_radius*1.65, y + m_radius/rowCount, pos.z);
            GLvertex3f discardCenter = pos + GLvertex3f(m_radius*1.65 + m_radius*1.2, y + m_radius/rowCount, pos.z);
            
            if(t.x > acceptCenter.x+m_geo[m_buttonBoxOffset].x && t.x < acceptCenter.x+m_geo[m_buttonBoxOffset+2].x &&
               t.y > acceptCenter.y+m_geo[m_buttonBoxOffset+2].y && t.y < acceptCenter.y+m_geo[m_buttonBoxOffset].y)
                return 1;
            if(t.x > discardCenter.x+m_geo[m_buttonBoxOffset].x && t.x < discardCenter.x+m_geo[m_buttonBoxOffset+2].x &&
               t.y > discardCenter.y+m_geo[m_buttonBoxOffset+2].y && t.y < discardCenter.y+m_geo[m_buttonBoxOffset].y)
                return 0;
        }
    }
    
    // check if in entire bounds
    else if(t.x > pos.x-m_radius && t.x < pos.x+m_radius &&
            t.y > pos.y-m_radius && t.y < pos.y+m_radius)
    {
        *inBbox = true;
        
        int numPorts = m_node->numEditPorts();
        
        for(int i = 0; i < numPorts; i++)
        {
            float y_max = pos.y + m_radiusY - m_radius*2.0*(i+1)/rowCount;
            float y_min = pos.y + m_radiusY - m_radius*2.0*(i+2)/rowCount;
            
            AGPortInfo info = m_node->editPortInfo(i);
            AGControl::Type editPortType = info.type;
            
            if(t.y > y_min && t.y < y_max &&
               (editPortType == AGControl::TYPE_NONE ||
                editPortType == AGControl::TYPE_FLOAT ||
                editPortType == AGControl::TYPE_INT ||
                editPortType == AGControl::TYPE_STRING))
            {
                return i;
            }
        }
    }
    
    return -1;
}

void AGUIStandardNodeEditor::touchDown(const AGTouchInfo &t)
{
    touchDown(t.position, t.screenPosition);
}

void AGUIStandardNodeEditor::touchMove(const AGTouchInfo &t)
{
    touchMove(t.position, t.screenPosition);
}

void AGUIStandardNodeEditor::touchUp(const AGTouchInfo &t)
{
    touchUp(t.position, t.screenPosition);
}


void AGUIStandardNodeEditor::touchDown(const GLvertex3f &t, const CGPoint &screen)
{
    if(m_editingPort < 0)
    {
        m_hit = -1;
        bool inBBox = false;
        
        // check if in entire bounds
        m_hit = hitTestX(t, &inBBox);
        
        m_doneEditing = !inBBox;
        
        if(m_doneEditing && m_customItemEditor)
            removeChild(m_customItemEditor);
    }
    else
    {
        m_hitAccept = false;
        m_startedInAccept = false;
        m_hitDiscard = false;
        m_startedInDiscard = false;
        
        bool inBBox = false;
        int hit = hitTestX(t, &inBBox);
        
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
            m_currentDrawlineAlpha.forceTo(1);
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

void AGUIStandardNodeEditor::touchMove(const GLvertex3f &t, const CGPoint &screen)
{
    if(!m_doneEditing)
    {
        if(m_editingPort >= 0)
        {
            bool inBBox = false;
            int hit = hitTestX(t, &inBBox);
            
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
            m_hit = hitTestX(t, &inBBox);
        }
    }
}

void AGUIStandardNodeEditor::touchUp(const GLvertex3f &t, const CGPoint &screen)
{
    if(!m_doneEditing)
    {
        if(m_editingPort >= 0)
        {
            if(m_hitAccept)
            {
                AGAnalytics::instance().eventEditNodeParamDrawAccept(m_node->type(), m_node->editPortInfo(m_editingPort).name);
                
                //                m_doneEditing = true;
                m_node->setEditPortValue(m_editingPort, m_currentValue);
                m_editSliders[m_editingPort]->setValue(m_currentValue);
                m_editingPort = -1;
                m_hitAccept = false;
                m_drawline.clear();
            }
            else if(m_hitDiscard)
            {
                AGAnalytics::instance().eventEditNodeParamDrawDiscard(m_node->type(), m_node->editPortInfo(m_editingPort).name);
                
                //                m_doneEditing = true;
                m_editingPort = -1;
                m_hitDiscard = false;
                m_drawline.clear();
            }
            else if(m_currentTrace.getNumberOfPoints() > 0 && !m_startedInDiscard && !m_startedInAccept)
            {
                // attempt recognition
                AGHandwritingRecognizerFigure figure = [[AGHandwritingRecognizer instance] recognizeNumeral:m_currentTrace];
                int digit = -1;
                
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
                        digit = (figure-'0');
                        AGAnalytics::instance().eventDrawNumeral(digit);
                        if(m_decimal)
                        {
                            m_currentValue = m_currentValue + digit*m_decimalFactor;
                            m_decimalFactor *= 0.1;
                            m_currentValueStream << digit;
                        }
                        else
                        {
                            m_currentValue = m_currentValue*10 + digit;
                            m_currentValueStream << digit;
                        }
                        m_lastTraceWasRecognized = true;
                        break;
                        
                    case AG_FIGURE_PERIOD:
                        //AGAnalytics::instance().eventDrawNumeral();
                        if(m_decimal)
                        {
                            m_lastTraceWasRecognized = false;
                        }
                        else
                        {
                            m_decimalFactor = 0.1;
                            if(m_currentValue == 0)
                                m_currentValueStream << "0"; // prepend 0 to look better
                            m_currentValueStream << ".";
                            m_lastTraceWasRecognized = true;
                            m_decimal = true;
                        }
                        break;
                        
                    default:
                        AGAnalytics::instance().eventDrawNumeralUnrecognized();
                        m_lastTraceWasRecognized = false;
                }
                
                if(m_lastTraceWasRecognized)
                    m_currentValueString = m_currentValueStream.str();
                else
                    m_currentDrawlineAlpha.reset(1, 0);
            }
        }
        else
        {
            bool inBBox = false;
            m_hit = hitTestX(t, &inBBox);
            
            if(m_hit >= 0)
            {
                AGAnalytics::instance().eventEditNodeParamDrawOpen(m_node->type(), m_node->editPortInfo(m_hit).name);
                
                const AGPortInfo &portInfo = m_node->editPortInfo(m_hit);
                if(portInfo.editorMode == AGPortInfo::EDITOR_DEFAULT)
                {
                    m_editingPort = m_hit;
                    m_hit = -1;
                    m_currentValue = 0;
                    m_currentValueStream.str(std::string()); // clear
                    m_currentValueString = m_currentValueStream.str();
                    m_decimal = false;
                    m_drawline.clear();
                    //m_node->getEditPortValue(m_editingPort, m_currentValue);
                }
                else if(portInfo.editorMode == AGPortInfo::EDITOR_AUDIOFILES)
                {
                    int hitPort = m_hit;
                    m_hit = -1;
                    
                    AGFileBrowser *fileBrowser = new AGFileBrowser;
                    fileBrowser->init();
                    
                    fileBrowser->setFilter([](const string &path){
                        string ext = ".wav";
                        // if has ext
                        if(path.size() >= ext.size() && path.compare(path.size() - ext.size(), ext.size(), ext) == 0)
                            return true;
                        else
                            return false;
                    });
                    fileBrowser->setDirectoryPath(AGFileManager::instance().soundfileDirectory());
                    
                    m_customItemEditor = fileBrowser;
                    addChildToTop(m_customItemEditor);
                    
                    fileBrowser->onChooseFile([hitPort, this](const string &file){
                        m_node->setEditPortValue(hitPort, file);
                        removeChild(m_customItemEditor);
                        m_customItemEditor = NULL;
                    });
                    
                    fileBrowser->onCancel([this](){
                        removeChild(m_customItemEditor);
                        m_customItemEditor = NULL;
                    });
                }
            }
        }
    }
}

GLvrectf AGUIStandardNodeEditor::effectiveBounds()
{
    if(m_editingPort >= 0)
    {
        // TODO HACK: overestimate bounds
        // because figuring out the item editor box bounds is too hard right now
        //        GLvertex2f size = GLvertex2f(m_radius*2, m_radius*2);
        //        return GLvrectf(m_node->position()-size, m_node->position()+size);
        
        float rowCount = NODEEDITOR_ROWCOUNT;
        GLvertex3f pos = m_node->position();
        float y = m_radius - m_radius*2.0*(m_editingPort+2)/rowCount;
        
        float bb_center = y - m_radius + m_radius*2/rowCount;
        return GLvrectf(GLvertex2f(pos.x+m_geo[m_itemEditBoxOffset].x,
                                   pos.y+bb_center+m_geo[m_itemEditBoxOffset+2].y),
                        GLvertex2f(pos.x+m_geo[m_itemEditBoxOffset+2].x,
                                   pos.y+bb_center+m_geo[m_itemEditBoxOffset].y));
    }
    else
    {
        GLvertex2f size = GLvertex2f(m_radius, m_radius);
        return GLvrectf(m_node->position()-size, m_node->position()+size);
    }
}

void AGUIStandardNodeEditor::renderOut()
{
    m_xScale = lincurvef(AGStyle::open_animTimeX/2, 1, AGStyle::open_squeezeHeight);
    m_yScale = lincurvef(AGStyle::open_animTimeY/2, 1, AGStyle::open_squeezeHeight);
    
    // cause custom item editor to fade out also
    if(m_customItemEditor)
        removeChild(m_customItemEditor);
}

bool AGUIStandardNodeEditor::finishedRenderingOut()
{
    return m_xScale <= AGStyle::open_squeezeHeight;
}

