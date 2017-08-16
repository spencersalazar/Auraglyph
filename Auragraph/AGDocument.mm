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
#include "AGControl.h"

#include "spstl.h"
#include "NSString+STLString.h"


static NSString *filenameForTitle(string title)
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return [[basePath stringByAppendingPathComponent:[NSString stringWithCString:title.c_str() encoding:NSUTF8StringEncoding]] stringByAppendingPathExtension:@"json"];
}


AGDocument::ParamValue::ParamValue(const AGParamValue &value)
{
    switch(value.type)
    {
        case AGControl::TYPE_NONE:
            type = NONE;
            break;
        case AGControl::TYPE_BIT:
            type = BIT;
            i = value.getInt();
            break;
        case AGControl::TYPE_INT:
            type = INT;
            i = value.getInt();
            break;
        case AGControl::TYPE_FLOAT:
            type = FLOAT;
            f = value.getFloat();
            break;
        case AGControl::TYPE_STRING:
            type = STRING;
            s = value.getString();
            break;
        default: assert(0);
    }
}

AGDocument::ParamValue::operator AGParamValue() const
{
    switch(type)
    {
        case BIT: return AGParamValue(i?1:0);
        case INT: return AGParamValue(i);
        case FLOAT: return AGParamValue(f);
        case STRING: return AGParamValue(s);
        default: assert(0);
    }
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

void AGDocument::load(const string &title)
{
    m_title = title;
    
    NSString *filename = filenameForTitle(m_title);
    loadFromPath([filename stlString]);
}

void AGDocument::loadFromPath(const string &path)
{
    NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithSTLString:path]];
    NSDictionary *doc = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    
    if(doc)
    {
        for(NSString *key in doc)
        {
            NSDictionary *dict = doc[key];
            NSString *object = dict[@"object"];
            
            if([object isEqualToString:@"node"])
            {
                Node n;
                n.uuid = [key stlString];
                n._class = (AGDocument::Node::Class) [dict[@"class"] intValue];
                n.type = [dict[@"type"] stlString];
                n.x = [dict[@"x"] floatValue]; n.y = [dict[@"y"] floatValue]; n.z = [dict[@"z"] floatValue];
                
                if([dict objectForKey:@"params"])
                {
                    for(NSString *param in dict[@"params"])
                    {
                        ParamValue pv;
                        
                        NSDictionary *value = dict[@"params"][param];
                        if([value[@"type"] isEqualToString:@"bit"]) { pv.type = ParamValue::BIT; pv.i = [value[@"value"] intValue]?1:0; }
                        else if([value[@"type"] isEqualToString:@"int"]) { pv.type = ParamValue::INT; pv.i = [value[@"value"] intValue]; }
                        else if([value[@"type"] isEqualToString:@"float"]) { pv.type = ParamValue::FLOAT; pv.f = [value[@"value"] floatValue]; }
                        else if([value[@"type"] isEqualToString:@"string"]) { pv.type = ParamValue::STRING; pv.s = [value[@"value"] UTF8String]; }
                        else if([value[@"type"] isEqualToString:@"array_float"])
                        {
                            pv.type = ParamValue::FLOAT_ARRAY;
                            for(id v in value[@"value"])
                                pv.fa.push_back([v floatValue]);
                        }
                        else assert(0); // unhandled
                        
                        n.params[[param UTF8String]] = pv;
                    }
                }
                
                if([dict objectForKey:@"inbound"])
                {
                    for(NSDictionary *conn in dict[@"inbound"])
                    {
                        Connection c;
                        
                        c.uuid = [conn[@"uuid"] stlString];
                        c.srcUuid = [conn[@"src"] stlString];
                        if([conn objectForKey:@"srcPort"])
                            c.srcPort = [[conn objectForKey:@"srcPort"] intValue];
                        else
                            c.srcPort = 0;
                        c.dstUuid = n.uuid;
                        if([conn[@"dstPort"] isKindOfClass:[NSString class]])
                        {
                            int dstPort = AGNodeManager::portNumberForPortName(n._class, n.type, [conn[@"dstPort"] stlString]);
                            assert(dstPort != -1);
                            c.dstPort = dstPort;
                        }
                        else
                            c.dstPort = [conn[@"dstPort"] intValue];
                        
                        m_connections[c.uuid] = c;
                    }
                }
                
                if([dict objectForKey:@"outbound"])
                {
                    for(NSDictionary *conn in dict[@"outbound"])
                    {
                        Connection c;
                        
                        NSDictionary *dstNode = doc[conn[@"dst"]];
                        AGDocument::Node::Class dstClass = (AGDocument::Node::Class) [dstNode[@"class"] intValue];
                        string dstType = [dstNode[@"type"] stlString];
                        
                        c.uuid = [conn[@"uuid"] stlString];
                        c.srcUuid = n.uuid;
                        if([conn objectForKey:@"srcPort"])
                            c.srcPort = [[conn objectForKey:@"srcPort"] intValue];
                        else
                            c.srcPort = 0;
                        c.dstUuid = [conn[@"dst"] stlString];
                        if([conn[@"dstPort"] isKindOfClass:[NSString class]])
                        {
                            int dstPort = AGNodeManager::portNumberForPortName(dstClass, dstType, [conn[@"dstPort"] stlString]);
                            assert(dstPort != -1);
                            c.dstPort = dstPort;
                        }
                        else
                            c.dstPort = [conn[@"dstPort"] intValue];
                        
                        m_connections[c.uuid] = c;
                    }
                }
                
                m_nodes[n.uuid] = n;
            }
            else if([object isEqualToString:@"connection"])
            {
                Connection c;
                
                c.uuid = [key stlString];
                c.srcUuid = [dict[@"src"] stlString];
                c.dstUuid = [dict[@"dst"] stlString];
                c.dstPort = [dict[@"dstPort"] intValue];
                
                m_connections[c.uuid] = c;
            }
            else if([object isEqualToString:@"freedraw"])
            {
                Freedraw f;
                
                f.uuid = [key stlString];
                f.x = [dict[@"x"] floatValue]; f.y = [dict[@"y"] floatValue]; f.z = [dict[@"z"] floatValue];
                f.points.reserve([dict[@"points"] count]);
                for(NSNumber *num in dict[@"points"])
                    f.points.push_back([num floatValue]);
                
                m_freedraws[f.uuid] = f;
            }
            else
            {
                NSLog(@"AGDocument::load: error: unhandled object '%@'", object);
            }
        }
    }
}

