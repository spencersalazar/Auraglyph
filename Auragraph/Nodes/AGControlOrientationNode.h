//
//  AGControlOrientationNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/12/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGControlOrientationNode_hpp
#define AGControlOrientationNode_hpp

#include "AGControlNode.h"
#include "AGTimer.h"

#ifdef __OBJC__
@class CMMotionManager;
#else
typedef void CMMotionManager;
#endif


//------------------------------------------------------------------------------
// ### AGControlOrientationNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlOrientationNode

class AGControlOrientationNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_OUTPUT,
        PARAM_READ,
        PARAM_RATE,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlOrientationNode>
    {
    public:
        string _type() const override { return "Orientation"; };
        string _name() const override { return "Orientation"; };
        string _description() const override { return "Outputs Euler angles (rotation about X, Y, and Z axes) corresponding to device orientation. X and Y rotation are measured from +/-π; Z rotation is from 0 to π."; };

        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_READ, "read", .doc = "Triggers sensor reading and output." }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return {
                { PARAM_RATE, "rate", 60, 0, 100, AGPortInfo::LIN, .doc = "Rate at which to read sensors." },
            };
        };

        vector<AGPortInfo> _outputPortInfo() const override
        {
            return {
                { PARAM_OUTPUT, "output", .doc = "Output." },
            };
        };

        vector<GLvertex3f> _iconGeo() const override;
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGControlNode::AGControlNode;
    
    void initFinal() override;
    
    ~AGControlOrientationNode();
    
    void editPortValueChanged(int paramId) override;
    
    void receiveControl(int port, const AGControl &control) override;
    
    virtual int numOutputPorts() const override { return 3; }
    
private:
    CMMotionManager *m_manager;
    AGTimer m_timer;
    
    void _pushData();
};



#endif /* AGControlOrientationNode_hpp */
