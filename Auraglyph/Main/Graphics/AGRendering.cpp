//
//  AGRendering.cpp
//  Auraglyph
//
//  Created by Spencer Salazar on 11/24/19.
//  Copyright © 2019 Spencer Salazar. All rights reserved.
//

#include "AGRendering.h"
#include "AGStyle.h"
#include "AGGenericShader.h"

void AGRendering::drawGeometry(GLvertex3f geo[], unsigned long size, int kind)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(modelview());
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(kind, 0, (int) size);
}

void AGRendering::drawTriangleFan(GLvertex2f geo[], unsigned long size)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(modelview());
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 2, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, (int) size);
}

void AGRendering::drawTriangleFan(GLvertex3f geo[], unsigned long size)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(modelview());
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, (int) size);
}

void AGRendering::drawTriangleFan(GLvertex3f geo[], unsigned long size, const GLKMatrix4 &xform)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(modelview().multiply(xform));
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, (int) size);
}

void AGRendering::drawTriangleFan(AGGenericShader &shader, GLvertex2f geo[], unsigned long size, const GLKMatrix4 &xform)
{
    shader.setModelViewMatrix(modelview().multiply(xform));
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 2, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, (int) size);
}

void AGRendering::drawTriangleFan(AGGenericShader &shader, GLvertex3f geo[], unsigned long size, const GLKMatrix4 &xform)
{
    shader.setModelViewMatrix(modelview().multiply(xform));
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, (int) size);
}

void AGRendering::drawLineLoop(GLvertex2f geo[], unsigned long size)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(modelview());
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 2, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_LOOP, 0, (int) size);
}

void AGRendering::drawLineLoop(GLvertex3f geo[], unsigned long size)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(modelview());
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_LOOP, 0, (int) size);
}

void AGRendering::drawLineLoop(GLvertex3f geo[], unsigned long size, const GLKMatrix4 &xform)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(modelview().multiply(xform));
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_LOOP, 0, (int) size);
}

void AGRendering::drawLineLoop(AGGenericShader &shader, GLvertex2f geo[], unsigned long size, const GLKMatrix4 &xform)
{
    shader.setModelViewMatrix(modelview().multiply(xform));
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 2, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_LOOP, 0, (int) size);
}

void AGRendering::drawLineLoop(AGGenericShader &shader, GLvertex3f geo[], unsigned long size, const GLKMatrix4 &xform)
{
    shader.setModelViewMatrix(modelview().multiply(xform));
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_LOOP, 0, (int) size);
}

void AGRendering::drawLineStrip(GLvertex2f geo[], unsigned long size)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(modelview());
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 2, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_STRIP, 0, (int) size);
}

void AGRendering::drawLineStrip(GLvertex2f geo[], unsigned long size, const GLKMatrix4 &xform)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(modelview().multiply(xform));
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 2, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_STRIP, 0, (int) size);
}

void AGRendering::drawLineStrip(AGGenericShader &shader, GLvertex2f geo[], unsigned long size, const GLKMatrix4 &xform)
{
    //    shader.useProgram();
    
    shader.setModelViewMatrix(modelview().multiply(xform));
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 2, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_STRIP, 0, (int) size);
}

void AGRendering::drawLineStrip(GLvertex3f geo[], unsigned long size)
{
    AGGenericShader &shader = AGGenericShader::instance();
    
    shader.useProgram();
    
    shader.setModelViewMatrix(modelview());
    shader.setProjectionMatrix(projection());
    
    glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, false, 0, geo);
    glEnableVertexAttribArray(AGVertexAttribPosition);
    
    glDrawArrays(GL_LINE_STRIP, 0, (int) size);
}

void AGRendering::fillCenteredRect(float width, float height)
{
    drawTriangleFan((GLvertex2f[]){
        { -width/2, -height/2 },
        {  width/2, -height/2 },
        {  width/2,  height/2 },
        { -width/2,  height/2 },
    }, 4);
}

void AGRendering::fillCenteredRect(AGGenericShader &shader, float width, float height, const GLKMatrix4 &xform)
{
    drawTriangleFan(shader, (GLvertex2f[]){
        { -width/2, -height/2 },
        {  width/2, -height/2 },
        {  width/2,  height/2 },
        { -width/2,  height/2 },
    }, 4, xform);
}

void AGRendering::strokeCenteredRect(float width, float height, float weight)
{
    glLineWidth(weight);
    
    drawLineLoop((GLvertex2f[]){
        { -width/2, -height/2 },
        {  width/2, -height/2 },
        {  width/2,  height/2 },
        { -width/2,  height/2 },
    }, 4);
}

