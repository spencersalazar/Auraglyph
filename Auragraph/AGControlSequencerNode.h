//
//  AGControlSequencerNode.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 3/12/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGControlSequencerNode_hpp
#define AGControlSequencerNode_hpp

#import "AGControlNode.h"
#import <list>
#import <vector>

class AGControlSequencerNode : public AGControlNode
{
public:
    static void initialize();
    
    AGControlSequencerNode(const GLvertex3f &pos);
    AGControlSequencerNode(const AGDocument::Node &docNode);
    ~AGControlSequencerNode();
    
    virtual int numOutputPorts() const { return 1; }
    virtual void setEditPortValue(int port, float value);
    virtual void getEditPortValue(int port, float &value) const;
    
    virtual void update(float t, float dt);
    virtual void render();
    
    virtual AGUINodeEditor *createCustomEditor();
    
    static void renderIcon();
    static AGNode *create(const GLvertex3f &pos);
    static AGNodeInfo *nodeInfo() { return s_nodeInfo; }
    
    int currentStep();
    int numSequences();
    int numSteps();
    
private:
    static AGNodeInfo *s_nodeInfo;
    
    AGTimer *m_timer;
    
    AGFloatControl m_control;
    float m_bpm;
    
    int m_pos;
    int m_numSteps;
    std::vector<std::vector<float> > m_sequence;
    
    void updateStep();
};


#endif /* AGControlSequencerNode_hpp */
