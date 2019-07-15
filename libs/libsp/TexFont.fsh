//
//  Shader.fsh
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

varying lowp vec4 vColor;
varying lowp vec2 vTexcoord;
varying mediump vec2 vClipOrigin;
varying mediump vec2 vClipSize;
varying mediump vec2 vClipPos;

uniform sampler2D texture;
uniform lowp int enableClip;


void main()
{
    // clip
    if(enableClip == 1 &&
       (vClipPos.x < vClipOrigin.x || vClipPos.x > vClipSize.x ||
        vClipPos.y < vClipOrigin.y || vClipPos.y > vClipSize.y))
        discard;
    
    // gl_FragColor = vec4(abs(vClipPos.x), abs(vClipPos.y), 0, 1);
    // gl_FragColor = vec4(abs(gl_FragCoord.x), abs(gl_FragCoord.y), 0, 1);

    gl_FragColor = vColor * texture2D(texture, vTexcoord) * vec4(0.75, 0.5, 0.0, 1.0);
}
