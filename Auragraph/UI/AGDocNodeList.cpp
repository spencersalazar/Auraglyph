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


#define AG_DOCNODELIST_LINEHEIGHT (75.0f)
#define AG_DOCNODELIST_NUMITEMSVISIBLE (8)


AGDocNodeList::AGDocNodeList()
{
    float height = AG_DOCNODELIST_LINEHEIGHT*AG_DOCNODELIST_NUMITEMSVISIBLE;
    m_size = GLvertex2f(500, height);
    
    const std::vector<const AGNodeManifest *> &audioNodeTypes = AGNodeManager::audioNodeManager().nodeTypes();
    int numItems = audioNodeTypes.size();
    m_scroller.setScrollRange(0, max(0.0f, (numItems-AG_DOCNODELIST_NUMITEMSVISIBLE)*AG_DOCNODELIST_LINEHEIGHT));
    
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
    m_scroller.update(t, dt);
    
    AGInteractiveObject::update(t, dt);
    
    m_renderState.modelview = GLKMatrix4Multiply(AGRenderObject::fixedModelViewMatrix(), localTransform());
    m_renderState.projection = AGRenderObject::projectionMatrix();
}

void AGDocNodeList::render()
{
    AGGenericShader &shader = AGGenericShader::instance();
    shader.useProgram();
    shader.setModelViewMatrix(m_renderState.modelview);
    shader.setProjectionMatrix(m_renderState.projection);
    
    // render background
    AGStyle::frameBackgroundColor().set();
    drawTriangleFan((GLvertex2f[]) {
        { -m_size.x/2, -m_size.y/2 },
        {  m_size.x/2, -m_size.y/2 },
        {  m_size.x/2,  m_size.y/2 },
        { -m_size.x/2,  m_size.y/2 },
    }, 4);
    
    // render frame
    AGStyle::foregroundColor().set();
    drawLineLoop((GLvertex2f[]) {
        { -m_size.x/2, -m_size.y/2 },
        {  m_size.x/2, -m_size.y/2 },
        {  m_size.x/2,  m_size.y/2 },
        { -m_size.x/2,  m_size.y/2 },
    }, 4);

    float lineHeight = AG_DOCNODELIST_LINEHEIGHT;
    TexFont *text = AGStyle::standardFont64();
    float textScale = G_RATIO-1;
    float textYOffset = -(text->ascender()/2+text->descender())*textScale;
    
    AGClipShader &clipShader = AGClipShader::instance();
    
    const std::vector<const AGNodeManifest *> &audioNodeTypes = AGNodeManager::audioNodeManager().nodeTypes();
    int num = audioNodeTypes.size();
    for(int i = 0; i < num; i++)
    {
        const AGNodeManifest *node = audioNodeTypes[i];
        
        float y = m_size.y/2-(i+1)*lineHeight+lineHeight/2;
        GLKMatrix4 localMatrix = GLKMatrix4MakeTranslation(-0.75f*m_size.x/2, y, 0);
        localMatrix = m_scroller.apply(localMatrix);
        GLKMatrix4 modelview = GLKMatrix4Multiply(m_renderState.modelview, localMatrix);
        
        clipShader.useProgram();
        clipShader.setModelViewMatrix(modelview);
        clipShader.setProjectionMatrix(m_renderState.projection);
        clipShader.setLocalMatrix(localMatrix);
        clipShader.setClip(m_pos.xy()-m_size/2, m_size);
        
        AGStyle::foregroundColor().set();
        glDisableClientState(AGVertexAttribTexCoord0);
        node->renderIcon();
        
        GLKMatrix4 textmv = m_scroller.apply(m_renderState.modelview);
        textmv = GLKMatrix4Translate(textmv, -0.5f*m_size.x/2, y+textYOffset, 0);
        textmv = GLKMatrix4Scale(textmv, textScale, textScale, textScale);
        text->render(node->type(), AGStyle::foregroundColor(), textmv, m_renderState.projection);
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
    m_scroller.touchDown(t);
}

void AGDocNodeList::touchMove(const AGTouchInfo &t)
{
    m_scroller.touchMove(t);
}

void AGDocNodeList::touchUp(const AGTouchInfo &t)
{
    m_scroller.touchUp(t);
}

void AGDocNodeList::touchOutside()
{
    removeFromTopLevel();
}

