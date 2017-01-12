//
//  gfx.h
//  Auragraph
//
//  Created by Spencer Salazar on 1/8/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#pragma once

#include <OpenGLES/ES1/gl.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>

typedef enum AGVertexAttrib:GLint
{
    AGVertexAttribPosition,
    AGVertexAttribNormal,
    AGVertexAttribColor,
    AGVertexAttribTexCoord0,
    AGVertexAttribTexCoord1
} AGVertexAttrib;

