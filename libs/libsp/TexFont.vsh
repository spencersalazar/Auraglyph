//
//  Shader.vsh
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

attribute vec4 position;
attribute vec3 normal;
attribute vec2 texcoord0;
attribute vec4 color;

varying lowp vec4 colorVarying;
varying lowp vec2 texcoord;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform mat3 normalMatrix;
uniform vec4 texpos;

void main()
{
    vec3 eyeNormal = normalize(normalMatrix * normal);
    vec3 lightPosition = vec3(0.0, 0.0, 1.0);
    vec4 diffuseColor = vec4(1.0, 1.0, 1.0, 1.0);
    
    float nDotVP = max(0.0, dot(eyeNormal, normalize(lightPosition)));
                 
    colorVarying = diffuseColor * nDotVP * color;
    
    texcoord.x = texpos.x + texcoord0.x*texpos.z;
    texcoord.y = texpos.y + texcoord0.y*texpos.w;

    gl_Position = projectionMatrix * modelViewMatrix * position;
}
