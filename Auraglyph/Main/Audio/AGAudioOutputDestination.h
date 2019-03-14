//
//  AGAudioOutputDestination.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/25/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#ifndef AGAudioOutputDestination_h
#define AGAudioOutputDestination_h

#include "AGAudioRenderer.h"

class AGAudioOutputDestination
{
public:
    virtual ~AGAudioOutputDestination() { }
    
    virtual void addOutput(AGAudioRenderer *renderer) = 0;
    virtual void removeOutput(AGAudioRenderer *renderer) = 0;
};

#endif /* AGAudioOutputSource_h */
