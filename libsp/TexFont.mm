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

bool TexFont::s_init = false;
GLuint TexFont::s_program = 0;
GLuint TexFont::s_vertexArray = 0;
GLuint TexFont::s_vertexBuffer = 0;
GLuint TexFont::s_geoSize = 0;
GLgeoprimf *TexFont::s_geo = NULL;

const static int g_asciiBegin = 32;
const static int g_asciiEnd = 127;
static CFStringRef g_glyphNameForChar[127];

void TexFont::initalizeTexFont()
{
    if(!s_init)
    {
        s_init = true;
        
        memset(g_glyphNameForChar, 0, sizeof(CFStringRef)*127);
        
        for(UniChar i = 'A'; i <= 'Z'; i++)
        {
            CFStringRef name = CFStringCreateWithCharacters(NULL, &i, 1);
            g_glyphNameForChar[i] = name;
        }
        
        s_program = [ShaderHelper createProgram:@"TexFont"
                     withAttributes:SHADERHELPER_PNTC];
        s_geoSize = 4;
        s_geo = new GLgeoprimf[s_geoSize];
        
        float radius = 0.001;
        
        // fill GL_TRIANGLE_STRIP S-shape
        s_geo[0].vertex = GLvertex3f(0, 0, 0);
        s_geo[1].vertex = GLvertex3f(radius, 0, 0);
        s_geo[2].vertex = GLvertex3f(0, radius, 0);
        s_geo[3].vertex = GLvertex3f(radius, radius, 0);
        
        s_geo[0].texcoord = GLvertex2f(0, 0);
        s_geo[1].texcoord = GLvertex2f(1, 0);
        s_geo[2].texcoord = GLvertex2f(0, 1);
        s_geo[3].texcoord = GLvertex2f(1, 1);
        
        // use default normal (0,0,1) + color (1,1,1,1)
        
        genVertexArrayAndBuffer(s_geoSize, s_geo, s_vertexArray, s_vertexBuffer);
    }
}

TexFont::TexFont(const std::string &filepath, int size)
{
    initalizeTexFont();
    
    GLuint spriteTexture = 0;
	CGContextRef spriteContext;
	GLubyte *spriteData;
	size_t	width, height;
    
    CGDataProviderRef dataProvider = CGDataProviderCreateWithFilename(filepath.c_str());
    if(!dataProvider)
        return;
    
    CGFontRef font = CGFontCreateWithDataProvider(dataProvider);
    if(!font)
        return;
    
	// Get the width and height of the image
	width = 2048;
	height = 2048;
    
	// Texture dimensions must be a power of 2. If you write an application that allows users to supply an image,
	// you'll want to add code that checks the dimensions and takes appropriate action if they are not a power of 2.
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Allocated memory needed for the bitmap context
    spriteData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
    // Uses the bitmap creation function provided by the Core Graphics framework.
    spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast);
    
    // After you create the context, you can draw the sprite image to the context.
//    CGContextDrawImage(spriteContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), spriteImage);
    
    CGContextSetFont(spriteContext, font);
    CGContextSetFontSize(spriteContext, size);
    CGContextSetFillColor(spriteContext, (const CGFloat *) &GLcolor4f::white());
    
    for(int i = 0; i < 127; i++)
    {
        
    }
    
    // You don't need the context at this point, so you need to release it to avoid memory leaks.
    CGContextRelease(spriteContext);
    
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
    
    CGFontRelease(font);
    CGDataProviderRelease(dataProvider);
}
