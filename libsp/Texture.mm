/*
 *  Texture.mm
 *  BallPit
 *
 *  Created by Spencer Salazar on 6/7/10.
 *  Copyright 2010 Spencer Salazar. All rights reserved.
 *
 */

#import "Texture.h"
#import <QuartzCore/QuartzCore.h>

GLuint loadTexture(const char *name)
{
    return loadTexture([NSString stringWithUTF8String:name]);
}


GLuint loadTexture(NSString *name)
{
    GLuint spriteTexture = 0;
	CGImageRef spriteImage;
	CGContextRef spriteContext;
	GLubyte *spriteData;
	size_t	width, height;
		
	// Creates a Core Graphics image from an image file
	spriteImage = [UIImage imageNamed:name].CGImage;
    
	// Get the width and height of the image
	width = CGImageGetWidth(spriteImage);
	height = CGImageGetHeight(spriteImage);
    
	// Texture dimensions must be a power of 2. If you write an application that allows users to supply an image,
	// you'll want to add code that checks the dimensions and takes appropriate action if they are not a power of 2.
    
	if(spriteImage)
    {
		// Allocated memory needed for the bitmap context
		spriteData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
		// Uses the bitmap creation function provided by the Core Graphics framework. 
		spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width * 4, CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
		// After you create the context, you can draw the sprite image to the context.
		CGContextDrawImage(spriteContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), spriteImage);
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
	}
    
    return spriteTexture;
}


NSMutableDictionary *_textureDict = nil;

GLuint loadOrRetrieveTexture(NSString *name)
{
    if(_textureDict == nil)
        _textureDict = [NSMutableDictionary new];
    
    NSNumber *num = [_textureDict objectForKey:name];
    
    if(num != nil)
    {
        return (GLuint) [num unsignedIntegerValue];
    }
    else
    {
        GLuint tex = loadTexture(name);
        [_textureDict setObject:[NSNumber numberWithUnsignedInteger:tex] forKey:name];
        return tex;
    }
}

GLuint loadOrRetrieveTexture(const char *name)
{
    return loadOrRetrieveTexture([NSString stringWithUTF8String:name]);
}