void AGRendering::strokeCenteredRect(AGGenericShader &shader, float width, float height, float weight, const GLKMatrix4 &xform)
{
    glLineWidth(weight);
    
    drawLineLoop(shader, (GLvertex2f[]){
        { -width/2, -height/2 },
        {  width/2, -height/2 },
        {  width/2,  height/2 },
        { -width/2,  height/2 },
    }, 4, xform);
}

void AGRendering::drawWaveform(float waveform[], unsigned long size, GLvertex2f from, GLvertex2f to, float gain, float yScale)
{
    GLvertex2f vec = (to - from);
    
    // scale gain logarithmically
    if(gain > 0)
        gain = 1.0f/gain * (1+log10f(gain));
    else
        gain = 1;
    
    AGWaveformShader &waveformShader = AGWaveformShader::instance();
    waveformShader.useProgram();
    
    waveformShader.setWindowAmount(0);
    
    GLKMatrix4 modelView = modelview();
    
    // move to from location
    modelView = GLKMatrix4Translate(modelView, from.x, from.y, 0);
    // rotate to face direction of to terminal
    modelView = GLKMatrix4Rotate(modelView, vec.angle(), 0, 0, 1);
    // scale [0,1] to length of connection
    modelView = GLKMatrix4Scale(modelView, vec.magnitude(), yScale, 1);
    
    waveformShader.setProjectionMatrix(projection());
    waveformShader.setModelViewMatrix(modelView);
    
    waveformShader.setZ(0);
    waveformShader.setGain(gain);
    glVertexAttribPointer(AGWaveformShader::s_attribPositionY, 1, GL_FLOAT, GL_FALSE, 0, waveform);
    glEnableVertexAttribArray(AGWaveformShader::s_attribPositionY);
    waveformShader.setNumElements(size);
    
    glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
    glDisableVertexAttribArray(AGVertexAttribNormal);
    
    // todo: pass color in
    AGStyle::foregroundColor().set();
    glDisableVertexAttribArray(AGVertexAttribColor);
    
    glDisableVertexAttribArray(AGVertexAttribPosition);
    
    glLineWidth(2.0);
    
    glDrawArrays(GL_LINE_STRIP, 0, (int) size);
    
    glEnableVertexAttribArray(AGVertexAttribPosition);
}

void AGRendering::fillRect(float x, float y, float width, float height)
{
    drawTriangleFan((GLvertex2f[]){
        { x-width/2, y-height/2 },
        { x+width/2, y-height/2 },
        { x+width/2, y+height/2 },
        { x-width/2, y+height/2 },
    }, 4);
}

void AGRendering::fillRect(AGGenericShader &shader, float x, float y, float width, float height)
{
    drawTriangleFan(shader, (GLvertex2f[]){
        { x-width/2, y-height/2 },
        { x+width/2, y-height/2 },
        { x+width/2, y+height/2 },
        { x-width/2, y+height/2 },
    }, 4, Matrix4::identity);
}

void AGRendering::fillRect(AGGenericShader &shader, float x, float y, float width, float height, const Matrix4& xform)
{
    drawTriangleFan(shader, (GLvertex2f[]){
        { x-width/2, y-height/2 },
        { x+width/2, y-height/2 },
        { x+width/2, y+height/2 },
        { x-width/2, y+height/2 },
    }, 4, xform);
}

void AGRendering::strokeRect(float x, float y, float width, float height, float weight)
{
    glLineWidth(weight);
    
    drawLineLoop((GLvertex2f[]){
        { x-width/2, y-height/2 },
        { x+width/2, y-height/2 },
        { x+width/2, y+height/2 },
        { x-width/2, y+height/2 },
    }, 4);
}

void AGRendering::strokeRect(AGGenericShader &shader, float x, float y, float width, float height, float weight)
{
    glLineWidth(weight);
    
    drawLineLoop(shader, (GLvertex2f[]){
        { x-width/2, y-height/2 },
        { x+width/2, y-height/2 },
        { x+width/2, y+height/2 },
        { x-width/2, y+height/2 },
    }, 4, Matrix4::identity);
}

void AGRendering::strokeRect(AGGenericShader &shader, float x, float y, float width, float height, float weight, const Matrix4& xform)
{
    glLineWidth(weight);
    
    drawLineLoop(shader, (GLvertex2f[]){
        { x-width/2, y-height/2 },
        { x+width/2, y-height/2 },
        { x+width/2, y+height/2 },
        { x-width/2, y+height/2 },
    }, 4, xform);
}
