//
//  AGNodeEditor.mm
//  Auragraph
//
//  Created by Spencer Salazar on 1/14/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#import "AGUINodeEditor.h"
#import "AGNode.h"
#import "AGStyle.h"
#import "AGGenericShader.h"
#import "AGHandwritingRecognizer.h"

#import "TexFont.h"

static const float AGNODESELECTOR_RADIUS = 0.02*AGStyle::globalScale;


//------------------------------------------------------------------------------
// ### AGUIStandardNodeEditor ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGUIStandardNodeEditor

static const int NODEEDITOR_ROWCOUNT = 5;


bool AGUIStandardNodeEditor::s_init = false;
float AGUIStandardNodeEditor::s_radius = 0;
GLuint AGUIStandardNodeEditor::s_geoSize = 0;
GLvertex3f * AGUIStandardNodeEditor::s_geo = NULL;
GLuint AGUIStandardNodeEditor::s_boundingOffset = 0;
GLuint AGUIStandardNodeEditor::s_innerboxOffset = 0;
GLuint AGUIStandardNodeEditor::s_buttonBoxOffset = 0;
GLuint AGUIStandardNodeEditor::s_itemEditBoxOffset = 0;

void AGUIStandardNodeEditor::initializeNodeEditor()
{
    if(!s_init)
    {
        s_init = true;
        
        s_geoSize = 16;
        s_geo = new GLvertex3f[s_geoSize];
        
        s_radius = AGNODESELECTOR_RADIUS;
        float radius = s_radius;
        
        // outer box
        // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
        s_geo[0] = GLvertex3f(-radius, radius, 0);
        s_geo[1] = GLvertex3f(-radius, -radius, 0);
        s_geo[2] = GLvertex3f(radius, -radius, 0);
        s_geo[3] = GLvertex3f(radius, radius, 0);
        
        // inner selection box
        // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
        s_geo[4] = GLvertex3f(-radius*0.95, radius/NODEEDITOR_ROWCOUNT, 0);
        s_geo[5] = GLvertex3f(-radius*0.95, -radius/NODEEDITOR_ROWCOUNT, 0);
        s_geo[6] = GLvertex3f(radius*0.95, -radius/NODEEDITOR_ROWCOUNT, 0);
        s_geo[7] = GLvertex3f(radius*0.95, radius/NODEEDITOR_ROWCOUNT, 0);
        
        // button box
        // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
        s_geo[8] = GLvertex3f(-radius*0.9*0.60, radius/NODEEDITOR_ROWCOUNT * 0.95, 0);
        s_geo[9] = GLvertex3f(-radius*0.9*0.60, -radius/NODEEDITOR_ROWCOUNT * 0.95, 0);
        s_geo[10] = GLvertex3f(radius*0.9*0.60, -radius/NODEEDITOR_ROWCOUNT * 0.95, 0);
        s_geo[11] = GLvertex3f(radius*0.9*0.60, radius/NODEEDITOR_ROWCOUNT * 0.95, 0);
        
        // item edit bounding box
        // stroke GL_LINE_STRIP + fill GL_TRIANGLE_FAN
        s_geo[12] = GLvertex3f(-radius*1.05, radius, 0);
        s_geo[13] = GLvertex3f(-radius*1.05, -radius, 0);
        s_geo[14] = GLvertex3f(radius*3.45, -radius, 0);
        s_geo[15] = GLvertex3f(radius*3.45, radius, 0);
        
        s_boundingOffset = 0;
        s_innerboxOffset = 4;
        s_buttonBoxOffset = 8;
        s_itemEditBoxOffset = 12;
    }
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
    initializeNodeEditor();
    
    string ucname = m_node->title();
    for(int i = 0; i < ucname.length(); i++)
        ucname[i] = toupper(ucname[i]);
    //    m_title = "EDIT " + ucname;
    //    m_title = "EDIT";
    m_title = ucname;
    
    m_xScale = lincurvef(AGStyle::open_animTimeX, AGStyle::open_squeezeHeight, 1);
    m_yScale = lincurvef(AGStyle::open_animTimeY, AGStyle::open_squeezeHeight, 1);
}

void AGUIStandardNodeEditor::update(float t, float dt)
{
    m_modelView = AGNode::globalModelViewMatrix();
    GLKMatrix4 projection = AGNode::projectionMatrix();
    
    m_modelView = GLKMatrix4Translate(m_modelView, m_node->position().x, m_node->position().y, m_node->position().z);
    
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
    
    m_modelView = GLKMatrix4Scale(m_modelView,
                                  m_yScale <= AGStyle::open_squeezeHeight ? (float)m_xScale : 1.0f,
                                  m_xScale >= 0.99f ? (float)m_yScale : AGStyle::open_squeezeHeight,
                                  1);
    
    m_normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(m_modelView), NULL);
    
    m_modelViewProjectionMatrix = GLKMatrix4Multiply(projection, m_modelView);
    
    m_currentDrawlineAlpha.update(dt);
    
    m_t += dt;
}

