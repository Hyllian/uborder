#version 450

/*
   CRT - Guest - Advanced
   
   Copyright (C) 2018-2023 guest(r) - guest.r@gmail.com

   Incorporates many good ideas and suggestions from Dr. Venom.
   I would also like give thanks to many Libretro forums members for continuous feedback, suggestions and caring about the shader.
   
   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
   
*/

layout(push_constant) uniform Push
{
	float TATE, IOS, OS, BLOOM, brightboost, brightboost1, gsl, scanline1, scanline2, beam_min, beam_max, beam_size,
	h_sharp, s_sharp, csize, bsize1, warpX, warpY, glow, spike, ring, no_scanlines, tds, clips, ssharp, hiscan;
    float geom_center_x;
    float geom_center_y;
    float box_scale;
    float in_res_x;
    float in_res_y;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float bloom;
	float halation;
	float scans;
	float gamma_c;
	float smart_ei;
	float ei_limit;
	float sth;
	float overscanX;
	float overscanY;
	float c_shape;
	float intres;
	float prescalex;
	float scan_falloff;
	float bloom_dist;
	float scangamma;
	float bmask1;
	float hmask1;

    float geom_d;
    float geom_R;
    float geom_cornersize;
    float geom_cornersmooth;
    float geom_x_tilt;
    float geom_y_tilt;
    float geom_overscan_x;
    float geom_overscan_y;
    float geom_inner_center_x;
    float geom_inner_center_y;
    float geom_curvature;
    float geom_invert_aspect;
} global;


#pragma parameter hiscan "          High Resolution Scanlines (prepend a scaler...)" 0.0 0.0 1.0 1.0
#define hiscan        params.hiscan

#pragma parameter bogus_brightness "[ BRIGHTNESS SETTINGS ]:" 0.0 0.0 1.0 1.0

#pragma parameter glow "          (Magic) Glow Strength" 0.08 -2.0 2.0 0.01
#define glow         params.glow     // Glow Strength

#pragma parameter bloom "          Bloom Strength" 0.0 -2.0 2.0 0.05
#define bloom         global.bloom     // bloom effect

#pragma parameter mask_bloom "          Mask Bloom" 0.0 -2.0 2.0 0.05
#define mask_bloom         params.mask_bloom     // bloom effect

#pragma parameter bloom_dist "          Bloom Distribution" 0.0 -2.0 3.0 0.05
#define bloom_dist         global.bloom_dist     // bloom effect distribution

#pragma parameter halation "          Halation Strength" 0.0 -2.0 2.0 0.025
#define halation         global.halation     // halation effect

#pragma parameter bmask1 "          Bloom Mask Strength" 0.0 -1.0 1.0 0.025
#define bmask1         global.bmask1     // bloom/halation mask strength

#pragma parameter hmask1 "          Halation Mask Strength" 0.5 -1.0 1.0 0.025
#define hmask1         global.hmask1     // bloom/halation mask strength

#pragma parameter gamma_c "          Gamma correct" 1.0 0.50 2.0 0.025
#define gamma_c   global.gamma_c     // adjust brightness

#pragma parameter brightboost "          Bright Boost Dark Pixels" 1.40 0.25 10.0 0.05
#define brightboost  params.brightboost     // adjust brightness

#pragma parameter brightboost1 "          Bright Boost Bright Pixels" 1.10 0.25 3.00 0.025
#define brightboost1  params.brightboost1     // adjust brightness

#pragma parameter clips "          Clip Saturated Color Beams" 0.0 -1.0 1.0 0.05
#define clips  params.clips     // kinky effect

#pragma parameter bogus_scanline "[ SCANLINE OPTIONS ]: " 0.0 0.0 1.0 1.0

#pragma parameter gsl "          Scanline Type" 0.0 -1.0 2.0 1.0
#define gsl          params.gsl      // Alternate scanlines

#pragma parameter scanline1 "          Scanline Beam Shape Center" 6.0 -20.0 40.0 0.5
#define scanline1    params.scanline1      // scanline param, vertical sharpness

#pragma parameter scanline2 "          Scanline Beam Shape Edges" 8.0 0.0 70.0 1.0 
#define scanline2    params.scanline2      // scanline param, vertical sharpness

#pragma parameter beam_min "          Scanline Shape Dark Pixels" 1.30 0.25 10.0 0.05
#define beam_min     params.beam_min     // dark area beam min - narrow

#pragma parameter beam_max "          Scanline Shape Bright Pixels" 1.00 0.2 3.5 0.025
#define beam_max     params.beam_max     // bright area beam max - wide

#pragma parameter tds "          Thinner Dark Scanlines" 0.0 0. 1.0 1.0
#define tds     params.tds     // thinner dark scanlines

