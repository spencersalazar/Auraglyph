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
#include "AGStyle.h"
#import <CoreText/CoreText.h>

bool TexFont::s_init = false;
GLuint TexFont::s_program = 0;
GLint TexFont::s_uniformMVMatrix = 0;
GLint TexFont::s_uniformProjMatrix = 0;
GLint TexFont::s_uniformNormalMatrix = 0;
GLint TexFont::s_uniformTexture = 0;
GLint TexFont::s_uniformTexpos = 0;
GLuint TexFont::s_geoSize = 0;
GLgeoprimf *TexFont::s_geo = NULL;
float TexFont::s_radius = 0;

static UniChar *g_chars = NULL;
static const char g_charStr[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+[]{}:\";',./<>?|\\`~ ";

void TexFont::initalizeTexFont()
{
    if(!s_init)
    {
        s_init = true;
        
        int len = strlen(g_charStr)+1;
        g_chars = new UniChar[len];
        for(int i = 0; i < len; i++)
        {
            g_chars[i] = g_charStr[i];
        }
        
        s_program = [ShaderHelper createProgram:@"TexFont"
                                 withAttributes:SHADERHELPER_PNTC];
        s_uniformMVMatrix = glGetUniformLocation(s_program, "modelViewMatrix");
        s_uniformProjMatrix = glGetUniformLocation(s_program, "projectionMatrix");
        s_uniformNormalMatrix = glGetUniformLocation(s_program, "normalMatrix");
        s_uniformTexture = glGetUniformLocation(s_program, "texture");
        s_uniformTexpos = glGetUniformLocation(s_program, "texpos");
        
        s_geoSize = 4;
        s_geo = new GLgeoprimf[s_geoSize];
        
        s_radius = 0.005*AGStyle::globalScale;
        
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
    }
}

TexFont::TexFont(const std::string &filepath, int size) :
m_tex(0)
{
    initalizeTexFont();
    
    GLuint spriteTexture = 0;
	CGContextRef spriteContext;
	GLubyte *spriteData;
	size_t texWidth, texHeight;
    
    CGDataProviderRef dataProvider = CGDataProviderCreateWithFilename(filepath.c_str());    
    CGFontRef font = CGFontCreateWithDataProvider(dataProvider);
//    CGFontRef font = CGFontCreateWithFontName(CFSTR("Courier"));
    
    CTFontRef ctFont = CTFontCreateWithGraphicsFont(font, size, NULL, NULL);
    
    CGGlyph glyph;
    CTFontGetGlyphsForCharacters(ctFont, &g_chars[0], &glyph, 1);
    m_width = CTFontGetAdvancesForGlyphs(ctFont, kCTFontDefaultOrientation, &glyph, NULL, 1);
    m_height = CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont);
    
    m_res = 1024;
	texWidth = (int) m_res;
	texHeight = (int) m_res;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    spriteData = (GLubyte *) calloc(texWidth * texHeight * 4, sizeof(GLubyte));
    spriteContext = CGBitmapContextCreate(spriteData, texWidth, texHeight, 8, texWidth * 4, colorSpace, kCGImageAlphaPremultipliedLast);
    
    CGFloat white[4] = {1.0, 1.0, 1.0, 1.0};
    
    CGContextSetFont(spriteContext, font);
    CGContextSetFontSize(spriteContext, size);
    
    CGContextSetFillColor(spriteContext, white);
    CGContextSetStrokeColor(spriteContext, white);
    
    CGContextTranslateCTM(spriteContext, 0, texHeight);
    CGContextScaleCTM(spriteContext, 1, -1);
    
    CGContextSetTextPosition(spriteContext, 0, CTFontGetDescent(ctFont));
    
    // inter-character margin in texture atlas
    // larger vertOffset seems to be needed to avoid artifacts
    float horizOffset = 1, vertOffset = 10;
    
    for(int i = 0; g_chars[i] != 0; i++)
    {
        CGGlyph glyph;
        CTFontGetGlyphsForCharacters(ctFont, &g_chars[i], &glyph, 1);
        if(glyph)
        {
            float glyphWidth = CTFontGetAdvancesForGlyphs(ctFont, kCTFontDefaultOrientation, &glyph, NULL, 1);
            CGRect bbox = CTFontGetBoundingRectsForGlyphs(ctFont, kCTFontDefaultOrientation, &glyph, NULL, 1);
//            fprintf(stderr, "glyph: %c bbox: %f %f %f %f\n", g_chars[i], bbox.origin.x, bbox.origin.y, bbox.size.width, bbox.size.height);
            float preWidth = 0;
            if(bbox.origin.x < 0) preWidth = -bbox.origin.x;
            CGPoint pos = CGContextGetTextPosition(spriteContext);
            
            bool updatePos = false;
            
            if(pos.x + glyphWidth >= m_res)
            {
                // linebreak
                pos.x = 0;
                pos.y += m_height + vertOffset;
                updatePos = true;
            }
            
            if(preWidth > 0)
            {
                pos.x += preWidth;
                updatePos = true;
            }
            
            if(horizOffset > 0)
            {
                pos.x += horizOffset;
                updatePos = true;
            }
            
            if(updatePos)
                CGContextSetTextPosition(spriteContext, pos.x, pos.y);
            
            m_info[g_charStr[i]].isRendered = true;
            m_info[g_charStr[i]].x = pos.x;
            m_info[g_charStr[i]].y = pos.y-CTFontGetDescent(ctFont);
            m_info[g_charStr[i]].width = glyphWidth;
            m_info[g_charStr[i]].height = m_height;
            m_info[g_charStr[i]].preWidth = preWidth; // TODO: account for pre-width in rendering
            
            CGContextShowGlyphs(spriteContext, &glyph, 1);
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
    // Specify a 2D texture image, providing the a pointer to the image data in memory
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, texWidth, texHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    //
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    // Release the image data
    free(spriteData);
    
    m_tex = spriteTexture;
}

void TexFont::render(const std::string &text, const GLcolor4f &color,
                     const GLKMatrix4 &_modelView, const GLKMatrix4 &proj)
{
    glEnable(GL_TEXTURE_2D);
    
    GLKMatrix3 normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(_modelView), NULL);
    
    glUseProgram(s_program);
    
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLgeoprimf), s_geo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLgeoprimf), &s_geo->texcoord);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(GLKVertexAttribNormal);
    
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, m_tex);
    
    glUniformMatrix4fv(s_uniformProjMatrix, 1, 0, proj.m);
    glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, normal.m);
    glUniform1i(s_uniformTexture, 0);
    
    GLKMatrix4 modelView = GLKMatrix4Scale(_modelView, 1, m_height/m_width, 1);
    GLKMatrix4 scaledMV;
    
    for(int i = 0; i < text.size(); i++)
    {
        GlyphInfo info = m_info[text[i]];
        if(info.isRendered) // skip unrendered chars
        {
            scaledMV = GLKMatrix4Scale(modelView, info.width/m_width, 1, 1);
            
            glUniformMatrix4fv(s_uniformMVMatrix, 1, 0, scaledMV.m);
            glUniform4f(s_uniformTexpos, info.x/m_res, info.y/m_res, info.width/m_res, info.height/m_res);
            
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
            
            modelView = GLKMatrix4Translate(modelView, s_radius*info.width/m_width, 0, 0);
        }
    }
    
    glBindTexture(GL_TEXTURE_2D, 0);
    glDisable(GL_TEXTURE_2D);
}

