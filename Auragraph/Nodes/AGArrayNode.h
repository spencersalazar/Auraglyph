//
//  AGArrayNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGArrayNode__
#define __Auragraph__AGArrayNode__

#include "AGControlNode.h"
#include "AGControl.h"
#include <list>

class AGUIArrayEditor;

class AGControlArrayNode : public AGControlNode
{
    friend class AGUIArrayEditor;
    
public:
    
    class Manifest : public AGStandardNodeManifest<AGControlArrayNode>
    {
    public:
        string _type() const override;
        string _name() const override;
        vector<AGPortInfo> _inputPortInfo() const override;
        vector<AGPortInfo> _editPortInfo() const override;
        vector<GLvertex3f> _iconGeo() const override;
        GLuint _iconGeoType() const override;
    };
    
    using AGControlNode::AGControlNode;
    
    void setDefaultPortValues() override;
    
    virtual int numOutputPorts() const override { return 1; }
    virtual void setEditPortValue(int port, float value) override;
    virtual void getEditPortValue(int port, float &value) const override;
    
    virtual AGUINodeEditor *createCustomEditor() override;
    
    virtual void receiveControl(int port, const AGControl &control) override;
    
private:
    static AGNodeInfo *s_nodeInfo;
    
    sampletime m_lastTime;
    
    list<float> m_items;
    list<float>::iterator m_position;
};


#endif /* defined(__Auragraph__AGArrayNode__) */
