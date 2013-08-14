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
    TexFont(const std::string &family, int size);
    
    void render(const std::string &text, const GLcolor4f &color,
                const GLKMatrix4 &modelView, const GLKMatrix4 &proj);
    
private:
    
    static bool s_init;
    static GLuint s_program;
    static GLuint s_vertexArray;
    static GLuint s_vertexBuffer;
    static GLuint s_geoSize;
    static GLgeoprimf *s_geo;

    static void initalizeTexFont();
    
    GLuint m_tex;
    
    struct GlyphInfo
    {
        float baselineHeight;
        float width;
    };
    
    GlyphInfo m_info[127];
};


#endif /* defined(__Auragraph__TexFont__) */
