//
//  AGConnection.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/13/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGConnection__
#define __Auragraph__AGConnection__

#include "AGRenderObject.h"
#include "AGUserInterface.h"

#include "Geometry.h"
#include "Animation.h"

#include <GLKit/GLKit.h>

#include <string>
#include <vector>
#include <list>

using namespace std;

class AGNode;

enum AGRate
{
    RATE_CONTROL,
    RATE_AUDIO,
};

struct AGPortInfo
{
    string name;
    bool canConnect; // can create connection btw this port and another port
    bool canEdit; // should this port appear in the node's editor window
    
    // TODO: min, max, units label, rate, etc.
};

struct AGNodeInfo
{
    AGNodeInfo() : iconGeo(NULL), iconGeoSize(0), iconGeoType(GL_LINE_STRIP) { }
    
    GLvertex3f *iconGeo;
    GLuint iconGeoSize;
    GLuint iconGeoType;
    
    vector<AGPortInfo> inputPortInfo;
    vector<AGPortInfo> editPortInfo;
};

typedef long long sampletime;


class AGConnection : public AGInteractiveObject
{
public:
    
    AGConnection(AGNode * src, AGNode * dst, int dstPort);
    ~AGConnection();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t);
    
    AGNode * src() const { return m_src; }
    AGNode * dst() const { return m_dst; }
    int dstPort() const { return m_dstPort; }
    
    AGRate rate() { return m_rate; }
    
    void controlActivate();
    
    void fadeOutAndRemove();
    
private:
    
    static bool s_init;
    static GLuint s_flareTex;
    
    GLvertex3f m_geo[3];
    GLcolor4f m_color;
    GLuint m_geoSize;
    
    AGNode * const m_src;
    AGNode * const m_dst;
    const int m_dstPort;
    
    GLvertex3f m_outTerminal;
    GLvertex3f m_inTerminal;
    
    bool m_hit;
    bool m_stretch;
    bool m_break;
    slew<GLvertex3f> m_stretchPoint;
    
    bool m_active;
    powcurvef m_alpha;
    
    const AGRate m_rate;
    
    list<float> m_flares;
    GLvertex3f m_flareGeo[4];
    GLvertex2f m_flareUV[4];
    
    slew<float> m_controlVisScale;
    
    static void initalize();
    
    void updatePath();
};



#endif /* defined(__Auragraph__AGConnection__) */
