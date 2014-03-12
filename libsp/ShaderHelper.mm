//
//  ShaderHelper.m
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "ShaderHelper.h"
#import <GLKit/GLKit.h>

@implementation ShaderHelper

#pragma mark -  OpenGL ES 2 shader compilation

+ (GLuint)createProgram:(NSString *)name
         withAttributes:(int)attributes
{
    return [ShaderHelper createProgramForVertexShader:[[NSBundle mainBundle] pathForResource:name ofType:@"vsh"]
                                       fragmentShader:[[NSBundle mainBundle] pathForResource:name ofType:@"fsh"]
                                       withAttributes:attributes];
}

+ (GLuint)createProgram:(NSString *)name
       withAttributeMap:(map<int, string>)attributeMap
{
    return [ShaderHelper createProgramForVertexShader:[[NSBundle mainBundle] pathForResource:name ofType:@"vsh"]
                                       fragmentShader:[[NSBundle mainBundle] pathForResource:name ofType:@"fsh"]
                                     withAttributeMap:attributeMap];
}

+ (GLuint)createProgramForVertexShader:(NSString *)vsh
                        fragmentShader:(NSString *)fsh
                        withAttributes:(int)attributes
{
    map<int, string> attributeMap;
    if(attributes & SHADERHELPER_ATTR_POSITION)
        attributeMap[GLKVertexAttribPosition] = "position";
    if(attributes & SHADERHELPER_ATTR_NORMAL)
        attributeMap[GLKVertexAttribNormal] = "normal";
    if(attributes & SHADERHELPER_ATTR_COLOR)
        attributeMap[GLKVertexAttribColor] = "color";
    if(attributes & SHADERHELPER_ATTR_TEXCOORD0)
        attributeMap[GLKVertexAttribTexCoord0] = "texcoord0";
    
    return [self createProgramForVertexShader:vsh
                               fragmentShader:fsh
                             withAttributeMap:attributeMap];
}

+ (GLuint)createProgramForVertexShader:(NSString *)vsh
                        fragmentShader:(NSString *)fsh
                      withAttributeMap:(map<int, string>)attributeMap
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    GLuint _program = 0;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = vsh;
    if (![ShaderHelper compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        glDeleteProgram(_program);
        return 0;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = fsh;
    if (![ShaderHelper compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        glDeleteProgram(_program);
        return 0;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    for(map<int, string>::iterator i = attributeMap.begin(); i != attributeMap.end(); i++)
        glBindAttribLocation(_program, i->first, i->second.c_str());
    
    // Link program.
    if (![ShaderHelper linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
        
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return _program;
}

+ (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

+ (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

+ (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
