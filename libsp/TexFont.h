//
//  TexFont.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__TexFont__
#define __Auragraph__TexFont__

#include <string>
#include <GLKit/GLKit.h>
#include "Geometry.h"

class TexFont
{
public:
    TexFont(const std::string &filepath, int size);
    
    void render(const std::string &text, const GLcolor4f &color,
                const GLKMatrix4 &modelView, const GLKMatrix4 &proj);
    
    // for debugging
    void renderTexmap(const GLcolor4f &color, const GLKMatrix4 &modelView, const GLKMatrix4 &proj);
    
    float width();
    float width(const std::string &text);
    float height();
    
private:
    
    static bool s_init;

    static GLuint s_program;
    static GLint s_uniformMVMatrix;
    static GLint s_uniformProjMatrix;
    static GLint s_uniformNormalMatrix;
    static GLint s_uniformTexture;
    static GLint s_uniformTexpos;

    static GLuint s_geoSize;
    static GLgeoprimf *s_geo;
    static float s_radius;

    static void initalizeTexFont();
    
    struct GlyphInfo
    {
        GlyphInfo() : isRendered(false) { }
        bool isRendered;
        GLfloat x, y;
        GLfloat width, height;
        GLfloat preWidth;
    };
    
    GLuint m_tex;
    GlyphInfo m_info[127];
    float m_width;
    float m_height;
    float m_res;
};


#endif /* defined(__Auragraph__TexFont__) */
