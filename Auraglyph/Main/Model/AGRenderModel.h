//
//  AGRenderModel.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 12/29/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include "Geometry.h"
#include "Matrix.h"
#include "Animation.h"
#include "AGInteractiveObject.h"
#include "AGModalDialog.h"

#include <CoreGraphics/CGGeometry.h>

class AGDashboard;
class AGTutorial;

/** Rendering model (things that are drawn to screen)
 */
class AGRenderModel
{
public:
    Matrix4 modelView;
    Matrix4 fixedModelView;
    Matrix4 projection;
    
    float t = 0;
    GLvertex3f camera;
    slewf cameraZ = slewf(0.4, 0);
    
    AGInteractiveObjectList dashboard;
    AGInteractiveObjectList objects;
    AGInteractiveObjectList fadingOut;
    
    AGDashboard *uiDashboard = nullptr;
    AGModalOverlay modalOverlay;
    AGTutorial *currentTutorial = nullptr;
    
    void setScreenBounds(CGRect bounds);
    
    void update(float dt);
    void updateMatrices();
    
    GLvertex3f screenToWorld(CGPoint p);
    GLvertex3f screenToFixed(CGPoint p);
    
private:
    CGRect m_screenBounds;
};