#pragma parameter beam_size "          Increased Bright Scanline Beam" 0.60 0.0 1.0 0.05
#define beam_size    params.beam_size     // increased max. beam size

#pragma parameter scans "          Scanline Saturation / Mask Falloff" 0.50 0.0 6.0 0.10
#define scans        1.5*global.scans     // scanline saturation

#pragma parameter scan_falloff "          Scanline Falloff" 1.0 0.10 2.0 0.025
#define scan_falloff        global.scan_falloff     // scanline falloff

#pragma parameter spike "          Scanline Spike Removal" 1.0 0.0 2.0 0.10
#define spike params.spike

#pragma parameter ssharp "          Smart Sharpen Scanlines" 0.0 0.0 0.30 0.01
#define ssharp params.ssharp

#pragma parameter scangamma "          Scanline Gamma" 2.40 0.5 5.0 0.05
#define scangamma global.scangamma

#pragma parameter no_scanlines "          No-scanline mode" 0.0 0.0 1.5 0.05
#define no_scanlines params.no_scanlines

#pragma parameter bogus_filtering "[ FILTERING OPTIONS ]: " 0.0 0.0 1.0 1.0

#pragma parameter h_sharp "          Horizontal sharpness" 5.20 0.20 15.0 0.10
#define h_sharp      params.h_sharp     // pixel sharpness

#pragma parameter s_sharp "          Substractive sharpness (1.0 recommended)" 0.50 0.0 2.0 0.10
#define s_sharp      params.s_sharp     // substractive sharpness

#pragma parameter ring "          Substractive sharpness Ringing" 0.0 0.0 3.0 0.05
#define ring      params.ring     // substractive sharpness ringing

#pragma parameter smart_ei "          Smart Edges Effect Strength" 0.0 0.0 0.75 0.01
#define smart_ei      global.smart_ei     // smart edge handling

#pragma parameter ei_limit "          Smart Edges Effect Strength Limit" 0.25 0.0 0.75 0.01
#define ei_limit      global.ei_limit     // smart edge handling

#pragma parameter sth     "          Smart Edges Smoothing Threshold" 0.23 0.0 1.0 0.01
#define sth        global.sth     // corner size

#pragma parameter bogus_screen "[ SCREEN OPTIONS ]: " 0.0 0.0 1.0 1.0

#pragma parameter intres "          Internal Resolution Y: 0.5...y-dowsample divider" 0.0 0.0 10.0 0.5 // Joint parameter with main pass, values must match

#pragma parameter TATE "          TATE Mode" 0.0 0.0 1.0 1.0
#define TATE         params.TATE     // Screen orientation

#pragma parameter IOS "          Integer Scaling: Odd:Y, Even:'X'+Y" 0.0 0.0 4.0 1.0
#define IOS          params.IOS     // Smart Integer Scaling

#pragma parameter OS "          R. Bloom Overscan Mode" 1.0 0.0 2.0 1.0
#define OS           params.OS     // Do overscan

#pragma parameter BLOOM "          Raster bloom %" 0.0 0.0 20.0 1.0
#define BLOOM        params.BLOOM     // Bloom overscan percentage

#pragma parameter warpX "          CurvatureX (default 0.03)" 0.0 0.0 0.25 0.01
#define warpX        params.warpX     // Curvature X

#pragma parameter warpY "          CurvatureY (default 0.04)" 0.0 0.0 0.25 0.01
#define warpY        params.warpY     // Curvature Y

#pragma parameter c_shape "          Curvature Shape" 0.25 0.05 0.60 0.05
#define c_shape        global.c_shape     // curvature shape

#pragma parameter overscanX "          Overscan X original pixels" 0.0 -200.0 200.0 1.0
#define overscanX        global.overscanX     // OverscanX pixels

#pragma parameter overscanY "          Overscan Y original pixels" 0.0 -200.0 200.0 1.0
#define overscanY        global.overscanY     // OverscanY pixels

#pragma parameter frame_nonono       "FRAME:"                           0.0  0.0 1.0 1.0
#pragma parameter box_scale          "    Image Scale"                  4.0 1.0 10.0 0.02
#pragma parameter in_res_x           "    Viewport Size X"            320.0 100.0 600.0 1.0
#pragma parameter in_res_y           "    Viewport Size Y"            240.0 64.0 512.0 1.0
#pragma parameter geom_center_x      "    Center X"                     0.0 -1.0 1.0 0.001
#pragma parameter geom_center_y      "    Center Y"                     0.0 -1.0 1.0 0.002

