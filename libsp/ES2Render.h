//
//  ES2Render.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__ES2Render__
#define __Auragraph__ES2Render__

#import <GLKit/GLKit.h>
#import "Geometry.h"

void genVertexArrayAndBuffer(const GLuint size, GLvncprimf * const geo,
                             GLuint &vertexArray, GLuint &vertexBuffer);


#define BUFFER_OFFSET(i) ((char *)NULL + (i))


#endif /* defined(__Auragraph__ES2Render__) */
