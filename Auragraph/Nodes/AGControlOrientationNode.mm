//
//  AGControlOrientationNode.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/12/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGControlOrientationNode.h"

#include "AGStyle.h"
#import <CoreMotion/CoreMotion.h>


//------------------------------------------------------------------------------
// ### AGControlOrientationNode ###
//------------------------------------------------------------------------------
#pragma mark - AGControlOrientationNode

vector<GLvertex3f> AGControlOrientationNode::Manifest::_iconGeo() const
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

void AGControlOrientationNode::initFinal()
{
    m_manager = [[CMMotionManager alloc] init];
    [m_manager startDeviceMotionUpdates];
    
    m_timer.setInterval(1.0f/param(PARAM_RATE));
    m_timer.setAction([this](AGTimer *timer){
        if(inbound().size() == 0)
            _pushData();
    });
}

AGControlOrientationNode::~AGControlOrientationNode()
{
    [m_manager stopDeviceMotionUpdates];
    m_manager = nil;
}

void AGControlOrientationNode::editPortValueChanged(int paramId)
{
    switch(paramId)
    {
        case PARAM_RATE:
            m_timer.setInterval(1.0f/param(PARAM_RATE));
            break;
    }
}

void AGControlOrientationNode::receiveControl(int port, const AGControl &control)
{
    _pushData();
}

void AGControlOrientationNode::_pushData()
{
    AGControl roll = AGControl((float) m_manager.deviceMotion.attitude.roll);
    AGControl pitch = AGControl((float) m_manager.deviceMotion.attitude.pitch);
    AGControl yaw = AGControl((float) m_manager.deviceMotion.attitude.yaw);
    
    pushControl(0, roll);
    pushControl(1, pitch);
    pushControl(2, yaw);
}

