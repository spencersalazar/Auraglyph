//
//  AGDrawFreedrawTouchHandler.m
//  Auragraph
//
//  Created by Spencer Salazar on 2/2/14.
//  Copyright (c) 2014 Spencer Salazar. All rights reserved.
//

#import "AGDrawFreedrawTouchHandler.h"

#import "AGDef.h"
#import "Geometry.h"

#import "AGViewController.h"
#import "AGNode.h"
#import "AGFreeDraw.h"
#import "AGStyle.h"
#import "AGGenericShader.h"
#import "AGAnalytics.h"


//------------------------------------------------------------------------------
// ### AGDrawFreedrawTouchHandler ###
//------------------------------------------------------------------------------
#pragma mark -
#pragma mark AGDrawFreedrawTouchHandler

@implementation AGDrawFreedrawTouchHandler

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _currentTrace = LTKTrace();
    _linePoints.push_back(pos);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p = [[touches anyObject] locationInView:_viewController.view];
    GLvertex3f pos = [_viewController worldCoordinateForScreenCoordinate:p];
    
    _linePoints.push_back(pos);
    
    floatVector point;
    point.push_back(p.x);
    point.push_back(p.y);
    _currentTrace.addPoint(point);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(_linePoints.size() > 1)
    {
        AGAnalytics::instance().eventDrawFreedraw();
        
        AGFreeDraw *freeDraw = new AGFreeDraw(&_linePoints[0], _linePoints.size());
        freeDraw->init();
        [_viewController addFreeDraw:freeDraw];
    }
}

- (void)update:(float)t dt:(float)dt { }

- (void)render
{
    if(_linePoints.size() > 1)
    {
        GLKMatrix4 proj = AGNode::projectionMatrix();
        GLKMatrix4 modelView = AGNode::globalModelViewMatrix();
        
        AGGenericShader &shader = AGGenericShader::instance();
        shader.useProgram();
        shader.setProjectionMatrix(proj);
        shader.setModelViewMatrix(modelView);
        shader.setNormalMatrix(GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelView), NULL));
        
        glVertexAttribPointer(AGVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, &_linePoints[0]);
        glEnableVertexAttribArray(AGVertexAttribPosition);
        
        glVertexAttrib3f(AGVertexAttribNormal, 0, 0, 1);
        AGStyle::foregroundColor().set();
        
        glDisableVertexAttribArray(AGVertexAttribTexCoord0);
        glDisableVertexAttribArray(AGVertexAttribTexCoord1);
        glDisable(GL_TEXTURE_2D);
        
        glDrawArrays(GL_LINE_STRIP, 0, (int) _linePoints.size());
    }
}

@end