void AGUIStandardNodeEditor::render()
{
    TexFont *text = AGStyle::standardFont64();
    
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    /* draw bounding box */
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_geo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(GLKVertexAttribNormal);
    
    AGGenericShader::instance().useProgram();
    
    AGGenericShader::instance().setMVPMatrix(m_modelViewProjectionMatrix);
    AGGenericShader::instance().setNormalMatrix(m_normalMatrix);
    
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
    glDrawArrays(GL_LINE_LOOP, s_boundingOffset, 4);
    
    GLcolor4f blackA = GLcolor4f(0, 0, 0, 0.75);
    glVertexAttrib4fv(GLKVertexAttribColor, (const float*) &blackA);
    
    // fill
    glDrawArrays(GL_TRIANGLE_FAN, s_boundingOffset, 4);
    
    
    /* draw title */
    
    float rowCount = NODEEDITOR_ROWCOUNT;
    GLKMatrix4 proj = AGNode::projectionMatrix();
    
    GLKMatrix4 titleMV = GLKMatrix4Translate(m_modelView, -s_radius*0.9, s_radius - s_radius*2.0/rowCount, 0);
    titleMV = GLKMatrix4Scale(titleMV, 0.61, 0.61, 0.61);
    text->render(m_title, GLcolor4f::white, titleMV, proj);
    
    
    /* draw items */
    
    int numPorts = m_node->numEditPorts();
    
    for(int i = 0; i < numPorts; i++)
    {
        float y = s_radius - s_radius*2.0*(i+2)/rowCount;
        GLcolor4f nameColor(0.61, 0.61, 0.61, 1);
        GLcolor4f valueColor = GLcolor4f::white;
        
        if(i == m_hit)
        {
            glBindVertexArrayOES(0);
            glBindBuffer(GL_ARRAY_BUFFER, 0);
            
            /* draw hit box */
            
            glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_geo);
            glEnableVertexAttribArray(GLKVertexAttribPosition);
            glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
            glDisableVertexAttribArray(GLKVertexAttribColor);
            glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
            glDisableVertexAttribArray(GLKVertexAttribNormal);
            
            AGGenericShader::instance().useProgram();
            GLKMatrix4 hitMVP = GLKMatrix4Multiply(proj, GLKMatrix4Translate(m_modelView, 0, y + s_radius/rowCount, 0));
            AGGenericShader::instance().setMVPMatrix(hitMVP);
            AGGenericShader::instance().setNormalMatrix(m_normalMatrix);
            
            // fill
            glDrawArrays(GL_TRIANGLE_FAN, s_innerboxOffset, 4);
            
            // invert colors
            nameColor = GLcolor4f(1-nameColor.r, 1-nameColor.g, 1-nameColor.b, 1);
            valueColor = GLcolor4f(1-valueColor.r, 1-valueColor.g, 1-valueColor.b, 1);
        }
        
        GLKMatrix4 nameMV = GLKMatrix4Translate(m_modelView, -s_radius*0.9, y + s_radius/rowCount*0.1, 0);
        nameMV = GLKMatrix4Scale(nameMV, 0.61, 0.61, 0.61);
        text->render(m_node->editPortInfo(i).name, nameColor, nameMV, proj);
        
        GLKMatrix4 valueMV = GLKMatrix4Translate(m_modelView, s_radius*0.1, y + s_radius/rowCount*0.1, 0);
        valueMV = GLKMatrix4Scale(valueMV, 0.61, 0.61, 0.61);
        std::stringstream ss;
        float v = 0;
        m_node->getEditPortValue(i, v);
        ss << v;
        text->render(ss.str(), valueColor, valueMV, proj);
    }
    
    
    /* draw item editor */
    
    if(m_editingPort >= 0)
    {
        glBindVertexArrayOES(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), s_geo);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        glDisableVertexAttribArray(GLKVertexAttribColor);
        glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
        glDisableVertexAttribArray(GLKVertexAttribNormal);
        
        float y = s_radius - s_radius*2.0*(m_editingPort+2)/rowCount;
        
        AGGenericShader::instance().useProgram();
        AGGenericShader::instance().setNormalMatrix(m_normalMatrix);
        
        // bounding box
        GLKMatrix4 bbMVP = GLKMatrix4Multiply(proj, GLKMatrix4Translate(m_modelView, 0, y - s_radius + s_radius*2/rowCount, 0));
        AGGenericShader::instance().setMVPMatrix(bbMVP);
        
        // stroke
        glDrawArrays(GL_LINE_LOOP, s_itemEditBoxOffset, 4);
        
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &blackA);
        
        // fill
        glDrawArrays(GL_TRIANGLE_FAN, s_itemEditBoxOffset, 4);
        
        
        glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
        
        // accept button
        GLKMatrix4 buttonMVP = GLKMatrix4Multiply(proj, GLKMatrix4Translate(m_modelView, s_radius*1.65, y + s_radius/rowCount, 0));
        AGGenericShader::instance().setMVPMatrix(buttonMVP);
        if(m_hitAccept)
            // stroke
            glDrawArrays(GL_LINE_LOOP, s_buttonBoxOffset, 4);
        else
            // fill
            glDrawArrays(GL_TRIANGLE_FAN, s_buttonBoxOffset, 4);
        
        // discard button
        buttonMVP = GLKMatrix4Multiply(proj, GLKMatrix4Translate(m_modelView, s_radius*1.65 + s_radius*1.2, y + s_radius/rowCount, 0));
        AGGenericShader::instance().setMVPMatrix(buttonMVP);
        // fill
        if(m_hitDiscard)
            // stroke
            glDrawArrays(GL_LINE_LOOP, s_buttonBoxOffset, 4);
        else
            // fill
            glDrawArrays(GL_TRIANGLE_FAN, s_buttonBoxOffset, 4);
        
        // text
        GLKMatrix4 textMV = GLKMatrix4Translate(m_modelView, s_radius*1.2, y + s_radius/rowCount*0.1, 0);
        textMV = GLKMatrix4Scale(textMV, 0.5, 0.5, 0.5);
        if(m_hitAccept)
            text->render("Accept", GLcolor4f::white, textMV, proj);
        else
            text->render("Accept", GLcolor4f::black, textMV, proj);
        
        
        textMV = GLKMatrix4Translate(m_modelView, s_radius*1.2 + s_radius*1.2, y + s_radius/rowCount*0.1, 0);
        textMV = GLKMatrix4Scale(textMV, 0.5, 0.5, 0.5);
        if(m_hitDiscard)
            text->render("Discard", GLcolor4f::white, textMV, proj);
        else
            text->render("Discard", GLcolor4f::black, textMV, proj);
        
        // text name + value
        GLKMatrix4 nameMV = GLKMatrix4Translate(m_modelView, -s_radius*0.9, y + s_radius/rowCount*0.1, 0);
        nameMV = GLKMatrix4Scale(nameMV, 0.61, 0.61, 0.61);
        text->render(m_node->editPortInfo(m_editingPort).name, GLcolor4f::white, nameMV, proj);
        
        GLKMatrix4 valueMV = GLKMatrix4Translate(m_modelView, s_radius*0.1, y + s_radius/rowCount*0.1, 0);
        valueMV = GLKMatrix4Scale(valueMV, 0.61, 0.61, 0.61);
        //        std::stringstream ss;
        //        ss << m_currentValue;
        //        if(m_decimal && floorf(m_currentValue) == m_currentValue)
        //        {
        //            ss << "."; // show decimal point if user has drawn it
        //            // draw extra zeros after decimal
        //            int decimalZeros = (int)(-1-log10f(m_decimalFactor));
        //            for(int i = 0; i < decimalZeros; i++)
        //                ss << "0";
        //        }
        if(m_currentValueString.length() == 0)
            // show a 0 if there is no value yet
            text->render("0", GLcolor4f::white, valueMV, proj);
        else
            text->render(m_currentValueString, GLcolor4f::white, valueMV, proj);
        
        AGGenericShader::instance().useProgram();
        AGGenericShader::instance().setNormalMatrix(m_normalMatrix);
        AGGenericShader::instance().setMVPMatrix(GLKMatrix4Multiply(proj, AGNode::globalModelViewMatrix()));
        
        // draw traces
        for(std::list<std::vector<GLvertex3f> >::iterator i = m_drawline.begin(); i != m_drawline.end(); i++)
        {
            std::vector<GLvertex3f> geo = *i;
            std::list<std::vector<GLvertex3f> >::iterator next = i;
            next++;
            
            glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), geo.data());
            glEnableVertexAttribArray(GLKVertexAttribPosition);
            if(next == m_drawline.end())
            {
                GLcolor4f traceColor = GLcolor4f(1, 1, 1, m_currentDrawlineAlpha);
                glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &traceColor);
            }
            else
            {
                glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &GLcolor4f::white);
            }
            glDisableVertexAttribArray(GLKVertexAttribColor);
            glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
            glDisableVertexAttribArray(GLKVertexAttribNormal);
            
            glDrawArrays(GL_LINE_STRIP, 0, geo.size());
        }
    }
}


