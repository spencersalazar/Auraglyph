//
//  AGFileManager.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 1/8/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGFileManager.h"
#include "NSString+STLString.h"

AGFileManager &AGFileManager::instance()
{
    static AGFileManager s_manager;
    return s_manager;
}

AGFileManager::AGFileManager()
{
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    m_resourcesDirectory = [[[NSBundle mainBundle] resourcePath] stlString];
    m_soundfileDirectory = [documentPath UTF8String];
    m_userDataDirectory = [documentPath UTF8String];
    m_documentDirectory = [documentPath UTF8String];
    m_examplesDirectory = [[[NSBundle mainBundle] pathForResource:@"examples" ofType:@""] stlString];
}

AGFileManager::~AGFileManager()
{ }

const string &AGFileManager::resourcesDirectory()
{
    return m_resourcesDirectory;
}

const string &AGFileManager::soundfileDirectory()
{
    return m_soundfileDirectory;
}

const string &AGFileManager::userDataDirectory()
{
    return m_userDataDirectory;
}

string AGFileManager::documentDirectory(const string &subpath)
{
    if (subpath.length() > 0) {
        return m_documentDirectory + "/" + subpath;
    } else {
        return m_documentDirectory;
    }
}

const string &AGFileManager::examplesDirectory()
{
    return m_examplesDirectory;
}

bool AGFileManager::fileHasExtension(const string &filepathOrName, const string &extension)
{
    if(filepathOrName.length() == 0 || extension.length() == 0)
        return false;
    const auto pos = filepathOrName.rfind(extension);
    bool hasExtensionAtEnd = (pos == filepathOrName.length()-extension.length());
    bool hasDotBeforeExtension = (pos > 0 && filepathOrName[pos-1] == '.');
    return hasExtensionAtEnd && hasDotBeforeExtension;
}

bool AGFileManager::fileExists(const AGFile &file)
{
    std::string filepath = getFullPath(file);
    return [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithSTLString:filepath]];
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
    
    return pathList;
}

std::vector<std::string> AGFileManager::getLines(const string &filepath)
{
    std::vector<std::string> lines;
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:[NSString stringWithSTLString:filepath]
                                                       encoding:NSUTF8StringEncoding error:&error];
    NSArray *linesArray = [fileContents componentsSeparatedByString:@"\n"];
    
    for (NSString *line in linesArray) {
        lines.push_back([line stlString]);
    }
    
    return lines;
}

bool AGFileManager::writeToFile(const string &filepath, const string &contents)
{
    NSString *filepathStr = [NSString stringWithSTLString:filepath];
    NSString *contentsStr = [NSString stringWithSTLString:contents];
    
    NSError *error = nil;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager createDirectoryAtPath:[filepathStr stringByDeletingLastPathComponent]
           withIntermediateDirectories:YES attributes:nil error:&error];
    if (error != nil)
        return false;
    
    [contentsStr writeToFile:filepathStr atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
        return false;
    
    return true;
}

std::string AGFileManager::getFullPath(const AGFile& file)
{
    string path;
    switch(file.m_source)
    {
        case AGFile::USER:
            path = documentDirectory() + "/" + file.m_filename;
            break;
        case AGFile::EXAMPLE:
            path = examplesDirectory() + "/" + file.m_filename;
            break;
    }
    
    return path;
}
