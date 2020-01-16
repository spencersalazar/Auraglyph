//
//  AGControlGestureNode.mm
//  Auragraph
//
//  Created by Spencer Salazar on 3/30/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGControlGestureNode.h"
#include "GeoGenerator.h"
#include "AGUINodeEditor.h"
#include "AGStyle.h"


class AGControlGestureNodeEditor : public AGUINodeEditor
{
private:
    AGControlGestureNode * const m_node;
    GLvertex2f m_size;
    
    AGSqueezeAnimation m_squeeze;
    bool m_doneEditing;
    
public:
    AGControlGestureNodeEditor(AGControlGestureNode *node) :
    m_node(node), m_doneEditing(false)
    {
        m_squeeze.open();

        m_size = GLvertex2f(200, 200);
    }
    
    GLvertex3f position() const override { return m_node->position(); }
    GLvertex2f size() override { return m_size; }
    
    void update(float t, float dt) override
    {
        AGRenderObject::update(t, dt);
        
        m_squeeze.update(t, dt);
        
        m_renderState.modelview = GLKMatrix4Translate(m_renderState.modelview, position().x, position().y, 0);
        m_renderState.modelview = m_squeeze.apply(m_renderState.modelview);
    }

    void render() override
    {
        GLvertex3f box[4];
        GeoGen::makeRect(box, m_size.x, m_size.y);
        
        // fill frame
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &AGStyle::frameBackgroundColor());
        drawTriangleFan(box, 4);
        
        // stroke frame
        glLineWidth(2.0f);
        glVertexAttrib4fv(AGVertexAttribColor, (const float *) &AGStyle::foregroundColor());
        drawLineLoop(box, 4);
    }
    
    void touchDown(const AGTouchInfo &t) override
    {
        UITouch *touch = t.platformTouchInfo;
        GLvertex2f pos = (t.position-position()).xy();
        if(touch.type == UITouchTypeDirect)
        {
            // x/y
            bool forceTouch = touch.view.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable;
            float force = 0;
            if(forceTouch)
                force = touch.force/touch.maximumPossibleForce;
            m_node->_pushData(&pos.x, &pos.y, forceTouch ? &force : NULL, NULL, NULL);
        }
        else if(touch.type == UITouchTypeStylus)
        {
            float force = touch.force/touch.maximumPossibleForce;
            float tilt = touch.altitudeAngle;
            float rot = [touch azimuthAngleInView:nil];
            m_node->_pushData(&pos.x, &pos.y, &force, &tilt, &rot);
        }
    }
    
    void touchMove(const AGTouchInfo &t) override
    {
        UITouch *touch = t.platformTouchInfo;
        GLvertex2f pos = (t.position-position()).xy();
        if(touch.type == UITouchTypeDirect)
        {
            // x/y
            bool forceTouch = touch.view.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable;
            float force = 0;
            if(forceTouch)
                force = touch.force/touch.maximumPossibleForce;
            m_node->_pushData(&pos.x, &pos.y, forceTouch ? &force : NULL, NULL, NULL);
        }
        else if(touch.type == UITouchTypeStylus)
        {
            float force = touch.force/touch.maximumPossibleForce;
            float tilt = touch.altitudeAngle;
            float rot = [touch azimuthAngleInView:nil];
            m_node->_pushData(&pos.x, &pos.y, &force, &tilt, &rot);
        }
    }
    
    void touchUp(const AGTouchInfo &t) override
    {
        UITouch *touch = t.platformTouchInfo;
        GLvertex2f pos = (t.position-position()).xy();
        if(touch.type == UITouchTypeDirect)
        {
            // x/y
            bool forceTouch = touch.view.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable;
            float force = 0;
            if(forceTouch)
                force = touch.force/touch.maximumPossibleForce;
            m_node->_pushData(&pos.x, &pos.y, forceTouch ? &force : NULL, NULL, NULL);
        }
        else if(touch.type == UITouchTypeStylus)
        {
            float force = touch.force/touch.maximumPossibleForce;
            float tilt = touch.altitudeAngle;
            float rot = [touch azimuthAngleInView:nil];
            m_node->_pushData(&pos.x, &pos.y, &force, &tilt, &rot);
        }
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
};


void AGControlGestureNode::initFinal() { }

AGControlGestureNode::~AGControlGestureNode() { }

AGUINodeEditor *AGControlGestureNode::createCustomEditor()
{
    AGUINodeEditor *editor = new AGControlGestureNodeEditor(this);
    editor->init();
    
    return editor;
}

void AGControlGestureNode::_pushData(AGFloat *x, AGFloat *y, AGFloat *pressure, AGFloat *tilt, AGFloat *rotation)
{
    if(x)
        pushControl(0, *x);
    if(y)
        pushControl(1, *y);
    if(pressure)
        pushControl(2, *pressure);
    if(tilt)
        pushControl(3, *tilt);
    if(rotation)
        pushControl(4, *rotation);
}