int AGUIStandardNodeEditor::hitTest(const GLvertex3f &t, bool *inBbox)
{
    float rowCount = NODEEDITOR_ROWCOUNT;
    
    *inBbox = false;
    
    GLvertex3f pos = m_node->position();
    
    if(m_editingPort >= 0)
    {
        float y = s_radius - s_radius*2.0*(m_editingPort+2)/rowCount;
        
        float bb_center = y - s_radius + s_radius*2/rowCount;
        if(t.x > pos.x+s_geo[s_itemEditBoxOffset].x && t.x < pos.x+s_geo[s_itemEditBoxOffset+2].x &&
           t.y > pos.y+bb_center+s_geo[s_itemEditBoxOffset+2].y && t.y < pos.y+bb_center+s_geo[s_itemEditBoxOffset].y)
        {
            *inBbox = true;
            
            GLvertex3f acceptCenter = pos + GLvertex3f(s_radius*1.65, y + s_radius/rowCount, pos.z);
            GLvertex3f discardCenter = pos + GLvertex3f(s_radius*1.65 + s_radius*1.2, y + s_radius/rowCount, pos.z);
            
            if(t.x > acceptCenter.x+s_geo[s_buttonBoxOffset].x && t.x < acceptCenter.x+s_geo[s_buttonBoxOffset+2].x &&
               t.y > acceptCenter.y+s_geo[s_buttonBoxOffset+2].y && t.y < acceptCenter.y+s_geo[s_buttonBoxOffset].y)
                return 1;
            if(t.x > discardCenter.x+s_geo[s_buttonBoxOffset].x && t.x < discardCenter.x+s_geo[s_buttonBoxOffset+2].x &&
               t.y > discardCenter.y+s_geo[s_buttonBoxOffset+2].y && t.y < discardCenter.y+s_geo[s_buttonBoxOffset].y)
                return 0;
        }
    }
    
    // check if in entire bounds
    else if(t.x > pos.x-s_radius && t.x < pos.x+s_radius &&
            t.y > pos.y-s_radius && t.y < pos.y+s_radius)
    {
        *inBbox = true;
        
        int numPorts = m_node->numEditPorts();
        
        for(int i = 0; i < numPorts; i++)
        {
            float y_max = pos.y + s_radius - s_radius*2.0*(i+1)/rowCount;
            float y_min = pos.y + s_radius - s_radius*2.0*(i+2)/rowCount;
            if(t.y > y_min && t.y < y_max)
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
        m_hit = hitTest(t, &inBBox);
        
        m_doneEditing = !inBBox;
    }
    else
    {
        m_hitAccept = false;
        m_startedInAccept = false;
        m_hitDiscard = false;
        m_startedInDiscard = false;
        
        bool inBBox = false;
        int hit = hitTest(t, &inBBox);
        
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
            int hit = hitTest(t, &inBBox);
            
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
            m_hit = hitTest(t, &inBBox);
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
                //                m_doneEditing = true;
                m_node->setEditPortValue(m_editingPort, m_currentValue);
                m_editingPort = -1;
                m_hitAccept = false;
                m_drawline.clear();
            }
            else if(m_hitDiscard)
            {
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
            m_hit = hitTest(t, &inBBox);
            
            if(m_hit >= 0)
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
        }
    }
}

