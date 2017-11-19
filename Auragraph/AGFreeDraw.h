//
//  AGFreeDraw.h
//  Auragraph
//
//  Created by Andrew Piepenbrink on 6/29/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#ifndef AGFreeDraw_h
#define AGFreeDraw_h

#include "AGDocument.h"
#include "AGUserInterface.h"

//------------------------------------------------------------------------------
// ### AGFreeDraw ###
//------------------------------------------------------------------------------
#pragma mark - AGFreeDraw

class AGFreeDraw : public AGUIObject
{
public:
    AGFreeDraw(GLvertex3f *points, unsigned long nPoints);
    AGFreeDraw(const AGDocument::Freedraw &docFreedraw);
    ~AGFreeDraw();
    
    const string &uuid() { return m_uuid; }
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    const vector<GLvertex3f> &points();
    virtual AGUIObject *hitTest(const GLvertex3f &t);
    
    virtual AGDocument::Freedraw serialize();
    
private:
    const string m_uuid;
    
    vector<GLvertex3f> m_points;
    
    bool m_touchDown;
    GLvertex3f m_touchLast;
    
    bool m_active;
    //    powcurvef m_alpha;
    
    // debug
    int m_touchPoint0;
};

#endif /* AGFreeDraw_h */
