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

std::string AGDocumentManager::save(const std::vector<std::vector<GLvertex2f>> &name, const AGDocument &doc)
{
    _loadList();
    
    std::string filename = makeUUID() + ".json";
    std::string filepath = documentDirectory() + "/" + filename;
    
    doc.saveToPath(filepath);
    
    m_list->push_back({filename, name});
    
    _saveList();
    
    return filename;
}

void AGDocumentManager::update(const std::string &filename, const AGDocument &doc)
{
    std::string filepath = documentDirectory() + "/" + filename;
    doc.saveToPath(filepath);
}

AGDocument AGDocumentManager::load(const std::string &filename)
{
    std::string filepath = documentDirectory() + "/" + filename;
    AGDocument doc;
    doc.loadFromPath(filepath);
    return doc;
}

const std::vector<AGDocumentManager::DocumentListing> &AGDocumentManager::list()
{
    _loadList(true);
    return *m_list;
}

void AGDocumentManager::_loadList(bool force)
{
    if(m_list == NULL || force)
    {
        /* load cached file list */
        
        NSString *libraryPath = [NSString stringWithSTLString:documentLibraryPath()];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        if(![fileManager fileExistsAtPath:libraryPath])
        {
            // library file doesn't exist - use default (empty) library
            m_list = new std::vector<DocumentListing>;
            return;
        }
        
        NSError *error = nil;
        // read data from disk
        NSData *data = [NSData dataWithContentsOfFile:libraryPath
                                              options:0 error:&error];
        if(error != nil)
        {
            NSLog(@"error: loading document list: %@", error);
            return;
        }
        
        if(data == nil)
        {
            NSLog(@"error: loading document list");
            return;
        }
        
        NSArray *listObj = [NSJSONSerialization JSONObjectWithData:data
                                                           options:0
                                                             error:&error];
        if(error != nil)
        {
            NSLog(@"error: deserializing document list: %@", error);
            return;
        }
        
        if(listObj == nil)
        {
            NSLog(@"error: deserializing document list");
            return;
        }
        
        auto list = new std::vector<DocumentListing>;
        std::set<std::string> filenameSet;
        bool didUpdateList = false;
        
        for(NSDictionary *fileObj in listObj)
        {
            if(fileObj[@"filename"] == nil) continue;
            if(fileObj[@"name"] == nil) continue;
            
            std::string filename = [(NSString *) fileObj[@"filename"] stlString];
            
            // verify existence on disk
            std::string filepath = documentDirectory() + "/" + filename;
            BOOL isDirectory = NO;
            if(![fileManager fileExistsAtPath:[NSString stringWithSTLString:filepath]
                                  isDirectory:&isDirectory]
               || isDirectory)
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
            list->push_back({ filename, name });
        }
        
        /* scan for new items on the list */
        NSString *documentDir = [NSString stringWithSTLString:documentDirectory()];
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
                AGDocument doc = load(filename);
                // pull out name
                auto name = doc.name();
                // add to list
                list->push_back({ filename, name });
            }
        }

        m_list = list;
        
        /* save updated list */
        if(didUpdateList)
            _saveList();
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
            
            [listObj addObject:@{ @"filename": [NSString stringWithSTLString:file.filename],
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


