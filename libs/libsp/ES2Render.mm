//
//  ES2Render.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#include "ES2Render.h"

void genVertexArrayAndBuffer(const GLuint size, GLvertex3f * const geo,
                             GLuint &vertexArray, GLuint &vertexBuffer,
                             const GLcolor4f &color,
                             const GLvertex3f &normal)
{
    glGenVertexArraysOES(1, &vertexArray);
    glBindVertexArrayOES(vertexArray);
    
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, size*sizeof(GLvertex3f), geo, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(AGVertexAttribPosition);
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvertex3f), BUFFER_OFFSET(0));
    
    glDisableVertexAttribArray(AGVertexAttribColor);
    glDisableVertexAttribArray(AGVertexAttribNormal);
    
    glBindVertexArrayOES(0);
}

void genVertexArrayAndBuffer(const GLuint size, GLvncprimf * const geo,
                             GLuint &vertexArray, GLuint &vertexBuffer)
{
    glGenVertexArraysOES(1, &vertexArray);
    glBindVertexArrayOES(vertexArray);
    
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, size*sizeof(GLvncprimf), geo, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(AGVertexAttribPosition);
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(0));
    glEnableVertexAttribArray(AGVertexAttribNormal);
    glVertexAttribPointer(AGVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(sizeof(GLvertex3f)));
    glEnableVertexAttribArray(AGVertexAttribColor);
    glVertexAttribPointer(AGVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(GLvncprimf), BUFFER_OFFSET(2*sizeof(GLvertex3f)));
    
    glBindVertexArrayOES(0);
}

void genVertexArrayAndBuffer(const GLuint size, GLgeoprimf * const geo,
                             GLuint &vertexArray, GLuint &vertexBuffer)
{
    glGenVertexArraysOES(1, &vertexArray);
    glBindVertexArrayOES(vertexArray);
    
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, size*sizeof(GLgeoprimf), geo, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(AGVertexAttribPosition);
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLgeoprimf), BUFFER_OFFSET(0));
    glEnableVertexAttribArray(AGVertexAttribNormal);
    glVertexAttribPointer(AGVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLgeoprimf), BUFFER_OFFSET(sizeof(GLvertex3f)));
    glEnableVertexAttribArray(AGVertexAttribTexCoord0);
    glVertexAttribPointer(AGVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLgeoprimf), BUFFER_OFFSET(2*sizeof(GLvertex3f)));
    glEnableVertexAttribArray(AGVertexAttribColor);
    glVertexAttribPointer(AGVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(GLgeoprimf), BUFFER_OFFSET(2*sizeof(GLvertex3f) + sizeof(GLvertex2f)));
    
    glBindVertexArrayOES(0);
}

void glGenTextureFromFramebuffer(GLuint *t, GLuint *f, GLsizei w, GLsizei h)
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