#pragma parameter geom_nonono        "GEOM'S CURVATURE:"                0.0  0.0 1.0 1.0
#pragma parameter geom_curvature     "    Curvature Toggle"             0.0 0.0 1.0 1.0
#pragma parameter geom_R             "    Curvature Radius"             2.0 0.3 10.0 0.1
#pragma parameter geom_d             "    Distance"                     1.5 0.1 3.0 0.1
#pragma parameter geom_invert_aspect "    Curvature Aspect Inversion"   0.0 0.0 1.0 1.0
#pragma parameter geom_cornersize    "    Corner Size"                  0.006 0.006 1.0 0.005
#pragma parameter geom_cornersmooth  "    Corner Smoothness"          400.0 80.0 2000.0 100.0
#pragma parameter geom_x_tilt        "    Horizontal Tilt"              0.0 -0.5 0.5 0.01
#pragma parameter geom_y_tilt        "    Vertical Tilt"                0.0 -0.5 0.5 0.01
#pragma parameter geom_inner_center_x "    Inner Center X"              0.0 -1.0 1.0 0.001
#pragma parameter geom_inner_center_y "    Inner Center Y"              0.0 -1.0 1.0 0.001
#pragma parameter geom_overscan_x    "    Horiz. Overscan %"          100.0 -125.0 125.0 0.5
#pragma parameter geom_overscan_y    "    Vert. Overscan %"           100.0 -125.0 125.0 0.5

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define TEX0 vTexCoord

//#define OutputSize global.OutputSize
#define gl_FragCoord (vTexCoord * ScaledOutputSize.xy)

vec2 SOutputSize = vec2(params.in_res_x, params.in_res_y) * params.box_scale;
vec4 ScaledOutputSize = vec4(SOutputSize, 1.0/SOutputSize);

// Macros.
#define FIX(c) max(abs(c), 1e-5);
#define PI 3.141592653589


// aspect ratio
vec2 aspect     = vec2(global.geom_invert_aspect > 0.5 ? (0.75, 1.0) : (1.0, 0.75));
vec2 overscan   = vec2(1.01, 1.01);

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 sinangle;
layout(location = 2) out vec2 cosangle;
layout(location = 3) out vec3 stretch;
layout(location = 4) out float R_d_cx_cy;
layout(location = 5) out float d2;

/*
    Geom code - a modified Geom code without CRT features made to provide
    curvature/warping/oversampling features.

    Adapted by Hyllian (2024).
*/

/*
    Copyright (C) 2010-2012 cgwg, Themaister and DOLLS

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

    (cgwg gave their consent to have the original version of this shader
    distributed under the GPL in this message:

    http://board.byuu.org/viewtopic.php?p=26075#p26075

    "Feel free to distribute my shaders under the GPL. After all, the
    barrel distortion code was taken from the Curvature shader, which is
    under the GPL."
    )
    This shader variant is pre-configured with screen curvature
*/


float intersect(vec2 xy)
{
    float A = dot(xy,xy) + global.geom_d*global.geom_d;
    float B = 2.0 * (global.geom_R * (dot(xy,sinangle) - global.geom_d * cosangle.x * cosangle.y) - global.geom_d * global.geom_d);
    float C = global.geom_d*global.geom_d + 2.0*global.geom_R*global.geom_d*cosangle.x*cosangle.y;
    
    return (-B-sqrt(B*B-4.0*A*C))/(2.0*A);
}

vec2 bkwtrans(vec2 xy)
{
    float c     = intersect(xy);
    vec2 point  = (vec2(c, c)*xy - vec2(-global.geom_R, -global.geom_R)*sinangle) / vec2(global.geom_R, global.geom_R);
    vec2 poc    = point/cosangle;
    
    vec2 tang   = sinangle/cosangle;
    float A     = dot(tang, tang) + 1.0;
    float B     = -2.0*dot(poc, tang);
    float C     = dot(poc, poc) - 1.0;
    
    float a     = (-B + sqrt(B*B - 4.0*A*C))/(2.0*A);
    vec2 uv     = (point - a*sinangle)/cosangle;
    float r     = FIX(global.geom_R*acos(a));
    
    return uv*r/sin(r/global.geom_R);
}

vec2 fwtrans(vec2 uv)
{
    float r = FIX(sqrt(dot(uv,uv)));
    uv *= sin(r/global.geom_R)/r;
    float x = 1.0-cos(r/global.geom_R);
    float D = global.geom_d/global.geom_R + x*cosangle.x*cosangle.y+dot(uv,sinangle);
    
    return global.geom_d*(uv*cosangle-x*sinangle)/D;
}

