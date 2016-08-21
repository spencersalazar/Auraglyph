//
//  AGFormulaNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGFormulaNode__
#define __Auragraph__AGFormulaNode__

#include "AGAudioNode.h"

using namespace std;


class AGAudioFormulaNode : public AGAudioNode
{
public:
    static void initialize();
    
    AGAudioFormulaNode(GLvertex3f pos);
    
    virtual int numOutputPorts() const;
    virtual int numInputPorts() const;
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames);
    
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);
    
private:
    static AGNodeInfo *s_audioNodeInfo;
};



#endif /* defined(__Auragraph__AGFormulaNode__) */