void AGDocument::save() const
{
    NSString *filepath = filenameForTitle(m_title);
    saveToPath([filepath stlString]);
}

void AGDocument::saveTo(const string &title)
{
    m_title = title;
    save();
}

void AGDocument::saveToPath(const std::string &path) const
{
    NSMutableDictionary *doc = [NSMutableDictionary new];
    
    for(const pair<const string, Node> &val : m_nodes)
    {
        const string &uuid = val.first;
        const Node &node = val.second;
        
        NSMutableDictionary *params = [NSMutableDictionary new];
        for(const pair<const string, ParamValue> &param : node.params)
        {
            NSString *serialType = nil;
            id serialValue = nil;
            
            switch(param.second.type)
            {
                case ParamValue::BIT: serialValue = @(param.second.i?1:0); serialType = @"bit"; break;
                case ParamValue::INT: serialValue = @(param.second.i); serialType = @"int"; break;
                case ParamValue::FLOAT: serialValue = @(param.second.f); serialType = @"float"; break;
                case ParamValue::STRING: serialValue = [NSString stringWithSTLString:param.second.s]; serialType = @"string"; break;
                case ParamValue::FLOAT_ARRAY:
                    serialType = @"array_float";
                    serialValue = [NSMutableArray arrayWithCapacity:param.second.fa.size()];
                    for(const float &f : param.second.fa)
                    {
                        [serialValue addObject:@(f)];
                    }
                    break;
                case ParamValue::NONE:
                    assert(0);
                    break;
            }
            
            [params setObject:@{ @"type": serialType, @"value": serialValue }
                       forKey:[NSString stringWithSTLString:param.first]];
        };
        
        NSMutableArray *inbound = [NSMutableArray arrayWithCapacity:node.inbound.size()];
        for(const Connection &conn : node.inbound)
        {
            const string &dstPort = AGNodeManager::portNameForPortNumber(node._class, node.type, conn.dstPort);
            assert(dstPort.size() > 0);
            [inbound addObject:@{ @"uuid": [NSString stringWithSTLString:conn.uuid],
                                  @"src": [NSString stringWithSTLString:conn.srcUuid],
                                  @"srcPort": @(conn.srcPort),
                                  @"dstPort": [NSString stringWithSTLString:dstPort],
                                  }];
        }
    
        NSMutableArray *outbound = [NSMutableArray arrayWithCapacity:node.outbound.size()];
        for(const Connection &conn : node.outbound)
        {
            const Node &dstNode = m_nodes.at(conn.dstUuid);
            const string &dstPort = AGNodeManager::portNameForPortNumber(dstNode._class, dstNode.type, conn.dstPort);
            assert(dstPort.size() > 0);
            [outbound addObject:@{ @"uuid": [NSString stringWithSTLString:conn.uuid],
                                   @"dst": [NSString stringWithSTLString:conn.dstUuid],
                                   @"srcPort": @(conn.srcPort),
                                   @"dstPort": [NSString stringWithSTLString:dstPort],
                                   }];
        }
    
        [doc setObject:@{ @"object": @"node",
                          @"class": @((int) node._class),
                          @"type": [NSString stringWithSTLString:node.type],
                          @"x": @(node.x), @"y": @(node.y), @"z": @(node.z),
                          @"params": params,
                          @"inbound": inbound,
                          @"outbound": outbound
                          }
                forKey:[NSString stringWithSTLString:uuid]];
    }
    
    for(const pair<const string, Connection> &val : m_connections)
    {
        const string &uuid = val.first;
        const Connection &conn = val.second;
        
        [doc setObject:@{ @"object": @"connection",
                          @"src": [NSString stringWithSTLString:conn.srcUuid],
                          @"dst": [NSString stringWithSTLString:conn.dstUuid],
                          @"dstPort": [NSString stringWithFormat:@"%i", conn.dstPort],
                          }
                forKey:[NSString stringWithSTLString:uuid]];
    };
    
    for(const pair<const string, Freedraw> &val : m_freedraws)
    {
        const string &uuid = val.first;
        const Freedraw &fd = val.second;
        
        NSMutableArray *points = [NSMutableArray arrayWithCapacity:fd.points.size()];
        for(const float &f : fd.points)
            [points addObject:@(f)];
        
        [doc setObject:@{ @"object": @"freedraw",
                          @"x": @(fd.x), @"y": @(fd.y), @"z": @(fd.z),
                          @"points": points,
                          }
                forKey:[NSString stringWithSTLString:uuid]];
    };
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:doc
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:NULL];
    NSString *filepath = [NSString stringWithSTLString:path];
    NSLog(@"Saving to %@", filepath);
    [data writeToFile:filepath atomically:YES];
}

