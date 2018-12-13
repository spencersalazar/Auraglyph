//
//  AGFileManager.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 1/8/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGFileManager.h"
#include "NSString+STLString.h"


AGFile::AGFile()
: m_filename(), m_source(USER), m_creationTime(0)
{ }

AGFile::AGFile(const std::string &filename, Source source, time_t creationTime)
: m_filename(filename), m_source(source), m_creationTime(creationTime)
{
    if(m_creationTime == 0)
    {
        std::string fullpath = AGFileManager::instance().getFullPath(filename, source);
        m_creationTime = AGFileManager::instance().creationTimeForFilepath(fullpath);
    }
}

AGFile AGFile::UserFile(const std::string &filename) { return AGFile(filename, USER); }

AGFile AGFile::ExampleFile(const std::string &filename) { return AGFile(filename, EXAMPLE); }

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
    m_documentDirectory = [documentPath UTF8String];
    m_examplesDirectory = [[[NSBundle mainBundle] pathForResource:@"examples" ofType:@""] stlString];
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

const string &AGFileManager::documentDirectory()
{
    return m_documentDirectory;
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

time_t AGFileManager::creationTimeForFilepath(const string &filepath)
{
    NSError *error = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[NSString stringWithSTLString:filepath]
                                                                                error:&error];
    if(error != nil)
        return 0;
    
    NSDate *date = attributes[NSFileCreationDate];
    return [date timeIntervalSince1970];
}

void AGFileManager::removeFile(const std::string &path)
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    [manager removeItemAtPath:[NSString stringWithSTLString:path] error:&error];
}

std::string AGFileManager::getFullPath(const string& filename, AGFile::Source fileSource)
{
    string path;
    switch(fileSource)
    {
        case AGFile::USER:
            path = documentDirectory() + "/" + filename;
            break;
        case AGFile::EXAMPLE:
            path = examplesDirectory() + "/" + filename;
            break;
    }
    
    return path;
}

std::string AGFileManager::getFullPath(const AGFile& file)
{
    return getFullPath(file.m_filename, file.m_source);
}
