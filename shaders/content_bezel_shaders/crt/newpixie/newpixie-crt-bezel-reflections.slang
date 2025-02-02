#version 450

/*
   Uborder-bezels-reflections shader - Hyllian 2025.

   Bezels code is a modified version of this shadertoy: https://www.shadertoy.com/view/XdtfzX
*/


// newpixie CRT
// by Mattias Gustavsson
// adapted for slang by hunterk

/*
------------------------------------------------------------------------------
This software is available under 2 licenses - you may choose the one you like.
------------------------------------------------------------------------------
ALTERNATIVE A - MIT License
Copyright (c) 2016 Mattias Gustavsson
Permission is hereby granted, free of charge, to any person obtaining a copy of 
this software and associated documentation files (the "Software"), to deal in 
the Software without restriction, including without limitation the rights to 
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
of the Software, and to permit persons to whom the Software is furnished to do 
so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
SOFTWARE.
------------------------------------------------------------------------------
ALTERNATIVE B - Public Domain (www.unlicense.org)
This is free and unencumbered software released into the public domain.
Anyone is free to copy, modify, publish, use, compile, sell, or distribute this 
software, either in source code form or as a compiled binary, for any purpose, 
commercial or non-commercial, and by any means.
In jurisdictions that recognize copyright laws, the author or authors of this 
software dedicate any and all copyright interest in the software to the public 
domain. We make this dedication for the benefit of the public at large and to 
the detriment of our heirs and successors. We intend this dedication to be an 
overt act of relinquishment in perpetuity of all present and future rights to 
this software under copyright law.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN 
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------
*/

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OutputSize;
	vec4 OriginalSize;
	uint FrameCount;
//	float use_frame;
	float curvature;
	float wiggle_toggle;
 	float scanroll;
	float vignette;
	float ghosting;
} params;


layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
    uint Rotation;

    float all_zoom;

    float fr_zoom;
    float fr_aspect_x;
    float fr_aspect_y;
    float fr_center_x;
    float fr_center_y;
    float fr_i_scaling;
    float fr_i_scaling_fac;

    float h_shape;
    float h_radius;
    float h_cornersize;
    float h_cornersmooth;
    float h_overscan_x;
    float h_overscan_y;
    float h_angle_x;
    float h_angle_y;
    float h_curvature;

    float bz_shine_enable;
    float bz_shine;
    float bz_shine_size;
    float bz_ambient_enable;
    float bz_ambient;
    float bz_ambient_size;
    float bz_ref_str;
    float bz_lights;
    float bz_transparent;
    float bz_inner_bezel_x;
    float bz_inner_bezel_y;
    float bz_middle_bezel_x;
    float bz_middle_bezel_y;
    float bz_outer_bezel_x;
    float bz_outer_bezel_y;
    float bz_outer_curve;
    float bz_ref_dist;
    float bz_radius;
    float bz_red;
    float bz_green;
    float bz_blue;
    float bz_ang;
    float bz_pos;

    float border_scale;
    float border_center_x;
    float border_center_y;
    float border_mirror_y;
    float border_allow_rot;
    float ub_border_top;
    float border_alpha;
    float black_baoc;
} global;

#define USE_BEZEL_REFLECTIONS_COMMON

#include "../../include/uborder_bezel_reflections_params.inc"

#define ub_OutputSize     params.OutputSize
#define ub_OriginalSize   params.OriginalSize
#define ub_Rotation       global.Rotation

#include "../../include/uborder_bezel_reflections_common.inc"

//#pragma parameter use_frame "Use Frame Image" 0.0 0.0 1.0 1.0
//#define use_frame params.use_frame
#pragma parameter curvature "Curvature" 0.0001 0.0001 4.0 0.25
#pragma parameter wiggle_toggle "Interference" 0.0 0.0 1.0 1.0
#pragma parameter scanroll "Rolling Scanlines" 1.0 0.0 1.0 1.0
#pragma parameter vignette "Vignette" 1.0 0.0 1.0 0.05
#pragma parameter ghosting "Ghosting" 1.0 0.0 2.0 0.10

