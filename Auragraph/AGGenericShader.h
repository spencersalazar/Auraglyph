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

class AGGenericShader
{
public:
    
    static const AGGenericShader &instance();
    
    void useProgram() const;
    
    void setMVPMatrix(const GLKMatrix4 &m) const;
    void setNormalMatrix(const GLKMatrix3 &m) const;
    
private:
    AGGenericShader();
    
    GLuint m_program;
    GLint m_uniformMVPMatrix;
    GLint m_uniformNormalMatrix;
};

#endif /* defined(__Auragraph__AGGenericShader__) */
