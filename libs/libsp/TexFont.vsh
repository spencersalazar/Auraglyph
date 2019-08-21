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

varying lowp vec4 vColor;
varying lowp vec2 vTexcoord;
varying mediump vec2 vClipBottomLeft;
varying mediump vec2 vClipTopRight;
varying mediump vec2 vClipPos;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform mat3 normalMatrix;
uniform vec4 texpos;

uniform mat4 uClipMatrix;
uniform vec2 uClipOrigin;
uniform vec2 uClipSize;

void main()
{
    vec3 eyeNormal = normalize(normalMatrix * normal);
    vec3 lightPosition = vec3(0.0, 0.0, 1.0);
    vec4 diffuseColor = vec4(1.0, 1.0, 1.0, 1.0);
    
    float nDotVP = max(0.0, dot(eyeNormal, normalize(lightPosition)));
                 
    vColor = diffuseColor * nDotVP * color;
    
    vTexcoord.xy = texpos.xy + texcoord0.xy*texpos.zw;
    
    vClipBottomLeft = (projectionMatrix * uClipMatrix*vec4(uClipOrigin.xy, 0, 1)).xy;
    mediump vec2 clipTopRight = uClipOrigin.xy+uClipSize.xy;
    vClipTopRight = (projectionMatrix * uClipMatrix*vec4(clipTopRight.xy, 0, 1)).xy;
    vClipPos = (projectionMatrix * modelViewMatrix * position).xy;

    gl_Position = projectionMatrix * modelViewMatrix * position;
}
