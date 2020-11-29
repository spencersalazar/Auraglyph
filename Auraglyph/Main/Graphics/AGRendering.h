//
//  AGRendering.hpp
//  Auraglyph
//
//  Created by Spencer Salazar on 11/24/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#pragma once

#include "Geometry.h"
#include "Matrix.h"
#include <vector>

class AGGenericShader;

/** Utility base class for rendering functions.
 Requires a subclass to supply modelview/projection matrices.
 */
class AGRendering
{
public:
    virtual ~AGRendering() { }
    
    virtual const Matrix4 &modelview() const = 0;
    virtual const Matrix4 &projection() const = 0;
    
    // draw functions
    void drawGeometry(GLvertex3f geo[], unsigned long size, int kind);
    
    void drawTriangleFan(GLvertex2f geo[], unsigned long size);
    void drawTriangleFan(GLvertex3f geo[], unsigned long size);
    void drawTriangleFan(GLvertex3f geo[], unsigned long size, const GLKMatrix4 &xform);
    void drawTriangleFan(AGGenericShader &shader, GLvertex2f geo[], unsigned long size, const GLKMatrix4 &xform);
    void drawTriangleFan(AGGenericShader &shader, GLvertex3f geo[], unsigned long size, const GLKMatrix4 &xform);
    
    void drawLineLoop(GLvertex2f geo[], unsigned long size);
    void drawLineLoop(GLvertex3f geo[], unsigned long size);
    void drawLineLoop(GLvertex3f geo[], unsigned long size, const GLKMatrix4 &xform);
    void drawLineLoop(AGGenericShader &shader, GLvertex2f geo[], unsigned long size, const GLKMatrix4 &xform);
    void drawLineLoop(AGGenericShader &shader, GLvertex3f geo[], unsigned long size, const GLKMatrix4 &xform);
    
    // void drawLineStrip(GLvertex2f geo[], unsigned long size);
    void drawLineStrip(GLvertex3f geo[], unsigned long size);
    void drawLineStrip(GLvertex2f geo[], unsigned long size, const GLKMatrix4 &xform);
    void drawLineStrip(AGGenericShader &shader, GLvertex2f geo[], unsigned long size, const GLKMatrix4 &xform);
    void drawLineStrip(const std::vector<GLvertex2f>& geo);
    void drawLineStrip(const std::vector<GLvertex2f>& geo, float width);

    void fillRect(float x, float y, float width, float height);
    void fillRect(AGGenericShader &shader, float x, float y, float width, float height);
    void fillRect(AGGenericShader &shader, float x, float y, float width, float height, const Matrix4& xform);

    void fillCenteredRect(float width, float height);
    void fillCenteredRect(AGGenericShader &shader, float width, float height, const GLKMatrix4 &xform);
    
    void strokeRect(float x, float y, float width, float height, float weight);
    void strokeRect(AGGenericShader &shader, float x, float y, float width, float height, float weight);
    void strokeRect(AGGenericShader &shader, float x, float y, float width, float height, float weight, const Matrix4& xform);
    
    void strokeCenteredRect(float width, float height, float weight);
    void strokeCenteredRect(AGGenericShader &shader, float width, float height, float weight, const GLKMatrix4 &xform);
    
    void drawWaveform(float waveform[], unsigned long size, GLvertex2f from, GLvertex2f to, float gain = 1.0f, float yScale = 1.0f);
};


