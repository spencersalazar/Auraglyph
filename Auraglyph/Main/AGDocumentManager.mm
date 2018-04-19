//
//  AGDocumentManager.mm
//  Auragraph
//
//  Created by Spencer Salazar on 11/17/16.
//  Copyright © 2016 Spencer Salazar. All rights reserved.
//

#include "AGDocumentManager.h"
#include "NSString+STLString.h"
#include "sputil.h"
#include "AGFileManager.h"
#include <set>


std::string documentLibraryPath()
{
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *docLibraryPath = [libraryPath stringByAppendingPathComponent:@"documents.json"];
    return [docLibraryPath stlString];
}

std::string exampleLibraryPath()
{
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *exLibraryPath = [libraryPath stringByAppendingPathComponent:@"examples.json"];
    return [exLibraryPath stlString];
}

std::string documentDirectory()
{
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [documentPath stlString];
}


AGDocumentManager &AGDocumentManager::instance()
{
    static AGDocumentManager s_instance;
    
    return s_instance;
}

AGFile AGDocumentManager::save(const std::vector<std::vector<GLvertex2f>> &name, const AGDocument &doc)
{
    _loadList();
    
    AGFile file = AGFile::UserFile(makeUUID() + ".json");
    std::string filepath = AGFileManager::instance().getFullPath(file);
    
    doc.saveToPath(filepath);
    
    m_list->push_back({ file, name });
    
    _saveList();
    
    return file;
}

void AGDocumentManager::update(const AGFile &file, const AGDocument &doc)
{
    std::string filepath = AGFileManager::instance().getFullPath(file);
    doc.saveToPath(filepath);
}

AGDocument AGDocumentManager::load(const AGFile &file)
{
    std::string filepath = AGFileManager::instance().getFullPath(file);
    AGDocument doc;
    doc.loadFromPath(filepath);
    
    // set name, if needed
    if(doc.name().size() == 0)
    {
        // find this doc in listing
        for(auto listing : list())
        {
            if(listing.filename == file)
            {
                doc.setName(listing.name);
                break;
            }
        }
    }
    
    return doc;
}

const std::vector<AGDocumentManager::DocumentListing> &AGDocumentManager::list()
{
    _loadList(true);
    return *m_list;
}

const std::vector<AGDocumentManager::DocumentListing> &AGDocumentManager::examplesList()
{
    if(m_examplesList == nullptr)
        m_examplesList = _doLoad(AGFileManager::instance().examplesDirectory(), exampleLibraryPath(), AGFile::EXAMPLE);
    return *m_examplesList;
}

std::vector<AGDocumentManager::DocumentListing> *AGDocumentManager::_doLoad(const std::string &dir, const std::string &libraryPath, AGFile::Source source)
{
    NSString *libPath = [NSString stringWithSTLString:libraryPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    
    auto list = new std::vector<DocumentListing>;
    bool didUpdateList = false;
    std::set<std::string> filenameSet;
    
    if([fileManager fileExistsAtPath:libPath])
    {
        // read data from disk
        NSData *data = [NSData dataWithContentsOfFile:libPath
                                              options:0 error:&error];
        if(error != nil)
        {
            NSLog(@"error: loading document list: %@", error);
            return nullptr;
        }
        
        if(data == nil)
        {
            NSLog(@"error: loading document list");
            return nullptr;
        }
        
        NSArray *listObj = [NSJSONSerialization JSONObjectWithData:data
                                                           options:0
                                                             error:&error];
        if(error != nil)
        {
            NSLog(@"error: deserializing document list: %@", error);
            return nullptr;
        }
        
        if(listObj == nil)
        {
            NSLog(@"error: deserializing document list");
            return nullptr;
        }
        
        for(NSDictionary *fileObj in listObj)
        {
            if(fileObj[@"filename"] == nil) continue;
            if(fileObj[@"name"] == nil) continue;
            
            std::string filename = [(NSString *) fileObj[@"filename"] stlString];
            AGFile file = { filename, source };
            
            // verify existence on disk
            if(!AGFileManager::instance().fileExists(file))
            {
                // file no longer exists; skip it
                didUpdateList = true;
                continue;
            }
            
            bool isValid = true;
            std::vector<std::vector<GLvertex2f>> name;
            for(NSArray *figureObj in fileObj[@"name"])
            {
                std::vector<GLvertex2f> figure;
                
                for(NSArray *pointObj in figureObj)
                {
                    if([pointObj count] != 2)
                    {
                        isValid = false;
                        break;
                    }
                    
                    float x = [pointObj[0] floatValue];
                    float y = [pointObj[1] floatValue];
                    figure.push_back({ x, y });
                }
                
                if(!isValid) break;
                
                name.push_back(figure);
            }
            
            if(!isValid) continue;
            
            filenameSet.insert(filename);
            list->push_back({ file, name });
        }
    }
    
    /* scan for new items on the list */
    NSString *documentDir = [NSString stringWithSTLString:dir];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:documentDir error:&error];
    for(NSString *file in files)
    {
        std::string filename = [file stlString];
        if(!AGFileManager::instance().fileHasExtension(filename, "json"))
            continue;
        if(filename == "nodes.json")
            continue;
        
        if(!filenameSet.count(filename))
        {
            didUpdateList = true;
            // load it
            AGFile file = { filename, source };
            AGDocument doc = load(file);
            // pull out name
            auto name = doc.name();
            // add to list
            list->push_back({ file, name });
        }
    }
    
    return list;
}

void AGDocumentManager::_loadList(bool force)
{
    if(m_list == NULL || force)
    {
        /* load cached file list */
        
        auto list = _doLoad(documentDirectory(), documentLibraryPath(), AGFile::USER);
        if(list != nullptr)
        {
            m_list = list;
            /* save updated list */
            _saveList();
        }
    }
}

void AGDocumentManager::_saveList()
{
    if(m_list != NULL)
    {
        NSMutableArray *listObj = [NSMutableArray arrayWithCapacity:m_list->size()];
        // package into NSArray
        for(auto file : *m_list)
        {
            // array of array of 2d points (array of floats)
            NSMutableArray *nameObj = [NSMutableArray arrayWithCapacity:file.name.size()];
            // for each figure (array of points)
            for(auto figure : file.name)
            {
                // array of 2d points (array of floats)
                NSMutableArray *figureObj = [NSMutableArray arrayWithCapacity:figure.size()];
                // for each point
                for(auto point : figure)
                    [figureObj addObject:@[@(point.x), @(point.y)]];
                [nameObj addObject:figureObj];
            }
            
            [listObj addObject:@{ @"filename": [NSString stringWithSTLString:file.filename.m_filename],
                                  @"source": (file.filename.m_source == AGFile::USER) ? @"user" : @"example",
                                  @"name": nameObj }];
        }
        
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:listObj
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
        if(error != nil)
        {
            NSLog(@"error: serializing document list: %@", error);
            return;
        }
        
        if(data == nil)
        {
            NSLog(@"error: serializing document list");
            return;
        }
        
        [data writeToFile:[NSString stringWithSTLString:documentLibraryPath()]
                  options:NSDataWritingAtomic error:&error];
        
        if(error != nil)
        {
            NSLog(@"error: writing document list: %@", error);
            return;
        }
    }
}