void AGDocument::recreate(void (^createNode)(const Node &node),
                          void (^createConnection)(const Connection &connection),
                          void (^createFreedraw)(const Freedraw &freedraw))
{
    for(const pair<const string, Node> &kv : m_nodes)
        createNode(kv.second);
    for(const pair<const string, Connection> &kv : m_connections)
        createConnection(kv.second);
    for(const pair<const string, Freedraw> &kv : m_freedraws)
        createFreedraw(kv.second);
}


bool AGDocument::existsForTitle(const string &title)
{
    NSString *filename = filenameForTitle(title);
    return [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:NULL];
}

void AGDocument::Node::saveParam(const string &name, int p)
{
    params[name] = AGDocument::ParamValue(p);
}

void AGDocument::Node::saveParam(const string &name, float p)
{
    params[name] = AGDocument::ParamValue(p);
}

void AGDocument::Node::saveParam(const string &name, const vector<float> &p)
{
    params[name].type = ParamValue::FLOAT_ARRAY;
    for(float f : p)
        params[name].fa.push_back(f);
}

void AGDocument::Node::loadParam(const string &name, vector<float> &p) const
{
    if(params.count(name) && params.at(name).type == ParamValue::FLOAT_ARRAY)
    {
        p.clear();
        p.reserve(params.at(name).fa.size());
        
        for(float f : params.at(name).fa)
            p.push_back(f);
    }
}

