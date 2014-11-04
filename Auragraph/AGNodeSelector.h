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

class AGUIMetaNodeSelector
{
public:
    static AGUIMetaNodeSelector *audioNodeSelector(const GLvertex3f &pos);
    
    AGUIMetaNodeSelector(const GLvertex3f &pos) { }
    virtual ~AGUIMetaNodeSelector() { }
    
    virtual void update(float t, float dt) = 0;
    virtual void render() = 0;
    
    virtual void touchDown(const GLvertex3f &t) = 0;
    virtual void touchMove(const GLvertex3f &t) = 0;
    virtual void touchUp(const GLvertex3f &t) = 0;
    
    virtual AGNode *createNode() = 0;
    
    virtual bool done() = 0;
};



#endif /* defined(__Auragraph__AGNodeSelector__) */
