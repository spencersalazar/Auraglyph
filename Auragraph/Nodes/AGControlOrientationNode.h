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

#include "AGStyle.h"
#import <CoreMotion/CoreMotion.h>

/*** TODO: move into ***/

//------------------------------------------------------------------------------
// ### AGControlMultiplyNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlMultiplyNode

class AGControlOrientationNode : public AGControlNode
{
public:
    
    enum Param
    {
        PARAM_READ,
    };
    
    class Manifest : public AGStandardNodeManifest<AGControlOrientationNode>
    {
    public:
        string _type() const override { return "Orientation"; };
        string _name() const override { return "Orientation"; };
        
        vector<AGPortInfo> _inputPortInfo() const override
        {
            return {
                { PARAM_READ, "read", true, true }
            };
        };
        
        vector<AGPortInfo> _editPortInfo() const override
        {
            return { };
        };
        
        vector<GLvertex3f> _iconGeo() const override
        {
            float radius = 0.005*AGStyle::oldGlobalScale;
            float squash = 1.0f/3.0f;
            
            // icon
            int ptsPerCircle = 32;
            vector<GLvertex3f> iconGeo(ptsPerCircle*3*2);
            
            // regular circle around center
            for(int i = 0; i < ptsPerCircle; i++)
            {
                float theta0 = ((float)i)/(ptsPerCircle)*2.0f*M_PI;
                float theta1 = ((float)i+1)/(ptsPerCircle)*2.0f*M_PI;
                iconGeo[i*2+0] = GLvertex3f(radius*cosf(theta0), radius*sinf(theta0), 0);
                iconGeo[i*2+1] = GLvertex3f(radius*cosf(theta1), radius*sinf(theta1), 0);
            }
            
            // circle around center squashed on x-axis
            for(int i = 0; i < ptsPerCircle; i++)
            {
                float theta0 = ((float)i)/(ptsPerCircle)*2.0f*M_PI;
                float theta1 = ((float)i+1)/(ptsPerCircle)*2.0f*M_PI;
                iconGeo[ptsPerCircle*2+i*2+0] = GLvertex3f(radius*squash*cosf(theta0), radius*sinf(theta0), 0);
                iconGeo[ptsPerCircle*2+i*2+1] = GLvertex3f(radius*squash*cosf(theta1), radius*sinf(theta1), 0);
            }
            
            // circle around center squashed on y-axis
            for(int i = 0; i < ptsPerCircle; i++)
            {
                float theta0 = ((float)i)/(ptsPerCircle)*2.0f*M_PI;
                float theta1 = ((float)i+1)/(ptsPerCircle)*2.0f*M_PI;
                iconGeo[ptsPerCircle*4+i*2+0] = GLvertex3f(radius*cosf(theta0), radius*squash*sinf(theta0), 0);
                iconGeo[ptsPerCircle*4+i*2+1] = GLvertex3f(radius*cosf(theta1), radius*squash*sinf(theta1), 0);
            }
            
            return iconGeo;
        };
        
        GLuint _iconGeoType() const override { return GL_LINES; };
    };
    
    using AGControlNode::AGControlNode;
    
    void initFinal() override
    {
        m_manager = [[CMMotionManager alloc] init];
        [m_manager startDeviceMotionUpdates];
    }
    
    ~AGControlOrientationNode()
    {
        [m_manager stopDeviceMotionUpdates];
        m_manager = nil;
    }
    
    void receiveControl(int port, const AGControl &control) override
    {
        AGControl roll = AGControl((float) m_manager.deviceMotion.attitude.roll);
        AGControl pitch = AGControl((float) m_manager.deviceMotion.attitude.pitch);
        AGControl yaw = AGControl((float) m_manager.deviceMotion.attitude.yaw);
        
        dbgprint("%s: push %f\n", this->title().c_str(), roll.getFloat());
        dbgprint("%s: push %f\n", this->title().c_str(), pitch.getFloat());
        dbgprint("%s: push %f\n", this->title().c_str(), yaw.getFloat());
        
        pushControl(0, roll);
        pushControl(1, pitch);
        pushControl(2, yaw);
    }
    
    virtual int numOutputPorts() const override { return 3; }
    
private:
    CMMotionManager *m_manager;
};



#endif /* AGControlOrientationNode_hpp */
