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

//mediump float offx = 1.0/768.0;
//mediump float offy = 1.0/1024.0;
//
//mediump vec4 weight_base = vec4(0.75, 0.75, 0.75, 0.75);
//mediump vec4 weight_blur = vec4(0.25, 0.25, 0.25, 0.75);

void main()
{
//    mediump vec4 base = colorVarying * texture2D(tex, texcoord) * weight_base;
//    
//    mediump vec4 basepp = texture2D(tex, vec2(texcoord.s+offx, texcoord.t+offy)) * weight_blur;
//    mediump vec4 basepm = texture2D(tex, vec2(texcoord.s+offx, texcoord.t-offy)) * weight_blur;
//    mediump vec4 basemm = texture2D(tex, vec2(texcoord.s-offx, texcoord.t-offy)) * weight_blur;
//    mediump vec4 basemp = texture2D(tex, vec2(texcoord.s-offx, texcoord.t+offy)) * weight_blur;
//
//    gl_FragColor = base + basepp + basepm + basemm + basemp;

    gl_FragColor = colorVarying * texture2D(tex, texcoord);
}
