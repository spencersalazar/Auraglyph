//
//  Shader.fsh
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

varying lowp vec4 colorVarying;
varying mediump vec2 localPos;

uniform mediump vec2 clipOrigin;
uniform mediump vec2 clipSize;

void main()
{
    // clip
    if(localPos.x < clipOrigin.x || localPos.y < clipOrigin.y ||
       localPos.x > clipOrigin.x+clipSize.x || localPos.y > clipOrigin.y+clipSize.y)
        discard;
    
    gl_FragColor = colorVarying * vec4(0.75, 0.5, 0.0, 1.0);
//    gl_FragColor = colorVarying * vec4(0.0, 1.0, 0.0, 1.0);
}
