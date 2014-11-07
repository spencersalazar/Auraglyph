//
//  AGAboutBox.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/5/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGAboutBox__
#define __Auragraph__AGAboutBox__


#include "Geometry.h"
#include "Animation.h"
#include "AGRenderObject.h"
#include "AGAudioNode.h"
#include "AGUserInterface.h"
#include "TexFont.h"

class AGAboutBox : public AGInteractiveObject
{
public:
    AGAboutBox(const GLvertex3f &pos);
    ~AGAboutBox();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t);

    virtual void renderOut();
    virtual bool finishedRenderingOut();
    
private:

    GLvertex3f m_geo[4];
    float m_radius;
    GLuint m_geoSize;
    
    GLvertex3f m_pos;
    lincurvef m_xScale;
    lincurvef m_yScale;
    
    GLKMatrix4 m_projection;
    GLKMatrix4 m_modelView;
    
    bool m_done;
    
    vector<string> m_lines;
    
protected:
    virtual GLvrectf effectiveBounds();
};

#endif /* defined(__Auragraph__AGAboutBox__) */
