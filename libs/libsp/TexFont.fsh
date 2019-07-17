//
//  Shader.fsh
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

varying lowp vec4 vColor;
varying lowp vec2 vTexcoord;

varying mediump vec2 vClipBottomLeft;
varying mediump vec2 vClipTopRight;
varying mediump vec2 vClipPos;

uniform sampler2D uTexture;
uniform lowp int uEnableClip;


void main()
{
    // clip
    if(uEnableClip == 1 &&
       (vClipPos.x < vClipBottomLeft.x || vClipPos.x > vClipTopRight.x ||
        vClipPos.y < vClipBottomLeft.y || vClipPos.y > vClipTopRight.y))
        discard;
    
    gl_FragColor = vColor * texture2D(uTexture, vTexcoord) * vec4(0.75, 0.5, 0.0, 1.0);
}
