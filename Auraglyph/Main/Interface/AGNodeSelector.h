//
//  AGNodeSelector.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/4/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGNodeSelector__
#define __Auragraph__AGNodeSelector__

#include "Geometry.h"
#include "Animation.h"
#include "AGRenderObject.h"
#include "AGAudioNode.h"
#include <list>

class AGUIMetaNodeSelector : public AGInteractiveObject
{
public:
    static AGUIMetaNodeSelector *audioNodeSelector(const GLvertex3f &pos);
    static AGUIMetaNodeSelector *controlNodeSelector(const GLvertex3f &pos);
    static AGUIMetaNodeSelector *inputNodeSelector(const GLvertex3f &pos);
    static AGUIMetaNodeSelector *outputNodeSelector(const GLvertex3f &pos);
    
    static const std::list<AGUIMetaNodeSelector*>& nodeSelectors() { return s_nodeSelectors; }

    AGUIMetaNodeSelector(const GLvertex3f &pos) { }
    virtual ~AGUIMetaNodeSelector() { }
    
    virtual void update(float t, float dt) override = 0;
    virtual void render() override = 0;
    
    virtual void touchDown(const GLvertex3f &t) override = 0;
    virtual void touchMove(const GLvertex3f &t) override = 0;
    virtual void touchUp(const GLvertex3f &t) override = 0;
    
    virtual AGNode *createNode() = 0;
    
    virtual bool done() = 0;
    
    virtual void renderOut() override = 0;
    virtual bool finishedRenderingOut() const override = 0;
    
    virtual void blink(bool enable, int item = -1) = 0;
    
protected:
    static std::list<AGUIMetaNodeSelector*> s_nodeSelectors;
};



#endif /* defined(__Auragraph__AGNodeSelector__) */
