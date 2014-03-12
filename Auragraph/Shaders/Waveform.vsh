//
//  Shader.vsh
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

attribute vec3 normal;
attribute vec4 color;
attribute float positionX;
attribute float positionY;

varying lowp vec4 colorVarying;

uniform mat4 modelViewProjectionMatrix;
uniform mat3 normalMatrix;
uniform float positionZ;

#define M_PI 3.1415926535897932384626433832795

void main()
{
//    vec4 position = vec4(positionX, sin(positionX*2.0*M_PI), positionZ, 1.0);
    vec4 position = vec4(positionX, positionY, positionZ, 1.0);
    vec3 eyeNormal = normalize(normalMatrix * normal);
    vec3 lightPosition = vec3(0.0, 0.0, 1.0);
    vec4 diffuseColor = vec4(1.0, 1.0, 1.0, 1.0);
    
    float nDotVP = max(0.0, dot(eyeNormal, normalize(lightPosition)));
                 
    colorVarying = diffuseColor * nDotVP * color;
    
    gl_Position = modelViewProjectionMatrix * position;
    //gl_Position = vec4(0, 0, 0, 1);
}

