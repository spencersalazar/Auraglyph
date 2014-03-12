//
//  ShaderHelper.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <map>
#import <string>

using namespace std;

typedef enum
{
    SHADERHELPER_ATTR_POSITION = (1 << 0),
    SHADERHELPER_ATTR_NORMAL = (1 << 1),
    SHADERHELPER_ATTR_COLOR = (1 << 2),
    SHADERHELPER_ATTR_TEXCOORD0 = (1 << 3),
    
    SHADERHELPER_PNC = SHADERHELPER_ATTR_POSITION | SHADERHELPER_ATTR_NORMAL | SHADERHELPER_ATTR_COLOR,
    SHADERHELPER_PNTC = SHADERHELPER_ATTR_POSITION | SHADERHELPER_ATTR_NORMAL | SHADERHELPER_ATTR_TEXCOORD0 | SHADERHELPER_ATTR_COLOR,
    SHADERHELPER_PTC = SHADERHELPER_ATTR_POSITION | SHADERHELPER_ATTR_TEXCOORD0 | SHADERHELPER_ATTR_COLOR,
} EnableAttributes;

@interface ShaderHelper : NSObject

#pragma mark -  OpenGL ES 2 shader compilation

+ (GLuint)createProgramForVertexShader:(NSString *)vsh
                        fragmentShader:(NSString *)fsh
                      withAttributeMap:(map<int, string>)attributes;
+ (GLuint)createProgramForVertexShader:(NSString *)vsh
                        fragmentShader:(NSString *)fsh
                        withAttributes:(int)attributes;
+ (GLuint)createProgram:(NSString *)name
       withAttributeMap:(map<int, string>)attributes;
+ (GLuint)createProgram:(NSString *)name
         withAttributes:(int)attributes;
+ (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
+ (BOOL)linkProgram:(GLuint)prog;
+ (BOOL)validateProgram:(GLuint)prog;

@end
