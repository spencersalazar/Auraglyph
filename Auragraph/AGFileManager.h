//
//  AGFileManager.hpp
//  Auragraph
//
//  Created by Spencer Salazar on 1/8/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include <string>
#include <vector>

using namespace std;

class AGFileManager
{
public:
    static AGFileManager &instance();
    
    const string &userDataDirectory();
    const string &soundfileDirectory();
    const string &documentDirectory();

    bool fileHasExtension(const string &filepathOrName, const string &extension);
    bool filenameExists(const string &filename);
    vector<string> listDirectory(const string &directory);
    
private:
    AGFileManager();
    ~AGFileManager();
    
    string m_soundfileDirectory;
    string m_userDataDirectory;
    string m_documentDirectory;
};
