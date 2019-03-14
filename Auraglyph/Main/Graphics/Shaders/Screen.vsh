//
//  Shader.vsh
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

attribute vec4 position;
attribute vec4 color;
attribute vec2 texcoord0;

varying lowp vec4 colorVarying;
varying lowp vec2 texcoord;

uniform mat4 modelViewProjectionMatrix;

void main()
{
    colorVarying = color;
    texcoord = texcoord0;
    
    gl_Position = modelViewProjectionMatrix * position;
}
