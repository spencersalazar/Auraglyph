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

std::string pathJoin(const std::vector<std::string> &strings)
{
    return join(strings, '/');
}

std::string join(const std::vector<std::string> &strings, char joinBy)
{
    std::string out;
    for (int i = 0; i < strings.size(); i++) {
        out += strings[i];
        if (i+1 < strings.size())
            out += joinBy;
    }
    return out;
}
