//
//  AGDocNodeList.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/24/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include "AGInteractiveObject.h"
#include "AGStyle.h"

class AGDocNodeList : public AGInteractiveObject
{
public:
    AGDocNodeList();
    ~AGDocNodeList();
    
    GLKMatrix4 localTransform() override;
    void update(float t, float dt) override;
    void render() override;
    
    GLvrectf effectiveBounds() override;    
    bool renderFixed() override { return true; }
    virtual void renderOut() override;
    virtual bool finishedRenderingOut() override;
    
    virtual void touchDown(const AGTouchInfo &t) override;
    virtual void touchMove(const AGTouchInfo &t) override;
    virtual void touchUp(const AGTouchInfo &t) override;
    virtual void touchOutside() override;
    
private:
    GLvertex2f m_size;
    AGSqueezeAnimation m_squeeze;
};

