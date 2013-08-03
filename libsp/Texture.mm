/*
 *  Texture.mm
 *  BallPit
 *
 *  Created by Spencer Salazar on 6/7/10.
 *  Copyright 2010 Spencer Salazar. All rights reserved.
 *
 */

#include "Texture.h"
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
	
//	// Sets up matrices and transforms for OpenGL ES
//	glViewport(0, 0, backingWidth, backingHeight);
//	glMatrixMode(GL_PROJECTION);
//	glLoadIdentity();
//	glOrthof(-1.0f, 1.0f, -1.5f, 1.5f, -1.0f, 1.0f);
//	glMatrixMode(GL_MODELVIEW);
//	
//	// Clears the view with black
//	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
//	
//	// Sets up pointers and enables states needed for using vertex arrays and textures
//	glVertexPointer(2, GL_FLOAT, 0, spriteVertices);
//	glEnableClientState(GL_VERTEX_ARRAY);
//	glTexCoordPointer(2, GL_SHORT, 0, spriteTexcoords);
//	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	
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
