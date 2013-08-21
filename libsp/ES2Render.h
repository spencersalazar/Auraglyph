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

void genVertexArrayAndBuffer(const GLuint size, GLvertex3f * const geo,
                             GLuint &vertexArray, GLuint &vertexBuffer,
                             const GLcolor4f &color = GLcolor4f(1, 1, 1, 1),
                             const GLvertex3f &normal = GLvertex3f(0, 0, 1));

void genVertexArrayAndBuffer(const GLuint size, GLvncprimf * const geo,
                             GLuint &vertexArray, GLuint &vertexBuffer);

void genVertexArrayAndBuffer(const GLuint size, GLgeoprimf * const geo,
                             GLuint &vertexArray, GLuint &vertexBuffer);


#define BUFFER_OFFSET(i) ((char *)NULL + (i))

static void glGenTextureFromFramebuffer(GLuint *t, GLuint *f, GLsizei w, GLsizei h)
{
    glGenFramebuffers(1, f);
    glGenTextures(1, t);
    
    glBindFramebuffer(GL_FRAMEBUFFER, *f);
    
    glBindTexture(GL_TEXTURE_2D, *t);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, *t, 0);
    
    GLuint depthbuffer;
    glGenRenderbuffers(1, &depthbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, depthbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, w, h);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthbuffer);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if(status != GL_FRAMEBUFFER_COMPLETE)
        NSLog(@"Framebuffer status: %x", (int)status);
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
}


#endif /* defined(__Auragraph__ES2Render__) */
