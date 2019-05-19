//
//  AGUtility.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 5/18/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include <string>
#include <functional>

namespace AGUtility {
    
    std::string getVersionString();
    
    void after(float timeInSeconds, std::function<void ()> func);
}

