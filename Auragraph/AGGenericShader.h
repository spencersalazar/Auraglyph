//
//  AGGenericShader.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/16/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef __Auragraph__AGGenericShader__
#define __Auragraph__AGGenericShader__

#import <GLKit/GLKit.h>
#import "Geometry.h"

class AGGenericShader
{
public:
    
    static AGGenericShader &instance();
    
    void useProgram();
    
    void setProjectionMatrix(const GLKMatrix4 &p);
    void setModelViewMatrix(const GLKMatrix4 &mv);
    
    void setMVPMatrix(const GLKMatrix4 &m);
    void setNormalMatrix(const GLKMatrix3 &m);
    
protected:
    AGGenericShader(NSString *name = @"Shader");
    
    GLuint m_program;
    GLint m_uniformMVPMatrix;
    GLint m_uniformNormalMatrix;
    
    GLKMatrix4 m_proj;
    GLKMatrix4 m_mv;
};

class AGClipShader : public AGGenericShader
{
public:
    
    static AGClipShader &instance();
    
    void setClip(const GLvertex2f &origin, const GLvertex2f &size);
    void setLocalMatrix(const GLKMatrix4 &l);

private:
    AGClipShader();
    
    GLint m_uniformClipOrigin;
    GLint m_uniformClipSize;
    GLint m_uniformLocalMatrix;
};

#endif /* defined(__Auragraph__AGGenericShader__) */
