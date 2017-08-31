//
//  AGDocNodeList.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/24/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGDocNodeList.h"
#include "AGAudioNode.h"
#include "AGGenericShader.h"
#include "AGStyle.h"

AGDocNodeList::AGDocNodeList()
{
    m_size = GLvertex2f(300, 400);
    addTouchOutsideListener(this);
}

AGDocNodeList::~AGDocNodeList()
{
    removeTouchOutsideListener(this);
}

GLKMatrix4 AGDocNodeList::localTransform()
{
    GLKMatrix4 local = GLKMatrix4MakeTranslation(m_pos.x, m_pos.y, m_pos.z);
    local = GLKMatrix4Multiply(local, m_squeeze.matrix());
    return local;
}

void AGDocNodeList::update(float t, float dt)
{
    m_squeeze.update(t, dt);
    AGInteractiveObject::update(t, dt);
    
    m_renderState.modelview = GLKMatrix4Multiply(AGRenderObject::fixedModelViewMatrix(), localTransform());
    m_renderState.projection = AGRenderObject::projectionMatrix();
}

void AGDocNodeList::render()
{
    GLKMatrix4 modelview = m_renderState.modelview;
    
    AGGenericShader &shader = AGGenericShader::instance();
    shader.setModelViewMatrix(modelview);
    shader.setProjectionMatrix(m_renderState.projection);
    
    // render background
    AGStyle::frameBackgroundColor().set();
    drawTriangleFan((GLvertex2f[]) {
        { -m_size.x, -m_size.y },
        {  m_size.x, -m_size.y },
        {  m_size.x,  m_size.y },
        { -m_size.x,  m_size.y },
    }, 4);
    
    // render frame
    AGStyle::foregroundColor().set();
    drawLineLoop((GLvertex2f[]) {
        { -m_size.x, -m_size.y },
        {  m_size.x, -m_size.y },
        {  m_size.x,  m_size.y },
        { -m_size.x,  m_size.y },
    }, 4);

    const std::vector<const AGNodeManifest *> &audioNodeTypes = AGNodeManager::audioNodeManager().nodeTypes();
    int num = audioNodeTypes.size();
    for(int i = 0; i < num; i++)
    {
//        const AGNodeManifest *node = audioNodeTypes[i];
//        
//        AGGenericShader &shader = AGGenericShader::instance();
//        
//        GLKMatrix4 modelview = m_renderState.modelview;
////        modelview = GLKMatrix4Translate(modelview, <#float tx#>, <#float ty#>, <#float tz#>)
//        
//        shader.setModelViewMatrix(modelview);
//        shader.setProjectionMatrix(m_renderState.projection);
//        
//        node->renderIcon();
//        
//        for(auto param : node->editPortInfo())
//            ;
//        
//        for(auto port : node->inputPortInfo())
//            ;
    }
}

GLvrectf AGDocNodeList::effectiveBounds()
{
    return GLvrectf(m_pos-m_size/2, m_pos+m_size/2);
}

void AGDocNodeList::renderOut()
{
    m_squeeze.close();
}

bool AGDocNodeList::finishedRenderingOut()
{
    return m_squeeze.finishedClosing();
}

void AGDocNodeList::touchDown(const AGTouchInfo &t)
{
    
}

void AGDocNodeList::touchMove(const AGTouchInfo &t)
{
    
}

void AGDocNodeList::touchUp(const AGTouchInfo &t)
{
    
}

void AGDocNodeList::touchOutside()
{
    removeFromTopLevel();
}

