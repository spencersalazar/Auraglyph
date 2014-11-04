//
//  AGArrayNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGArrayNode__
#define __Auragraph__AGArrayNode__

#include "AGNode.h"
#include "AGControl.h"

class AGControlArrayNode : public AGControlNode
{
public:
    static void initialize();
    
    AGControlArrayNode(const GLvertex3f &pos);
    
    virtual int numOutputPorts() const { return 1; }
    virtual void setEditPortValue(int port, float value);
    virtual void getEditPortValue(int port, float &value) const;
    
    virtual AGControl *renderControl(sampletime t);
    
private:
    static AGNodeInfo *s_nodeInfo;
    
    AGFloatControl m_control;
    sampletime m_lastTime;
};


#endif /* defined(__Auragraph__AGArrayNode__) */
