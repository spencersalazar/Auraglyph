//
//  Shader.fsh
//  Auragraph
//
//  Created by Spencer Salazar on 8/2/13.
//  Copyright (c) 2013 Spencer Salazar. All rights reserved.
//

varying lowp vec4 colorVarying;
varying lowp vec2 texcoord;

uniform sampler2D tex;

uniform int orderH;
uniform int orderV;
uniform mediump vec2 offset;

//mediump float offx = 2.0/768.0;
//mediump float offy = 2.0/1024.0;

//mediump vec4 weight_base = vec4(0.75, 0.75, 0.75, 0.75);
//mediump vec4 weight_blur = vec4(0.25, 0.25, 0.25, 0.75);

mediump float weight_base_color = 0.75;
mediump float weight_blur_color = 0.25;

void main()
{
    mediump vec4 weight_base = vec4(weight_base_color, weight_base_color, weight_base_color, 0.75);
    mediump vec4 weight_blur = vec4(weight_blur_color, weight_blur_color, weight_blur_color, 0.75);

    mediump vec4 base = colorVarying * texture2D(tex, texcoord) * weight_base;
    
//    mediump vec4 basepp = texture2D(tex, vec2(texcoord.s+offx, texcoord.t+offy)) * weight_blur;
//    mediump vec4 basepm = texture2D(tex, vec2(texcoord.s+offx, texcoord.t-offy)) * weight_blur;
//    mediump vec4 basemm = texture2D(tex, vec2(texcoord.s-offx, texcoord.t-offy)) * weight_blur;
//    mediump vec4 basemp = texture2D(tex, vec2(texcoord.s-offx, texcoord.t+offy)) * weight_blur;
    
    for(int i = -orderH/2; i <= orderH/2; i++)
    {
        for(int j = orderV/2; j <= orderV/2; j++)
        {
            base += texture2D(tex, vec2(texcoord.s+offset.x*float(i), texcoord.t+offset.y*float(j))) * weight_blur;
        }
    }

    gl_FragColor = base;

//    gl_FragColor = colorVarying * texture2D(tex, texcoord);
}