vec3 maxscale()
{
    vec2 c  = bkwtrans( -global.geom_R * sinangle / (1.0 + global.geom_R / global.geom_d * cosangle.x * cosangle.y) );
    vec2 a  = vec2(0.5,0.5) * aspect;
    
    vec2 lo = vec2(fwtrans(vec2(-a.x,  c.y)).x,
                   fwtrans(vec2( c.x, -a.y)).y)/aspect;

    vec2 hi = vec2(fwtrans(vec2(+a.x,  c.y)).x,
                   fwtrans(vec2( c.x, +a.y)).y)/aspect;
    
    return vec3( (hi + lo) * aspect * 0.5, max(hi.x - lo.x, hi.y - lo.y) );
}

void main()
{
   gl_Position = global.MVP * Position;
//   vTexCoord = TexCoord * 1.00001;

   vec2 corrected_size = vec2(params.in_res_x, params.in_res_y);
   vec2 scale = (global.OutputSize.xy / corrected_size) / params.box_scale;
   vec2 middle = vec2(params.geom_center_x, params.geom_center_y) + vec2(0.5, 0.5);
   vec2 diff = TexCoord.xy - middle;
   vTexCoord = middle + diff * scale;

    sinangle    = sin(vec2(global.geom_x_tilt, global.geom_y_tilt));
    cosangle    = cos(vec2(global.geom_x_tilt, global.geom_y_tilt));
    stretch     = maxscale();

    d2        = global.geom_d * global.geom_d;
    R_d_cx_cy = global.geom_R * global.geom_d * cosangle.x * cosangle.y;
}



#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 sinangle;
layout(location = 2) in vec2 cosangle;
layout(location = 3) in vec3 stretch;
layout(location = 4) in float R_d_cx_cy;
layout(location = 5) in float d2;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D LinearizePass;
layout(set = 0, binding = 3) uniform sampler2D AvgLumPass;
layout(set = 0, binding = 4) uniform sampler2D PrePass;

#define eps 1e-10 

float st(float x)
{
	return exp2(-10.0*x*x);
} 
   
vec3 sw0(float x, float color, float scanline, vec3 c)
{
	float tmp = mix(beam_min, beam_max, color);
	vec3 sat = mix(1.0.xxx + scans, 1.0.xxx, c);
	float ex = x*tmp;
	ex = (gsl > -0.5) ? ex*ex : mix(ex*ex, ex*ex*ex, 0.4);
	return exp2(-scanline*ex*sat);
} 

vec3 sw1(float x, float color, float scanline, vec3 c)
{	
	x = mix (x, beam_min*x, max(x-0.4*color,0.0));
	vec3 sat = mix(1.0.xxx + scans, 1.0.xxx, c);	
	float tmp = mix(1.2*beam_min, beam_max, color);
	float ex = x*tmp;
	return exp2(-scanline*ex*ex*sat);
}    

vec3 sw2(float x, float color, float scanline, vec3 c)
{
	float tmp = mix((2.5-0.5*color)*beam_min, beam_max, color);
	vec3 sat = mix(1.0.xxx + scans, 1.0.xxx, c);	
	tmp = mix(beam_max, tmp, pow(x, color+0.3));
	float ex = x*tmp;
	return exp2(-scanline*ex*ex*sat);
}   

 
vec2 Warp(vec2 pos)
{
	pos  = pos*2.0-1.0;    
	pos  = mix(pos, vec2(pos.x*inversesqrt(1.0-c_shape*pos.y*pos.y), pos.y*inversesqrt(1.0-c_shape*pos.x*pos.x)), vec2(warpX, warpY)/c_shape);
	return pos*0.5 + 0.5;
}

vec2 Overscan(vec2 pos, float dx, float dy){
	pos=pos*2.0-1.0;    
	pos*=vec2(dx,dy);
	return pos*0.5+0.5;
} 


vec3 gc(vec3 c)
{
	float mc = max(max(c.r,c.g),c.b);
	float mg = pow(mc, 1.0/gamma_c);
	return c * mg/(mc + eps);  
}

vec3 plant (vec3 tar, float r)
{
	float t = max(max(tar.r,tar.g),tar.b) + 0.00001;
	return tar * r / t;
}


