//
//  TexFont.cpp
//  Auragraph
//
//  Created by Spencer Salazar on 8/14/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#import "TexFont.h"
#import "ShaderHelper.h"
#import "ES2Render.h"
#import <CoreText/CoreText.h>

bool TexFont::s_init = false;
GLuint TexFont::s_program = 0;
GLint TexFont::s_uniformMVMatrix = 0;
GLint TexFont::s_uniformProjMatrix = 0;
GLint TexFont::s_uniformNormalMatrix = 0;
GLint TexFont::s_uniformColor2 = 0;
GLint TexFont::s_uniformTexture = 0;
GLint TexFont::s_uniformTexpos = 0;
GLuint TexFont::s_vertexArray = 0;
GLuint TexFont::s_vertexBuffer = 0;
GLuint TexFont::s_geoSize = 0;
GLgeoprimf *TexFont::s_geo = NULL;
float TexFont::s_radius = 0;


static UniChar *g_chars = NULL;
static const char g_charStr[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
static int g_asciiToIndex[127];
static const int g_linebreak = 16;

void TexFont::initalizeTexFont()
{
    if(!s_init)
    {
        s_init = true;
        
        for(int i = 0; i < 127; i++)
            g_asciiToIndex[i] = -1;
        int len = strlen(g_charStr)+1;
        g_chars = new UniChar[len];
        for(int i = 0; i < len; i++)
        {
            g_chars[i] = g_charStr[i];
            g_asciiToIndex[g_charStr[i]] = i;
        }
        
        s_program = [ShaderHelper createProgram:@"TexFont"
                                 withAttributes:SHADERHELPER_PNTC];
        s_uniformMVMatrix = glGetUniformLocation(s_program, "modelViewMatrix");
        s_uniformProjMatrix = glGetUniformLocation(s_program, "projectionMatrix");
        s_uniformNormalMatrix = glGetUniformLocation(s_program, "normalMatrix");
        s_uniformColor2 = glGetUniformLocation(s_program, "color2");
        s_uniformTexture = glGetUniformLocation(s_program, "texture");
        s_uniformTexpos = glGetUniformLocation(s_program, "texpos");
        
        s_geoSize = 4;
        s_geo = new GLgeoprimf[s_geoSize];
        
        s_radius = 0.005;
        
        // fill GL_TRIANGLE_STRIP S-shape
        s_geo[0].vertex = GLvertex3f(0, 0, 0);
        s_geo[1].vertex = GLvertex3f(s_radius, 0, 0);
        s_geo[2].vertex = GLvertex3f(0, s_radius, 0);
        s_geo[3].vertex = GLvertex3f(s_radius, s_radius, 0);
        
        s_geo[0].texcoord = GLvertex2f(0, 0);
        s_geo[1].texcoord = GLvertex2f(1, 0);
        s_geo[2].texcoord = GLvertex2f(0, 1);
        s_geo[3].texcoord = GLvertex2f(1, 1);
        
        // use default normal (0,0,1) + color (1,1,1,1)
        
        genVertexArrayAndBuffer(s_geoSize, s_geo, s_vertexArray, s_vertexBuffer);
    }
}

TexFont::TexFont(const std::string &filepath, int size) :
m_tex(0)
{
    initalizeTexFont();
    
    GLuint spriteTexture = 0;
	CGContextRef spriteContext;
	GLubyte *spriteData;
	size_t width, height;
    
    CGDataProviderRef dataProvider = CGDataProviderCreateWithFilename(filepath.c_str());    
    CGFontRef font = CGFontCreateWithDataProvider(dataProvider);
//    CGFontRef font = CGFontCreateWithFontName(CFSTR("Courier"));
    
    CTFontRef ctFont = CTFontCreateWithGraphicsFont(font, size, NULL, NULL);
    
    CGGlyph glyph;
    CTFontGetGlyphsForCharacters(ctFont, &g_chars[0], &glyph, 1);
    m_width = CTFontGetAdvancesForGlyphs(ctFont, kCTFontDefaultOrientation, &glyph, NULL, 1);
    m_height = CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont);
    
    m_res = 1024;
	width = (int) m_res;
	height = (int) m_res;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    spriteData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
    spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast);
    
    CGFloat white[4] = {1.0, 1.0, 1.0, 1.0};
    
    CGContextSetFont(spriteContext, font);
    CGContextSetFontSize(spriteContext, size);
    CGContextSetFillColor(spriteContext, white);
    CGContextSetStrokeColor(spriteContext, white);
    CGContextTranslateCTM(spriteContext, 0, height);
    CGContextScaleCTM(spriteContext, 1, -1);
    
    CGContextSetTextPosition(spriteContext, 0, CTFontGetDescent(ctFont));
    
    for(int i = 0; g_chars[i] != 0; i++)
    {
        CGGlyph glyph;
        CTFontGetGlyphsForCharacters(ctFont, &g_chars[i], &glyph, 1);
        if(glyph)
        {
            CGContextShowGlyphs(spriteContext, &glyph, 1);
        }
        
        if(i%g_linebreak == g_linebreak-1)
        {
            CGPoint p = CGContextGetTextPosition(spriteContext);
            CGContextSetTextPosition(spriteContext, 0, p.y+m_height);
        }
    }
    
    CGContextRelease(spriteContext);
    CGColorSpaceRelease(colorSpace);
    CFRelease(ctFont);
    CGFontRelease(font);
    CGDataProviderRelease(dataProvider);
    
    glEnable(GL_TEXTURE_2D);
    // Use OpenGL ES to generate a name for the texture.
    glGenTextures(1, &spriteTexture);
    // Bind the texture name.
    glBindTexture(GL_TEXTURE_2D, spriteTexture);
    // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    // Specify a 2D texture image, providing the a pointer to the image data in memory
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    // Release the image data
    free(spriteData);
    
    m_tex = spriteTexture;
}

void TexFont::render(const std::string &text, const GLcolor4f &color,
                     const GLKMatrix4 &_modelView, const GLKMatrix4 &proj)
{
    glEnable(GL_TEXTURE_2D);

    GLKMatrix3 normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(_modelView), NULL);
//    GLKMatrix4 mvp = GLKMatrix4Multiply(proj, modelView);
    
    glUseProgram(s_program);
    
    glBindVertexArrayOES(s_vertexArray);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, m_tex);
    
    glUniformMatrix4fv(s_uniformProjMatrix, 1, 0, proj.m);
    glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, normal.m);
    glUniform4fv(s_uniformColor2, 1, (float*) &color);
    glUniform1i(s_uniformTexture, 0);
    
    GLKMatrix4 modelView = GLKMatrix4Scale(_modelView, 1, m_height/m_width, 1);
    float res_width = m_width/m_res;
    float res_height = m_height/m_res;
    
    for(int i = 0; i < text.size(); i++)
    {
        int idx = g_asciiToIndex[text[i]];
        int x = idx % g_linebreak;
        int y = idx / g_linebreak;
        
//        float texpos[4] = { x*res_width, y*res_height, res_width, res_height };
        
        glUniformMatrix4fv(s_uniformMVMatrix, 1, 0, modelView.m);
        glUniform4f(s_uniformTexpos, x*res_width, y*res_height, res_width, res_height);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        modelView = GLKMatrix4Translate(modelView, s_radius, 0, 0);
    }
}