GLvrectf AGUIStandardNodeEditor::effectiveBounds()
{
    if(m_editingPort >= 0)
    {
        // TODO HACK: overestimate bounds
        // because figuring out the item editor box bounds is too hard right now
        //        GLvertex2f size = GLvertex2f(s_radius*2, s_radius*2);
        //        return GLvrectf(m_node->position()-size, m_node->position()+size);
        
        float rowCount = NODEEDITOR_ROWCOUNT;
        GLvertex3f pos = m_node->position();
        float y = s_radius - s_radius*2.0*(m_editingPort+2)/rowCount;
        
        float bb_center = y - s_radius + s_radius*2/rowCount;
        return GLvrectf(GLvertex2f(pos.x+s_geo[s_itemEditBoxOffset].x,
                                   pos.y+bb_center+s_geo[s_itemEditBoxOffset+2].y),
                        GLvertex2f(pos.x+s_geo[s_itemEditBoxOffset+2].x,
                                   pos.y+bb_center+s_geo[s_itemEditBoxOffset].y));
    }
    else
    {
        GLvertex2f size = GLvertex2f(s_radius, s_radius);
        return GLvrectf(m_node->position()-size, m_node->position()+size);
    }
}

void AGUIStandardNodeEditor::renderOut()
{
    m_xScale = lincurvef(AGStyle::open_animTimeX/2, 1, AGStyle::open_squeezeHeight);
    m_yScale = lincurvef(AGStyle::open_animTimeY/2, 1, AGStyle::open_squeezeHeight);
}

bool AGUIStandardNodeEditor::finishedRenderingOut()
{
    return m_xScale <= AGStyle::open_squeezeHeight;
}