vec2 transform(vec2 coord)
{
    coord = (coord - vec2(0.5, 0.5) - vec2(global.geom_inner_center_x, global.geom_inner_center_y)) * aspect * stretch.z + stretch.xy;
  //  coord = (coord - vec2(0.5, 0.5)) * aspect * stretch.z + stretch.xy;

    float A = dot(coord, coord) + d2;
    float B = 2.0 * ( global.geom_R * dot(coord, sinangle) - R_d_cx_cy - d2);
    float C = d2 + 2.0 * R_d_cx_cy;
    
    float c     = (-B - sqrt(B*B - 4.0*A*C)) / (2.0*A);

    vec2 point  = (vec2(c, c) * coord - vec2(-global.geom_R, -global.geom_R) * sinangle) / vec2(global.geom_R, global.geom_R);
    vec2 poc    = point / cosangle;
    
    vec2 tang   = sinangle / cosangle;
    A     = dot(tang, tang) + 1.0;
    B     = -2.0 * dot(poc, tang);
    C     = dot(poc, poc) - 1.0;
    
    float a     = (-B + sqrt(B*B - 4.0*A*C))/(2.0*A);
    vec2 uv     = (point - a*sinangle)/cosangle;
    float r     = FIX(global.geom_R*acos(a));
    
    vec2 bkw = uv*r/sin(r/global.geom_R);

    return (bkw / vec2(global.geom_overscan_x / 100.0, global.geom_overscan_y / 100.0)/aspect + vec2(0.5, 0.5));
}

float geom_corner(vec2 coord)
{
    coord = (coord - vec2(0.5, 0.5) + vec2(global.geom_inner_center_x, global.geom_inner_center_y)) * vec2(global.geom_overscan_x / 100.0, global.geom_overscan_y / 100.0) + vec2(0.5, 0.5);

   // coord = (coord - vec2(0.5, 0.5)) * vec2(params.geom_overscan_x / 100.0, params.geom_overscan_y / 100.0) + vec2(0.5, 0.5);

    coord = min(coord, vec2(1.0) - coord) * aspect;
    vec2 cdist = vec2(global.geom_cornersize);
    coord = (cdist - min(coord, cdist));
    float dist = sqrt(dot(coord, coord));
    
      return clamp((cdist.x - dist)*global.geom_cornersmooth, 0.0, 1.0);
}

