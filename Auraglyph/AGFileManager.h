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

class AGFile
{
public:
    enum Source
    {
        USER,
        EXAMPLE,
    };
    
    static AGFile UserFile(const std::string &filename) { return { filename, USER }; }
    static AGFile ExampleFile(const std::string &filename) { return { filename, EXAMPLE }; }

    std::string m_filename;
    Source m_source;
    
    bool operator==(const AGFile &other)
    {
        return other.m_filename == m_filename && other.m_source == m_source;
    }
};

class AGFileManager
{
public:
    static AGFileManager &instance();
    
    const string &userDataDirectory();
    const string &soundfileDirectory();
    const string &documentDirectory();
    const string &examplesDirectory();

    bool fileHasExtension(const string &filepathOrName, const string &extension);
    bool fileExists(const AGFile &file);
    vector<string> listDirectory(const string &directory);
    
    std::string getFullPath(const AGFile& file);
    
private:
    AGFileManager();
    ~AGFileManager();
    
    string m_soundfileDirectory;
    string m_userDataDirectory;
    string m_documentDirectory;
    string m_examplesDirectory;
};
