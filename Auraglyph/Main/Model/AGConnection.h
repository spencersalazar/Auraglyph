//
//  AGConnection.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/13/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGConnection__
#define __Auragraph__AGConnection__

#include "AGInteractiveObject.h"
#include "AGUserInterface.h"
#include "AGDocument.h"
#include "AGControl.h"

#include "Geometry.h"
#include "Animation.h"
#include "gfx.h"

#include <string>
#include <vector>
#include <list>

using namespace std;

class AGNode;

enum AGRate
{
    RATE_NULL,
    RATE_CONTROL,
    RATE_AUDIO,
};

class AGConnection : public AGInteractiveObject
{
public:
    
    static AGConnection *connect(AGNode *src, int srcPort, AGNode *dst, int dstPort);
    static AGConnection *connect(const AGDocument::Connection &docConnection);
    
    AGConnection(AGNode * src, int srcPort, AGNode * dst, int dstPort, const string &uuid = "");
    ~AGConnection();
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual void touchDown(const GLvertex3f &t);
    virtual void touchMove(const GLvertex3f &t);
    virtual void touchUp(const GLvertex3f &t);
    
    virtual AGInteractiveObject *hitTest(const GLvertex3f &t);
    
    const string &uuid() const { return m_uuid; }
    AGNode * src() const { return m_src; }
    AGNode * dst() const { return m_dst; }
    int dstPort() const { return m_dstPort; }
    int srcPort() const { return m_srcPort; }
    
    AGRate rate() { return m_rate; }
    
    void controlActivate(const AGControl &ctrl);
    
    void renderOut();
    
    AGDocument::Connection serialize();
    
private:
    
    static bool s_init;
    static GLuint s_flareTex;
    
    const string m_uuid;
    
    GLvertex3f m_geo[3];
    GLcolor4f m_color;
    GLuint m_geoSize;
    
    AGNode * const m_src;
    AGNode * const m_dst;
    const int m_dstPort;
    const int m_srcPort;
    
    GLvertex3f m_outTerminal;
    GLvertex3f m_inTerminal;
    
    bool m_hit;
    bool m_stretch;
    bool m_break;
    slew<GLvertex3f> m_stretchPoint;
    
    bool m_active;
    AGControl m_activation;
//    powcurvef m_alpha;
    
    const AGRate m_rate;
    
    list<float> m_flares;
    GLvertex3f m_flareGeo[4];
    GLvertex2f m_flareUV[4];
    
    slew<float> m_controlVisScale;
    
    static void initalize();
    
    void updatePath();
};



#endif /* defined(__Auragraph__AGConnection__) */
