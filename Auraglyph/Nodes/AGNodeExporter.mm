//
//  AGNodeExporter.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 12/28/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "AGNodeExporter.h"

#include "AGNode.h"
#include "NSString+STLString.h"

#include <vector>


static void _processNodes(const std::vector<const AGNodeManifest *> &nodeList,
                          NSMutableArray *nodes)
{
    for(auto node : nodeList) {
        NSMutableArray *params = [NSMutableArray new];
        NSMutableArray *ports = [NSMutableArray new];
        NSMutableArray *outputs = [NSMutableArray new];
        NSMutableDictionary *icon = [NSMutableDictionary new];
        
        for(auto param : node->editPortInfo())
            [params addObject:@{ @"name": [NSString stringWithSTLString:param.name],
                                 @"desc": [NSString stringWithSTLString:param.doc] }];
        
        for(auto port : node->inputPortInfo())
            [ports addObject:@{ @"name": [NSString stringWithSTLString:port.name],
                                @"desc": [NSString stringWithSTLString:port.doc] }];
        
        for(auto port : node->outputPortInfo())
            [outputs addObject:@{ @"name": [NSString stringWithSTLString:port.name],
                                  @"desc": [NSString stringWithSTLString:port.doc] }];
        
        NSMutableArray *iconGeo = [NSMutableArray new];
        for(auto pt : node->iconGeo())
            [iconGeo addObject:@{ @"x": @(pt.x), @"y": @(pt.y)}];
        icon[@"geo"] = iconGeo;
        
        switch (node->iconGeoType()) {
            case GL_LINES: icon[@"type"] = @"lines"; break;
            case GL_LINE_STRIP: icon[@"type"] = @"line_strip"; break;
            case GL_LINE_LOOP: icon[@"type"] = @"line_loop"; break;
            default: assert(0);
        }
        
        [nodes addObject:@{
            @"name": [NSString stringWithSTLString:node->type()],
            @"desc": [NSString stringWithSTLString:node->description()],
            @"icon": icon,
            @"params": params,
            @"ports": ports,
            @"outputs": outputs
        }];
    }
}


void AGNodeExporter::exportNodes(const std::string& file)
{
    NSMutableArray *audioNodes = [NSMutableArray new];
    NSMutableArray *controlNodes = [NSMutableArray new];
        
    _processNodes(AGNodeManager::audioNodeManager().nodeTypes(), audioNodes);
    _processNodes(AGNodeManager::controlNodeManager().nodeTypes(), controlNodes);
    
    NSDictionary *nodes = @{ @"audio": audioNodes, @"control": controlNodes };
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:nodes options:NSJSONWritingPrettyPrinted error:&error];
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *nodeInfoPath = [documentPath stringByAppendingPathComponent:[NSString stringWithSTLString:file]];
    NSLog(@"writing node info to: %@", nodeInfoPath);
    [jsonData writeToFile:nodeInfoPath atomically:YES];
}