void TexFont::renderTexmap(const GLcolor4f &color, const GLKMatrix4 &_modelView, const GLKMatrix4 &proj)
{
    glEnable(GL_TEXTURE_2D);
    
    GLKMatrix4 modelView = GLKMatrix4Scale(_modelView, 10, 10, 10);
    GLKMatrix3 normal = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL);
    
    glUseProgram(s_program);
    
    glBindVertexArrayOES(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLgeoprimf), s_geo);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLgeoprimf), &s_geo->texcoord);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    
    glVertexAttrib3f(GLKVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(GLKVertexAttribNormal);
    
    glVertexAttrib4fv(GLKVertexAttribColor, (const float *) &color);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, m_tex);
    
    glUniformMatrix4fv(s_uniformProjMatrix, 1, 0, proj.m);
    glUniformMatrix3fv(s_uniformNormalMatrix, 1, 0, normal.m);
    glUniform1i(s_uniformTexture, 0);
    
    glUniformMatrix4fv(s_uniformMVMatrix, 1, 0, modelView.m);
    glUniform4f(s_uniformTexpos, 0, 0, 1, 1);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    
    glBindTexture(GL_TEXTURE_2D, 0);
    glDisable(GL_TEXTURE_2D);
    
}


float TexFont::width()
{
    return s_radius;
}

float TexFont::width(const std::string &text)
{
    float widthRatio = 0;
    float _inverseStdWidth = 1.0f/m_width;
    int len = text.length();
    for(int i = 0; i < len; i++)
    {
        GlyphInfo info = m_info[text[i]];
        if(info.isRendered) widthRatio += info.width*_inverseStdWidth;
    }
    
    return s_radius*widthRatio;
}


float TexFont::height()
{
    return s_radius * m_height/m_width;
}


