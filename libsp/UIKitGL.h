//
//  UIKitGL.h
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

#ifndef UIKitGL_h
#define UIKitGL_h

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import "Geometry.h"

//------------------------------------------------------------------------------
// name: uiview2gl
// desc: convert UIView coordinates to the OpenGL coordinate space
//------------------------------------------------------------------------------
GLvertex2f uiview2gl(CGPoint p, UIView * view)
{
    GLvertex2f v;
    float aspect = fabsf(view.bounds.size.width / view.bounds.size.height);
    v.x = (((p.x - view.bounds.origin.x)/view.bounds.size.width)*2-1)*aspect;
    v.y = (((p.y - view.bounds.origin.y)/view.bounds.size.height)*2-1);
    return v;
}


#endif
