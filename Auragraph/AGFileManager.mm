//
//  AGFileManager.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 1/8/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGFileManager.h"


AGFileManager &AGFileManager::instance()
{
    static AGFileManager s_manager;
    return s_manager;
}

AGFileManager::AGFileManager()
{
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    m_soundfileDirectory = [documentPath UTF8String];
    m_userDataDirectory = [documentPath UTF8String];
}

AGFileManager::~AGFileManager()
{ }

const string &AGFileManager::soundfileDirectory()
{
    return m_soundfileDirectory;
}

const string &AGFileManager::userDataDirectory()
{
    return m_userDataDirectory;
}

vector<string> AGFileManager::listDirectory(const string &directory)
{
    vector<string> pathList;
    NSError *error = nil;
    NSArray *pathArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSString stringWithUTF8String:directory.c_str()]
                                                                             error:&error];
    for(NSString *path in pathArray)
    {
        pathList.push_back([path UTF8String]);
    }
    
    return std::move(pathList);
}
