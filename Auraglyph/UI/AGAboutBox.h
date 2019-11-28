//
//  AGAboutBox.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/5/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGAboutBox__
#define __Auragraph__AGAboutBox__


#include "AGInteractiveObject.h"
#include "AGAudioNode.h"
#include "AGUserInterface.h"
#include "AGStyle.h"

#include "Geometry.h"

class AGAboutBox : public AGInteractiveObject
{
public:
    AGAboutBox(const GLvertex3f &pos);
    ~AGAboutBox();
    
    virtual void update(float t, float dt) override;
    virtual void render() override;
    
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t) override;

    virtual void renderOut() override;
    virtual bool finishedRenderingOut() const override;
    
    bool renderFixed() override { return true; }
    
    virtual GLvrectf effectiveBounds() override;
    
    virtual GLKMatrix4 localTransform() override;

private:

    GLvertex3f m_geo[4];
    float m_radius;
    GLuint m_geoSize;
    
    AGSqueezeAnimation m_squeeze;
    
    GLKMatrix4 m_projection;
    GLKMatrix4 m_modelView;
    
    bool m_done;
    
    vector<string> m_lines;
};

#endif /* defined(__Auragraph__AGAboutBox__) */
