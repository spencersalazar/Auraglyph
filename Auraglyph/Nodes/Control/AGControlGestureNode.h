//
//  AGControlGestureNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 3/30/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGControlNode.h"

#ifdef __OBJC__
@class CMMotionManager;
#else
typedef void CMMotionManager;
#endif


class AGControlGestureNodeEditor;


//------------------------------------------------------------------------------
// ### AGControlStylusNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlGestureNode

class AGControlGestureNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_X,
        PARAM_Y,
        PARAM_PRESSURE,
        PARAM_TILT,
        PARAM_ROTATION,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlGestureNode>
    {
    public:
        string _type() const override { return "Gesture"; };
        string _name() const override { return "Gesture"; };
        string _description() const override { return "Outputs touch or stylus position, pressure, tilt, and rotation (as available)."; };
        
        vector<AGPortInfo> _inputPortInfo() const override { return { }; };
        
        vector<AGPortInfo> _editPortInfo() const override { return { }; };
        
        vector<AGPortInfo> _outputPortInfo() const override { return {
            { PARAM_X, "x", .doc = "X-position of pencil or touch within the bounding box of the node window." },
            { PARAM_Y, "y", .doc = "Y-position of pencil or touch within the bounding box of the node window." },
            { PARAM_PRESSURE, "pressure", .doc = "Pencil pressure." },
            { PARAM_TILT, "tilt", .doc = "Pencil tilt." },
            { PARAM_ROTATION, "rotation", .doc = "Pencil rotation." },
        }; };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 38;
            float w = radius*1.3, h = w*0.2, t = h*0.75, rot = -M_PI*0.7f;
            
            return {
                // pen
                rotateZ(GLvertex2f( w/2,      0), rot),
                rotateZ(GLvertex2f( w/2-t,  h/2), rot),
                rotateZ(GLvertex2f(-w/2,    h/2), rot),
                rotateZ(GLvertex2f(-w/2,   -h/2), rot),
                rotateZ(GLvertex2f( w/2-t, -h/2), rot),
                rotateZ(GLvertex2f( w/2,      0), rot),
            };
        }
        
        GLuint _iconGeoType() const override { return GL_LINE_STRIP; };
    };
    
    using AGControlNode::AGControlNode;
    
    void initFinal() override;
    
    ~AGControlGestureNode();
    
    virtual AGUINodeEditor *createCustomEditor() override;
    
    virtual int numOutputPorts() const override { return 5; }
    
private:
    void _pushData(AGFloat *x, AGFloat *y, AGFloat *pressure, AGFloat *tilt, AGFloat *rotation);
    
    friend class AGControlGestureNodeEditor;
};


