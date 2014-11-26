//
//  AGDocument.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 11/21/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#include "AGDocument.h"

#include "AGNode.h"
#include "AGConnection.h"

#include "spstl.h"
#include "NSString+STLString.h"

static NSString *filenameForTitle(string title)
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return [basePath stringByAppendingPathComponent:[NSString stringWithCString:title.c_str() encoding:NSUTF8StringEncoding]];
}


AGDocument::AGDocument() :
m_title("") { }

AGDocument::~AGDocument()
{ }

void AGDocument::addNode(const Node &node)
{
    m_nodes[node.uuid] = node;
}

void AGDocument::updateNode(const string &uuid, const Node &update)
{
    m_nodes[uuid] = update;
}

void AGDocument::removeNode(const string &uuid)
{
    m_nodes.erase(uuid);
}

void AGDocument::addConnection(const Connection &connection)
{
    m_connections[connection.uuid] = connection;
}

void AGDocument::removeConnection(const string &uuid)
{
    m_connections.erase(uuid);
}

void AGDocument::addFreedraw(const Freedraw &freedraw)
{
    m_freedraws[freedraw.uuid] = freedraw;
}

void AGDocument::updateFreedraw(const string &uuid, const Freedraw &update)
{
    m_freedraws[uuid] = update;
}

void AGDocument::removeFreedraw(const string &uuid)
{
    m_freedraws.erase(uuid);
}

void AGDocument::create()
{
    
}

void AGDocument::load(string title)
{
    m_title = title;
    
    NSString *filename = filenameForTitle(m_title);
    NSData *data = [NSData dataWithContentsOfFile:filename];
    NSDictionary *top = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
}

void AGDocument::save()
{
    NSMutableDictionary *doc = [NSMutableDictionary new];
    
    itmap(m_nodes, ^(pair<const string, Node> &val){
        const string &uuid = val.first;
        Node &node = val.second;
        
        NSMutableDictionary *params = [NSMutableDictionary new];
        itmap(node.params, ^(pair<const string, ParamValue> &param){
            id serialValue = nil;
            
            switch(param.second.type)
            {
                case ParamValue::INT: serialValue = @(param.second.i); break;
                case ParamValue::FLOAT: serialValue = @(param.second.f); break;
                case ParamValue::STRING: serialValue = [NSString stringWithSTLString:param.second.s]; break;
                case ParamValue::FLOAT_ARRAY:
                    serialValue = [NSMutableArray arrayWithCapacity:param.second.fa.size()];
                    itmap(param.second.fa, ^(float &f){
                        [serialValue addObject:@(f)];
                    });
                    break;
            }
            
            [params setObject:serialValue
                       forKey:[NSString stringWithSTLString:param.first]];
        });
        
        [doc setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        @"node", @"object",
                        @((int) node._class), @"class",
                        [NSString stringWithSTLString:node.type], @"type",
                        @(node.x), @"x", @(node.y), @"y", @(node.z), @"z",
                        params, @"params",
                        nil]
                forKey:[NSString stringWithSTLString:uuid]];
    });
    
    itmap(m_connections, ^(pair<const string, Connection> &val){
        const string &uuid = val.first;
        Connection &conn = val.second;
        
        [doc setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        @"connection", @"object",
                        [NSString stringWithSTLString:conn.srcUuid], @"source",
                        [NSString stringWithSTLString:conn.dstUuid], @"destination",
                        nil]
                forKey:[NSString stringWithSTLString:uuid]];
    });
    
    itmap(m_freedraws, ^(pair<const string, Freedraw> &val){
        const string &uuid = val.first;
        Freedraw &fd = val.second;
        
        NSMutableArray *points = [NSMutableArray arrayWithCapacity:fd.points.size()];
        itmap(fd.points, ^(float &f){
            [points addObject:@(f)];
        });
        
        [doc setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        @"freedraw", @"object",
                        @(fd.x), @"x", @(fd.y), @"y", @(fd.z), @"z",
                        points, @"points",
                        nil]
                forKey:[NSString stringWithSTLString:uuid]];
    });
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:doc
                                                   options:0 error:NULL];
    NSString *filepath = filenameForTitle(m_title);
    [data writeToFile:filepath atomically:YES];
}

void AGDocument::saveTo(string title)
{
    m_title = title;
    save();
}

void AGDocument::recreate(void (^createNode)(const Node &node),
              void (^createConnection)(const Connection &connection),
              void (^createFreedraw)(const Freedraw &freedraw))
{
    
}

