//
//  AGFormulaNode.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 11/3/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGFormulaNode.h"

AGNodeInfo *AGAudioFormulaNode::s_audioNodeInfo = NULL;

void AGAudioFormulaNode::initialize()
{
    
}

AGAudioFormulaNode::AGAudioFormulaNode(GLvertex3f pos)
{
    
}

int AGAudioFormulaNode::numOutputPorts() const
{
    return 0;
}

int AGAudioFormulaNode::numInputPorts() const
{
    return 0;
}

void AGAudioFormulaNode::renderAudio(sampletime t, float *input, float *output, int nFrames)
{
    
}

void AGAudioFormulaNode::renderIcon()
{
    
}

AGAudioNode *AGAudioFormulaNode::create(const GLvertex3f &pos)
{
    return NULL;
}

