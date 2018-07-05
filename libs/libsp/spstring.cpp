//
//  spstring.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 6/27/18.
//  Copyright © 2018 Spencer Salazar. All rights reserved.
//

#include "spstring.h"
#include <sstream>

std::vector<std::string> split(const std::string &stringToSplit, char splitBy)
{
    std::vector<std::string> substrings;
    
    std::stringstream ss(stringToSplit);
    std::string item;
    while (std::getline(ss, item, splitBy)) {
        substrings.push_back(item);
    }

    return substrings;
}
