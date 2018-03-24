//
//  ES2Render.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#pragma once

#include "gfx.h"
#include "Geometry.h"

void genVertexArrayAndBuffer(const GLuint size, GLvertex3f * const geo,
                             GLuint &vertexArray, GLuint &vertexBuffer,
                             const GLcolor4f &color = GLcolor4f(1, 1, 1, 1),
                             const GLvertex3f &normal = GLvertex3f(0, 0, 1));

void genVertexArrayAndBuffer(const GLuint size, GLvncprimf * const geo,
                             GLuint &vertexArray, GLuint &vertexBuffer);

void genVertexArrayAndBuffer(const GLuint size, GLgeoprimf * const geo,
                             GLuint &vertexArray, GLuint &vertexBuffer);


#define BUFFER_OFFSET(i) ((char *)NULL + (i))

void glGenTextureFromFramebuffer(GLuint *t, GLuint *f, GLsizei w, GLsizei h);
