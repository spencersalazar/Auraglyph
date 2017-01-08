//
//  AGFileManager.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 1/8/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include <string>

using namespace std;

class AGFileManager
{
public:
    static AGFileManager &instance();
    
    const string &soundfileDirectory();
    
private:
    AGFileManager();
    ~AGFileManager();
    
    string m_soundfileDirectory;
};