void main()
{
    float draw = step(max(vTexCoord.x, vTexCoord.y), 1.0) * step(0.0, min(vTexCoord.x, vTexCoord.y));

    if (draw < 0.5) discard;

	vec2 prescalex = vec2(vec2(textureSize(LinearizePass, 0))/global.OriginalSize.xy);
	
	vec4 SourceSize = global.OriginalSize * mix( vec4(prescalex.x, 1.0, 1.0/prescalex.x, 1.0), vec4(1.0, prescalex.y, 1.0, 1.0/prescalex.y), TATE);
	
	float lum = COMPAT_TEXTURE(AvgLumPass, vec2(0.5,0.5)).a;
	
	float gamma_in = 1.0/COMPAT_TEXTURE(LinearizePass, vec2(0.25,0.25)).a;
	float intera = COMPAT_TEXTURE(LinearizePass, vec2(0.75,0.25)).a;
	bool hscan = (hiscan > 0.5);
	bool interb  = (((intera < 0.35) || (no_scanlines > 0.025)) && !hscan);
	bool notate  = (TATE < 0.5);
	bool vgascan = ((abs(intera-0.5) < 0.05) && (no_scanlines == 0.0));

	float SourceY = mix(SourceSize.y, SourceSize.x, TATE);
	
	float sy = 1.0;
	if (global.intres == 1.0) sy = max(round(SourceY/224.0),1.0);
	if (global.intres > 0.25 && global.intres != 1.0) sy = global.intres;
	
	// VGA Scan Mode
	if (vgascan) sy = 0.5; else if (abs(intera-0.75) < 0.05) sy = 1.0;
	
	if (notate) SourceSize*=vec4(1.0, 1.0/sy, 1.0, sy); else SourceSize*=vec4(1.0/sy, 1.0, sy, 1.0);
	
	// Calculating texel coordinates
   
    vec2  uv   = TEX0.xy;
    float cval = 1.0;

    if (global.geom_curvature > 0.5)
    {
        uv  = transform(uv);
    }
    else
    {
        uv -= vec2(global.geom_inner_center_x, global.geom_inner_center_y);
    }

    cval = geom_corner(uv)  *  step(0.0, fract(uv.y));  // Discard off limit pixels

//	vec2 texcoord = TEX0.xy;
	vec2 texcoord = uv.xy;
	if (IOS > 0.0 && !interb){
		vec2 ofactor = ScaledOutputSize.xy/global.OriginalSize.xy;
		vec2 intfactor = (IOS < 2.5) ? floor(ofactor) : ceil(ofactor);
		vec2 diff = ofactor/intfactor;
		float scan = mix(diff.y, diff.x, TATE);
		texcoord = Overscan(texcoord, scan, scan);
		if (IOS == 1.0 || IOS == 3.0) texcoord = mix(vec2(uv.x, texcoord.y), vec2(texcoord.x, uv.y), TATE);
	}
   
	float factor  = 1.00 + (1.0-0.5*OS)*BLOOM/100.0 - lum*BLOOM/100.0;
	texcoord  = Overscan(texcoord, factor, factor);

	texcoord = Overscan(texcoord, (global.OriginalSize.x - overscanX)/global.OriginalSize.x, (global.OriginalSize.y - overscanY)/global.OriginalSize.y);

//	vec2 pos  = Warp(texcoord);
	vec2 pos  = Warp(uv.xy);
   
	bool smarte  = (smart_ei > 0.01 && notate); // smart edge interpolation on / off

	vec2 coffset = vec2(0.5, 0.5);
	
	vec2 ps = SourceSize.zw;
	vec2 OGL2Pos = pos * SourceSize.xy - coffset;
	vec2 fp = fract(OGL2Pos);
	
	vec2 dx = vec2(ps.x,0.0);
	vec2 dy = vec2(0.0, ps.y);
   
	// Reading the texels
	vec2 x2 = 2.0*dx;
	vec2 y2 = 2.0*dy;

	vec2 offx = dx;
	vec2 off2 = x2;
	vec2 offy = dy;
	float fpx = fp.x;
	if(!notate)
	{
		offx = dy;
		off2 = y2;
		offy = dx;
		fpx = fp.y;
	}
	float  f = (notate) ? fp.y : fp.x;
	
	vec2 pC4 = floor(OGL2Pos) * ps + 0.5*ps; 
	
	if ((global.intres == 0.5 &&  notate && prescalex.y < 1.5) || vgascan) pC4.y = floor(pC4.y * global.OriginalSize.y)*global.OriginalSize.w + 0.5*global.OriginalSize.w;
	if ((global.intres == 0.5 && !notate && prescalex.x < 1.5) || (vgascan && !notate)) pC4.x = floor(pC4.x * global.OriginalSize.x)*global.OriginalSize.z + 0.5*global.OriginalSize.z;
	
	if (interb && no_scanlines < 0.025 && !hscan)  pC4.y = pos.y; else if (interb) pC4.y = pC4.y + smoothstep(0.40-0.5*no_scanlines, 0.60 + 0.5*no_scanlines, f)*mix(SourceSize.w, SourceSize.z, TATE);
	if (hscan) pC4 = mix(vec2(pC4.x, pos.y), vec2(pos.x, pC4.y), TATE);
	
	float zero = exp2(-h_sharp);
	float sharp1 = s_sharp * zero;
	
	float idiv = clamp(mix(SourceSize.x, SourceSize.y, TATE) / 400.0, 1.0, 2.0);
	float fdivider = max(min(mix(prescalex.x, prescalex.y, TATE), 2.0), idiv*float(interb));
	fdivider = 1.0/max(fdivider, 1.0);
	
	float wl3 = (2.0 + fpx)*fdivider;
	float wl2 = (1.0 + fpx)*fdivider;
	float wl1 = (      fpx)*fdivider;
	float wr1 = (1.0 - fpx)*fdivider;
	float wr2 = (2.0 - fpx)*fdivider;
	float wr3 = (3.0 - fpx)*fdivider;

	wl3*=wl3; wl3 = exp2(-h_sharp*wl3);
	wl2*=wl2; wl2 = exp2(-h_sharp*wl2);
	wl1*=wl1; wl1 = exp2(-h_sharp*wl1);
	wr1*=wr1; wr1 = exp2(-h_sharp*wr1);
	wr2*=wr2; wr2 = exp2(-h_sharp*wr2);
	wr3*=wr3; wr3 = exp2(-h_sharp*wr3);
	
	float fp1 = 1.-fpx;

	float twl3 = max(wl3 - sharp1, 0.0);
	float twl2 = max(wl2 - sharp1, mix(-0.12, 0.0, 1.0-fp1*fp1));
	float twl1 = max(wl1 - sharp1, -0.12);
	float twr1 = max(wr1 - sharp1, -0.12);
	float twr2 = max(wr2 - sharp1, mix(-0.12, 0.0, 1.0-fpx*fpx));
	float twr3 = max(wr3 - sharp1, 0.0);
	
	bool sharp = (sharp1 > 0.0);

	vec3 c1, c2;
	
	if (smarte)
	{
		twl3 = 0.0; twr3 = 0.0;
		c1 = COMPAT_TEXTURE(AvgLumPass, pC4       ).xyz;		
		c2 = COMPAT_TEXTURE(AvgLumPass, pC4 + offy).xyz;
		c1 = max(c1 - sth, 0.0);
		c2 = max(c2 - sth, 0.0);
	}
	
	vec3 l3, l2, l1, r1, r2, r3, color1, color2, colmin, colmax;

	l3 = COMPAT_TEXTURE(LinearizePass, pC4 -off2).rgb;
	l2 = COMPAT_TEXTURE(LinearizePass, pC4 -offx).rgb;
	l1 = COMPAT_TEXTURE(LinearizePass, pC4      ).rgb;
	r1 = COMPAT_TEXTURE(LinearizePass, pC4 +offx).rgb;
	r2 = COMPAT_TEXTURE(LinearizePass, pC4 +off2).rgb;
	r3 = COMPAT_TEXTURE(LinearizePass, pC4 +offx+off2).rgb;

	colmin = min(min(l1,r1), min(l2,r2));
	colmax = max(max(l1,r1), max(l2,r2));
	
	if (smarte)
	{	
		float pc = min(smart_ei*c1.y, ei_limit);
		float pl = min(smart_ei*max(c1.y,c1.x), ei_limit);
		float pr = min(smart_ei*max(c1.y,c1.z), ei_limit);
		twl1 = max(wl1-pc, 0.01*wl1); twr1 = max(wr1-pc, 0.01*wr1);
		twl2 = max(wl2-pl, 0.01*wl2); twr2 = max(wr2-pr, 0.01*wr2);
	}
	
	color1 = (l3*twl3 + l2*twl2 + l1*twl1 + r1*twr1 + r2*twr2 + r3*twr3)/(twl3+twl2+twl1+twr1+twr2+twr3);

	if (sharp) color1 = clamp(mix(clamp(color1, colmin, colmax), color1, ring), 0.0, 1.0);
	float ts = 0.025;
	vec3 luma = vec3(0.2126, 0.7152, 0.0722);
	
	float lm2 = max(max(l2.r,l2.g),l2.b);
	float lm1 = max(max(l1.r,l1.g),l1.b);
	float rm1 = max(max(r1.r,r1.g),r1.b);
	float rm2 = max(max(r2.r,r2.g),r2.b);	
	
	float swl2 = max(twl2, 0.0) * (dot(l2,luma) + ts);
	float swl1 = max(twl1, 0.0) * (dot(l1,luma) + ts);
	float swr1 = max(twr1, 0.0) * (dot(r1,luma) + ts);
	float swr2 = max(twr2, 0.0) * (dot(r2,luma) + ts);
	
	float fscolor1 = (lm2*swl2 + lm1*swl1 + rm1*swr1 + rm2*swr2)/(swl2+swl1+swr1+swr2);
	vec3 scolor1 = vec3(clamp(mix(max(max(color1.r,color1.g),color1.b), fscolor1, spike), 0.0, 1.0));

	if(!interb) color1 = pow(color1, vec3(scangamma/gamma_in));
	
	vec3 scolor2;
	
	if (!interb && !hscan)
{	
	pC4+=offy;

	if ((global.intres == 0.5 &&  notate && prescalex.y < 1.5) || vgascan) pC4.y = floor((pos.y + 0.33*offy.y) * global.OriginalSize.y)*global.OriginalSize.w + 0.5*global.OriginalSize.w;
	if ((global.intres == 0.5 && !notate && prescalex.x < 1.5) || (vgascan && !notate)) pC4.x = floor((pos.x + 0.33*offy.x) * global.OriginalSize.x)*global.OriginalSize.z + 0.5*global.OriginalSize.z;
	
	l3 = COMPAT_TEXTURE(LinearizePass, pC4 -off2).rgb;
	l2 = COMPAT_TEXTURE(LinearizePass, pC4 -offx).rgb;
	l1 = COMPAT_TEXTURE(LinearizePass, pC4      ).rgb;
	r1 = COMPAT_TEXTURE(LinearizePass, pC4 +offx).rgb;
	r2 = COMPAT_TEXTURE(LinearizePass, pC4 +off2).rgb;
	r3 = COMPAT_TEXTURE(LinearizePass, pC4 +offx+off2).rgb;

	colmin = min(min(l1,r1), min(l2,r2));
	colmax = max(max(l1,r1), max(l2,r2));
	
	if (smarte)
	{	
		float pc = min(smart_ei*c2.y, ei_limit);
		float pl = min(smart_ei*max(c2.y,c2.x), ei_limit);
		float pr = min(smart_ei*max(c2.y,c2.z), ei_limit);
		twl1 = max(wl1-pc, 0.01*wl1); twr1 = max(wr1-pc, 0.01*wr1);
		twl2 = max(wl2-pl, 0.01*wl2); twr2 = max(wr2-pr, 0.01*wr2);
	}
	
	color2 = (l3*twl3 + l2*twl2 + l1*twl1 + r1*twr1 + r2*twr2 + r3*twr3)/(twl3+twl2+twl1+twr1+twr2+twr3);
	
	if (sharp) color2 = clamp(mix(clamp(color2, colmin, colmax), color2, ring), 0.0, 1.0);

	lm2 = max(max(l2.r,l2.g),l2.b);
	lm1 = max(max(l1.r,l1.g),l1.b);
	rm1 = max(max(r1.r,r1.g),r1.b);
	rm2 = max(max(r2.r,r2.g),r2.b);
	
	swl2 = max(twl2, 0.0) * (dot(l2,luma) + ts);
	swl1 = max(twl1, 0.0) * (dot(l1,luma) + ts);
	swr1 = max(twr1, 0.0) * (dot(r1,luma) + ts);
	swr2 = max(twr2, 0.0) * (dot(r2,luma) + ts);
	
	float fscolor2 = (lm2*swl2 + lm1*swl1 + rm1*swr1 + rm2*swr2)/(swl2+swl1+swr1+swr2);
	scolor2 = vec3(clamp(mix(max(max(color2.r,color2.g),color2.b), fscolor2, spike), 0.0, 1.0));
	
	color2 = pow(color2, vec3(scangamma/gamma_in)); 
	
}

	vec3 ctmp = color1; float w3 = 1.0; vec3 color = color1;
	vec3 one = vec3(1.0);

	if (hscan) { color2 = color1; scolor2 = scolor1; }

if (!interb)
{	
	// calculating scanlines

	float ssub = ssharp*max(abs(scolor1.x-scolor2.x), abs(dot(color1,luma)-dot(color2,luma)));

	float shape1 = mix(scanline1, scanline2 + ssub * scolor1.x * 35.0, f);
	float shape2 = mix(scanline1, scanline2 + ssub * scolor2.x * 35.0, 1.0-f);
	
	float wt1 = st(f);
	float wt2 = st(1.0-f);

	vec3 color00 = color1*wt1 + color2*wt2;
	vec3 scolor0 = scolor1*wt1 + scolor2*wt2;
	
	ctmp = color00/(wt1+wt2);
	vec3 sctmp = scolor0/(wt1+wt2);
	
	vec3 w1, w2;
	
	vec3 cref1 = mix(sctmp, scolor1, beam_size); float creff1 = pow(max(max(cref1.r,cref1.g),cref1.b), scan_falloff);
	vec3 cref2 = mix(sctmp, scolor2, beam_size); float creff2 = pow(max(max(cref2.r,cref2.g),cref2.b), scan_falloff);

	if (tds > 0.5) { shape1 = mix(scanline2, shape1, creff1); shape2 = mix(scanline2, shape2, creff2); }

	float f1 = f; 
	float f2 = 1.0-f;

	float mc1 = max(max(color1.r,color1.g),color1.b) + eps;
	float mc2 = max(max(color2.r,color2.g),color2.b) + eps;
	
	cref1 = color1 / mc1;
	cref2 = color2 / mc2;

	if (gsl <  0.5) { w1 = sw0(f1,creff1,shape1,cref1); w2 = sw0(f2,creff2,shape2,cref2);} else
	if (gsl == 1.0) { w1 = sw1(f1,creff1,shape1,cref1); w2 = sw1(f2,creff2,shape2,cref2);} else
	                { w1 = sw2(f1,creff1,shape1,cref1); w2 = sw2(f2,creff2,shape2,cref2);}

	vec3 w3 = w1+w2;
	float wf1 = max(max(w3.r,w3.g),w3.b);
	if (wf1 > 1.0) {wf1 = 1.0/wf1; w1*=wf1, w2*=wf1;}
	
	if (abs(clips) > 0.005)
	{
		sy = mc1; one = (clips > 0.0) ? w1 : 1.0.xxx;
		float sat = 1.0001-min(min(cref1.r,cref1.g),cref1.b);
		color1 = mix(color1, plant(pow(color1, 0.70.xxx-0.325*sat),sy), pow(sat,0.3333)*one*abs(clips));
		sy = mc2; one = (clips > 0.0) ? w2 : 1.0.xxx;
		sat =       1.0001-min(min(cref2.r,cref2.g),cref2.b);
		color2 = mix(color2, plant(pow(color2, 0.70.xxx-0.325*sat),sy), pow(sat,0.3333)*one*abs(clips));
	}	
	
	color = (gc(color1)*w1 + gc(color2)*w2);
	
	color = min(color, 1.0);
}
	
	if (interb) 
	{
		color = gc(color1);
	}

	float colmx = max(max(ctmp.r,ctmp.g),ctmp.b);

	if(!interb) color = pow( color, vec3(gamma_in/scangamma) );
	
	FragColor = vec4(color, colmx) * vec4(cval);
}
