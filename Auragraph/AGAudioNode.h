//
//  AGAudioNode.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGAudioNode__
#define __Auragraph__AGAudioNode__

#import "AGNode.h"

#import "Geometry.h"
#import "ShaderHelper.h"

#import <GLKit/GLKit.h>
#import <Foundation/Foundation.h>

#import <list>
#import <vector>
#import <string>

using namespace std;


class AGAudioOutputNode : public AGAudioNode
{
public:
    static void initialize();
    
    AGAudioOutputNode(GLvertex3f pos);
    AGAudioOutputNode(const AGDocument::Node &docNode);
    
    virtual int numOutputPorts() const { return 0; }
    virtual int numInputPorts() const { return 1; }
    
    virtual void renderAudio(sampletime t, float *input, float *output, int nFrames);
    
    static void renderIcon();
    static AGAudioNode *create(const GLvertex3f &pos);
    
private:
    static AGNodeInfo *s_audioNodeInfo;
};


#endif /* defined(__Auragraph__AGAudioNode__) */