//#define resolution (params.OutputSize.xy)
#define resolution (params.OutputSize.xy*fr_scale)

//#define gl_FragCoord (vTexCoord.xy * params.OutputSize.xy)
#define gl_FragCoord (mix(vTex.xy, uv2.xy, global.h_curvature) * resolution)


#define backbuffer accum1
#define blurbuffer blur2
//#define frametexture frametexture

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 uv;
layout(location = 2) out vec2 border_uv;
layout(location = 3) out vec2 vTexOri;

void main()
{
   gl_Position = global.MVP * Position;
   vec2 vTexOri = TexCoord.xy * vec2(1.000001);

    vec2 diff = vTexOri - middle;
    vTexCoord = middle + diff/fr_scale - fr_center;

    uv           = 2.0*vTexCoord - 1.0;

    border_uv = get_unrotated_coords(get_unrotated_coords(TexCoord.xy, ub_Rotation), int(global.border_allow_rot));

    border_uv.y = mix(border_uv.y, 1.0-border_uv.y, border_mirror_y);

    border_uv = middle + (border_uv.xy - middle - border_pos) / (global.border_scale*all_zoom);

    border_uv = border_uv.xy * vec2(1.000001);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec2 border_uv;
layout(location = 3) in vec2 vTexOri;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D accum1;
layout(set = 0, binding = 4) uniform sampler2D blur2;
layout(set = 0, binding = 5) uniform sampler2D BORDER;

// Why 'resolution' if you don't need!? :P
//vec3 tsample( sampler2D samp, vec2 tc, float offs, vec2 resolution )
vec3 tsample( sampler2D samp, vec2 tc, float offs )
    {
    tc = tc * vec2(1.025, 0.92) + vec2(-0.0125, 0.04);
//    vec3 s = pow( abs( texture( samp, vec2( tc.x, 1.0-tc.y ) ).rgb), vec3( 2.2 ) );
    vec3 s = pow( abs( texture( samp, vec2( tc.x, tc.y ) ).rgb), vec3( 2.2 ) ); // invert y dimension.
    return s*vec3(1.25);
    }
		
vec3 filmic( vec3 LinearColor )
    {
    vec3 x = max( vec3(0.0), LinearColor-vec3(0.004));
    return (x*(6.2*x+0.5))/(x*(6.2*x+1.7)+0.06);
    }
		
vec2 curve( vec2 uv )
    {
    uv = (uv - 0.5);// * 2.0;
//    uv.x *= 0.75;
    uv *= vec2(0.925, 1.095);  
   uv *= params.curvature;
    uv.x *= 1.0 + pow((abs(uv.y) / 4.0), 2.0);
    uv.y *= 1.0 + pow((abs(uv.x) / 3.0), 2.0);
    uv /= params.curvature;
    uv  += 0.5;
    uv =  uv *0.92 + 0.04;
    return uv;
    }
/* Uborder already has this exactly function.		
float rand(vec2 co)
    {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
    }
  */

vec3 get_content(vec2 vTex, vec2 uv2)
{
    // stop time variable so the screen doesn't wiggle
   float time = mod(params.FrameCount, 849.0) *36.;
//    vec2 uv = vTexCoord.xy;
    vec2 uv = vTex.xy;
    /* Curve */
    vec2 curved_uv = mix( curve( uv ), uv, 0.4 );
    float scale = -0.101;
    vec2 scuv = curved_uv*(1.0-scale)+scale/2.0+vec2(0.003, -0.001);
    
    uv = scuv;
		
    /* Main color, Bleed */
    vec3 col;
    float x = params.wiggle_toggle* sin(0.1*time+curved_uv.y*13.0)*sin(0.23*time+curved_uv.y*19.0)*sin(0.3+0.11*time+curved_uv.y*23.0)*0.0012;
    float o =sin(gl_FragCoord.y*1.5)/resolution.x;
    x+=o*0.25;
   // make time do something again
//   time = float(mod(params.FrameCount, 640) * 1); 
   time = -float(mod(params.FrameCount, 640) * 1); // roll scanlines downward. 
    col.r = tsample(backbuffer,vec2(x+scuv.x+0.0009,scuv.y+0.0009),resolution.y/800.0 ).x+0.02;
    col.g = tsample(backbuffer,vec2(x+scuv.x+0.0000,scuv.y-0.0011),resolution.y/800.0 ).y+0.02;
    col.b = tsample(backbuffer,vec2(x+scuv.x-0.0015,scuv.y+0.0000),resolution.y/800.0 ).z+0.02;
    float i = clamp(col.r*0.299 + col.g*0.587 + col.b*0.114, 0.0, 1.0 );
    i = pow( 1.0 - pow(i,2.0), 1.0 );
    i = (1.0-i) * 0.85 + 0.15; 
    
    /* Ghosting */
    float ghs = 0.15 * params.ghosting;
    vec3 r = tsample(blurbuffer, vec2(x-0.014*1.0, -0.027)*0.85+0.007*vec2( 0.35*sin(1.0/7.0 + 15.0*curved_uv.y + 0.9*time), 
        0.35*sin( 2.0/7.0 + 10.0*curved_uv.y + 1.37*time) )+vec2(scuv.x+0.001,scuv.y+0.001),
        5.5+1.3*sin( 3.0/9.0 + 31.0*curved_uv.x + 1.70*time)).xyz*vec3(0.5,0.25,0.25);
    vec3 g = tsample(blurbuffer, vec2(x-0.019*1.0, -0.020)*0.85+0.007*vec2( 0.35*cos(1.0/9.0 + 15.0*curved_uv.y + 0.5*time), 
        0.35*sin( 2.0/9.0 + 10.0*curved_uv.y + 1.50*time) )+vec2(scuv.x+0.000,scuv.y-0.002),
        5.4+1.3*sin( 3.0/3.0 + 71.0*curved_uv.x + 1.90*time)).xyz*vec3(0.25,0.5,0.25);
    vec3 b = tsample(blurbuffer, vec2(x-0.017*1.0, -0.003)*0.85+0.007*vec2( 0.35*sin(2.0/3.0 + 15.0*curved_uv.y + 0.7*time), 
        0.35*cos( 2.0/3.0 + 10.0*curved_uv.y + 1.63*time) )+vec2(scuv.x-0.002,scuv.y+0.000),
        5.3+1.3*sin( 3.0/7.0 + 91.0*curved_uv.x + 1.65*time)).xyz*vec3(0.25,0.25,0.5);
		
    col += vec3(ghs*(1.0-0.299))*pow(clamp(vec3(3.0)*r,vec3(0.0),vec3(1.0)),vec3(2.0))*vec3(i);
    col += vec3(ghs*(1.0-0.587))*pow(clamp(vec3(3.0)*g,vec3(0.0),vec3(1.0)),vec3(2.0))*vec3(i);
    col += vec3(ghs*(1.0-0.114))*pow(clamp(vec3(3.0)*b,vec3(0.0),vec3(1.0)),vec3(2.0))*vec3(i);
		
    /* Level adjustment (curves) */
    col *= vec3(0.95,1.05,0.95);
    col = clamp(col*1.3 + 0.75*col*col + 1.25*col*col*col*col*col,vec3(0.0),vec3(10.0));
		
    /* Vignette */
    float vig = ((1.0-0.99*params.vignette) + 1.0*16.0*curved_uv.x*curved_uv.y*(1.0-curved_uv.x)*(1.0-curved_uv.y));
    vig = 1.3*pow(vig,0.5);
    col *= vig;
    
    time *= params.scanroll;
		
    /* Scanlines */
    float scans = clamp( 0.35+0.18*sin(6.0*time-curved_uv.y*resolution.y*1.5), 0.0, 1.0);
    float s = pow(scans,0.9);
    col = col * vec3(s);
		
    /* Vertical lines (shadow mask) */
    col*=1.0-0.23*(clamp((mod(gl_FragCoord.xy.x, 3.0))/2.0,0.0,1.0));

    /* Tone map */
    col = filmic( col );
		
    /* Noise */
    /*vec2 seed = floor(curved_uv*resolution.xy*vec2(0.5))/resolution.xy;*/
    vec2 seed = curved_uv*resolution.xy;
    /* seed = curved_uv; */
    col -= 0.015*pow(vec3(rand( seed +time ), rand( seed +time*2.0 ), rand( seed +time * 3.0 ) ), vec3(1.5) );
		
    /* Flicker */
    col *= (1.0-0.004*(sin(50.0*time+curved_uv.y*2.0)*0.5+0.5));


  // No need for FRAME in this case!		
    /* Clamp */
//    if (curved_uv.x < 0.0 || curved_uv.x > 1.0)
//        col *= 0.0;
//    if (curved_uv.y < 0.0 || curved_uv.y > 1.0)
//        col *= 0.0;

    //uv = curved_uv;
    /* Frame */
    //vec2 fscale = vec2( 0.026, -0.018);//vec2( -0.018, -0.013 );
    //uv = vec2(uv.x, 1.-uv.y);
    //vec4 f=texture(frametexture,vTexCoord.xy);//*((1.0)+2.0*fscale)-fscale-vec2(-0.0, 0.005));
    //f.xyz = mix( f.xyz, vec3(0.5,0.5,0.5), 0.5 );
    //float fvig = clamp( -0.00+512.0*uv.x*uv.y*(1.0-uv.x)*(1.0-uv.y), 0.2, 0.8 );
    //col = mix( col, mix( max( col, 0.0), pow( abs( f.xyz ), vec3( 1.4 ) ) * fvig, f.w * f.w), vec3( use_frame ) );
    
    return col;
}


void main()
{
// Bezels and border begins...

    vec2 uvFC = mix(uv, h_warp(uv), global.h_curvature); // Frame content area
    vec2 uvIB = uvFC;                                    // Inner bezel area
    vec2 uvMB = mix(uv, uvFC, global.bz_outer_curve);    // In Between bezel area
    vec2 uvOB = uvMB;                                    // Outer bezel area

    uvFC = uvFC*overscan - content_position;

    vec2 area_out = RoundedRectVec(vec4(uvMB, uvOB), vec4(MID_BZ, OUT_BZ), bz_r.xx, vec2(SMTH, -SMTH));

    vec4 border = texture(BORDER, border_uv);

    border.rgb *= (bz_lights > 0.5) ? 1.0 : 0.5;
    if (area_out.y < 1.0) {FragColor = vec4(border.rgb, 1.0); return;}

// Bezels pause...

     vec2 fcTex = 0.5*uvFC + 0.5;

    float cval = h_corner(fcTex)  *  step(0.0, fract(fcTex.y));  // Discard off limit pixels

// Call to content shader here.
    vec3 content = get_content(fcTex, uv) * vec3(cval);

// Bezels continue...

    vec2  area_inn      = RoundedRectVec(vec4(uvIB, uvMB), vec4(INN_BZ, MID_BZ), bz_r.xx, vec2(SMTH, -SMTH));

    float out_border    = 1.0 - area_out.y;

    content = mix(content, mix(content.rgb, border.rgb, border.a), global.ub_border_top);

    const float ambient     = bz_ambient;
    const float ambient_out = 1.4*bz_ambient;
    vec3 shine_content      = 0.0.xxx;
    vec3 ambient_content    = 0.0.xxx;

    if (bz_lights == 1.0)
    {
        vec2 rct = RoundedRectVec(vec4(uvIB + bz_shadow, uvIB), INN_BZ.xyxy, bz_r.xx, vec2(-SMTH/2.0, -SMTH));
    	shine_content += max(0.0, bz_shine - shine_size*length(uvIB + shine_position)) * rct.x; // Glass Shine
	ambient_content += max(0.0, ambient - amb_size*length(uvIB)) * rct.y; // Ambient Light
    }
    else
    {
        // Ambient Light
	ambient_content += max(0.0, ambient - amb_size*length(uvIB)) * RoundedRect(uvIB, INN_BZ, bz_r, -SMTH.xx);
    }

    vec3  frame_content = content + (global.bz_ambient_enable*ambient_content + global.bz_shine_enable*shine_content);

    if (area_inn.x < 0.5)
    {
    	float baoc = 1.0 - global.border_alpha*step(dot(content.rgb, 0.333333.xxx), BLVL(1.0 - global.black_baoc));

        FragColor = vec4(mix(border.rgb, mix(border.rgb, frame_content, baoc), 1.0-step(1.0,fcTex.x*fcTex.y)), 1.0);

        return;
    }

    float bezel_inner_area = area_inn.x * area_inn.y;
    float bezel_outer_area = area_out.x * area_out.y;

    vec3 bezels = 0.0.xxx;

    // Inner Bezel Reflection Coords
    vec2 uvR = ReflectionCoords(uvFC, bz_ref_dist);

    vec3 Blur = 0.0.xxx;
    float fsm = 1.0 - fsmoothstep(0.8, 1.0, abs(uvFC.x))*fsmoothstep(0.8, 1.0, abs(uvFC.y));

    for(int i = 0; i < R_BLUR_ITER; i++)
        Blur += texture(Source, uvR + (vec2(rand(uvR+float(i)),rand(uvR+float(i)+0.00625))-0.5)*R_BLUR_SIZE).rgb;

    Blur *= (fsm * bz_ref_str / float(R_BLUR_ITER));

    // This is a hack. Still needs analytical solution.
    vec2 IB = abs(uvIB);
    IB = vec2(IB.x*mb_aspect, IB.y - MID_BZ.y + mb_aspect*MID_BZ.x);
    float corner = fsmoothstep(-bz_r, bz_r, IB.y - mix(IB.x, bz_ang*IB.x + bz_pos, cyl_shape));

    if (global.bz_transparent > 0.5) BZ_COLOR = border.rgb;

    if (bz_lights == 1.0)
    {
        // Bezel texture 
        vec3 bz_color = clamp(BZ_COLOR + rand(uvIB)*0.0125-0.00625, 0.0, 1.0) + 
                                         rand(uvIB+1.0.xx)*0.0625 * cos(0.75*PI*uvIB.x);
        // Inner Bezel and Reflections
        bezels += (bz_color + Blur) * bezel_inner_area * (0.25*(1.0 + corner));

    	// Outer Bezel
   	bezels +=  mix(bz_color, BZ_COLOR, global.bz_transparent) * bezel_outer_area;

    }
    else
    {
        // Middle Bezel
        bezels -= (BZ_COLOR ) * RoundedRect(uvOB, MID_BZ, bz_r, vec2(SMTH*2.0, -SMTH*10.0)) * 
                                RoundedRect(uvOB, MID_BZ, bz_r, vec2(SMTH*2.0, -SMTH* 2.0));

        // Inner Bezel and Reflections
        bezels += (BZ_COLOR + Blur) * bezel_inner_area * (ambient_out * (0.7 + 0.35*(1.0 - corner)) + Blur);

        // Outer Bezel
        bezels += BZ_COLOR * bezel_outer_area * mix(ambient_out, 1.0, global.bz_transparent);

    }

    bezels = mix(bezels+border.rgb*bezel_inner_area*global.bz_transparent, mix(bezels, border.rgb, border.a), global.ub_border_top);

    FragColor = vec4(bezels, 1.0);
}
