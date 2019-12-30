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
    /* PROJECTION MATRIX */
    projection = Matrix4::makeFrustum(-m_screenBounds.size.width/2, m_screenBounds.size.width/2,
                                      -m_screenBounds.size.height/2, m_screenBounds.size.height/2,
                                      10.0f, 10000.0f);
    
    /* FIXED MODEL/VIEW MATRIX (e.g does not move with camera) */
    fixedModelView = Matrix4::makeTranslation(0, 0, -10.1f);
        
    // camera
    dbgprint_off("cameraZ: %f\n", (float) cameraZ);
    
    float cameraScale = 1.0;
    if(cameraZ > 0)
        cameraZ.reset(0);
    if(cameraZ < -160)
        cameraZ.reset(-160);
    if(cameraZ <= 0)
        camera.z = -0.1-(-1+powf(2, -cameraZ*0.045));
    
    /* MODEL/VIEW MATRIX */
    modelView = fixedModelView.translate(camera.x, camera.y, camera.z);
    if(cameraScale > 1.0f)
        modelView.scaleInPlace(cameraScale, cameraScale, 1.0f);
    
    // update render object shared variables
    AGRenderObject::setProjectionMatrix(projection);
    AGRenderObject::setGlobalModelViewMatrix(modelView);
    AGRenderObject::setFixedModelViewMatrix(fixedModelView);
    AGRenderObject::setCameraMatrix(Matrix4::makeTranslation(camera.x, camera.y, camera.z));
}

