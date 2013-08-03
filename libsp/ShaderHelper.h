//
//  ShaderHelper.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ShaderHelper : NSObject

#pragma mark -  OpenGL ES 2 shader compilation

+ (GLuint)createProgramForVertexShader:(NSString *)vsh
                        fragmentShader:(NSString *)fsh;
+ (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
+ (BOOL)linkProgram:(GLuint)prog;
+ (BOOL)validateProgram:(GLuint)prog;

@end
