//
//  AGInterAppAudioManager.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 5/28/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include <AudioUnit/AudioUnit.h>

#include <string>
#include <functional>


class AGInterAppAudioManager final
{
public:
    AGInterAppAudioManager(AudioUnit au, std::function<void (bool enabled)> onInterAppAudioEnable);
    
    void publishInterAppAudioUnit(OSType type, OSType manufacturer, const std::string &name);
    
    bool isInterAppAudio();
    
    void launchInterAppAudioHost();
    
    void onInterAppAudioEnabled();
    
private:
    AudioUnit m_au;
    std::function<void (bool enabled)> m_onInterAppAudioEnable;
};
