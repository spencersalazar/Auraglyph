//
//  AGRenderModel.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 12/29/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGRenderModel.h"

void AGRenderModel::setScreenBounds(CGRect bounds)
{
    m_screenBounds = bounds;
    updateMatrices();
    
    modalOverlay.setScreenSize(GLvertex2f(m_screenBounds.size.width,
                                          m_screenBounds.size.height));
}

void AGRenderModel::update(float dt)
{
    t += dt;
    
    cameraZ.interp();
    
    updateMatrices();
}

void AGRenderModel::updateMatrices()
{
    GLKMatrix4 projectionMatrix;
    projectionMatrix = GLKMatrix4MakeFrustum(-m_screenBounds.size.width/2, m_screenBounds.size.width/2,
                                             -m_screenBounds.size.height/2, m_screenBounds.size.height/2,
                                             10.0f, 10000.0f);
    
    fixedModelView = GLKMatrix4MakeTranslation(0, 0, -10.1f);
    
    dbgprint_off("cameraZ: %f\n", (float) cameraZ);
    
    float cameraScale = 1.0;
    if(cameraZ > 0)
        cameraZ.reset(0);
    if(cameraZ < -160)
        cameraZ.reset(-160);
    if(cameraZ <= 0)
        camera.z = -0.1-(-1+powf(2, -cameraZ*0.045));
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4Translate(fixedModelView, camera.x, camera.y, camera.z);
    if(cameraScale > 1.0f)
        baseModelViewMatrix = GLKMatrix4Scale(baseModelViewMatrix, cameraScale, cameraScale, 1.0f);
    
    // Compute the model view matrix for the object rendered with GLKit
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    modelView = modelViewMatrix;
    projection = projectionMatrix;
    
    AGRenderObject::setProjectionMatrix(projection);
    AGRenderObject::setGlobalModelViewMatrix(modelView);
    AGRenderObject::setFixedModelViewMatrix(fixedModelView);
    AGRenderObject::setCameraMatrix(GLKMatrix4MakeTranslation(camera.x, camera.y, camera.z));
}

