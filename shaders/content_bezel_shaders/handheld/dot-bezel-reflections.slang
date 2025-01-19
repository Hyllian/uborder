#version 450


layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
   vec4 OutputSize;
   vec4 OriginalSize;
   vec4 SourceSize;

   uint Rotation;

    float all_zoom;

    float fr_zoom;
    float fr_scale_x;
    float fr_scale_y;
    float fr_center_x;
    float fr_center_y;
    float fr_i_scaling;
    float fr_i_scaling_fac;
    float fr_i_aspect_x;
    float fr_i_aspect_y;

    float h_shape;
    float h_radius;
    float h_cornersize;
    float h_cornersmooth;
    float h_overscan_x;
    float h_overscan_y;
    float h_angle_x;
    float h_angle_y;
    float h_curvature;

    float bz_width;
    float bz_height;
    float bz_shine_enable;
    float bz_shine;
    float bz_shine_size;
    float bz_ambient_enable;
    float bz_ambient;
    float bz_ambient_size;
    float bz_ref_str;
    float bz_lights;
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
    float ub_border_top;
} global;

#define USE_BEZEL_REFLECTIONS_COMMON

#include "../include/uborder_bezel_reflections_params.inc"

#define ub_OutputSize     global.OutputSize
#define ub_OriginalSize   global.OriginalSize

#include "../include/uborder_bezel_reflections_common.inc"

#define gamma 2.4
#define shine 0.05
#define blend 0.65

/*
   Author: Themaister
   License: Public domain
*/

//#define TEX(coord) texture(Source, vTexCoord).rgb
#define TEX(coord) texture(Source, vTex).rgb

float dist(vec2 coord, vec2 source)
{
   vec2 delta = coord - source;
   return sqrt(dot(delta, delta));
}

float color_bloom(vec3 color)
{
   const vec3 gray_coeff = vec3(0.30, 0.59, 0.11);
   float bright = dot(color, gray_coeff);
   return mix(1.0 + shine, 1.0 - shine, bright);
}

vec3 lookup(vec2 pixel_no, float offset_x, float offset_y, vec3 color)
{
   vec2 offset = vec2(offset_x, offset_y);
   float delta = dist(fract(pixel_no), offset + vec2(0.5, 0.5));
   return color * exp(-gamma * delta * color_bloom(color));
}

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec4 c00_10;
layout(location = 2) out vec4 c00_01;
layout(location = 3) out vec4 c20_01;
layout(location = 4) out vec4 c21_02;
layout(location = 5) out vec4 c12_22;
layout(location = 6) out vec2 c11;
layout(location = 7) out vec2 pixel_no;
layout(location = 8) out vec2 uv;
layout(location = 9) out vec2 border_uv;

void main()
{
   gl_Position = global.MVP * Position;
//   vTexCoord = TexCoord;

    vec2 diff    = TexCoord.xy * vec2(1.000001) - middle;
    vTexCoord    = middle + diff/fr_scale - fr_center;

    uv           = 2.0*vTexCoord - 1.0;

    border_uv = mix( TexCoord.xy, vec2(     TexCoord.y, 1.0- TexCoord.x), float(global.Rotation==1.0));
    border_uv = mix(border_uv.xy, vec2(1.0-border_uv.x, 1.0-border_uv.y), float(global.Rotation==2.0)); // It seems useless...
    border_uv = mix(border_uv.xy, vec2(1.0-border_uv.y,     border_uv.x), float(global.Rotation==3.0));

    border_uv.y = mix(border_uv.y, 1.0-border_uv.y, border_mirror_y);

    border_uv = middle + (border_uv.xy - middle - border_pos) / (global.border_scale*all_zoom);

    border_uv = border_uv.xy * vec2(1.000001);

   
   float dx = global.SourceSize.z;
   float dy = global.SourceSize.w;
   
   c00_10 = vec4(vTexCoord + vec2(-dx, -dy), vTexCoord + vec2(0, -dy));
   c20_01 = vec4(vTexCoord + vec2(dx, -dy), vTexCoord + vec2(-dx, 0));
   c21_02 = vec4(vTexCoord + vec2(dx, 0), vTexCoord + vec2(-dx, dy));
   c12_22 = vec4(vTexCoord + vec2(0, dy), vTexCoord + vec2(dx, dy));
   c11 = vTexCoord;
   pixel_no = vTexCoord * global.SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec4 c00_10;
layout(location = 2) in vec4 c00_01;
layout(location = 3) in vec4 c20_01;
layout(location = 4) in vec4 c21_02;
layout(location = 5) in vec4 c12_22;
layout(location = 6) in vec2 c11;
layout(location = 7) in vec2 pixel_no;
layout(location = 8) in vec2 uv;
layout(location = 9) in vec2 border_uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D BORDER;


void main()
{
// Bezels and border begins...

    vec2 uvFC = mix(uv, h_warp(uv), global.h_curvature); // Frame content area
    vec2 uvIB = uvFC;                                    // Inner bezel area
    vec2 uvMB = mix(uv, uvFC, global.bz_outer_curve);    // In Between bezel area
    vec2 uvOB = uvMB;                                    // Outer bezel area

    uvFC = uvFC*overscan - 2.0*vec2(global.h_angle_x, global.h_angle_y);

    vec2 area_out = RoundedRectVec(vec4(uvMB, uvOB), vec4(MID_BZ, OUT_BZ), bz_r.xx, vec2(SMTH, -SMTH));

    vec4 border = texture(BORDER, border_uv);

    border.rgb *= (bz_lights > 0.5) ? 1.0 : 0.5;
    if (area_out.y < 0.5) {FragColor = vec4(border.rgb, 1.0); return;}

// Bezels pause...

// Content frame begins... (put content shader code here)
// crt-nobody

     vec2 vTex = 0.5*uvFC + 0.5;

    float cval = h_corner(vTex)  *  step(0.0, fract(vTex.y));  // Discard off limit pixels


   vec3 mid_color = lookup(pixel_no, 0.0, 0.0, TEX(c11));
   vec3 color = vec3(0.0, 0.0, 0.0);
   color += lookup(pixel_no, -1.0, -1.0, TEX(c00_10.xy));
   color += lookup(pixel_no,  0.0, -1.0, TEX(c00_10.zw));
   color += lookup(pixel_no,  1.0, -1.0, TEX(c20_01.xy));
   color += lookup(pixel_no, -1.0,  0.0, TEX(c20_01.zw));
   color += mid_color;
   color += lookup(pixel_no,  1.0,  0.0, TEX(c21_02.xy));
   color += lookup(pixel_no, -1.0,  1.0, TEX(c21_02.zw));
   color += lookup(pixel_no,  0.0,  1.0, TEX(c12_22.xy));
   color += lookup(pixel_no,  1.0,  1.0, TEX(c12_22.zw));
   vec3 content = mix(1.2 * mid_color, color, blend);
   
// Content frame ends.

// Bezels continue...

    vec2 area_inn = RoundedRectVec(vec4(uvIB, uvMB), vec4(INN_BZ, MID_BZ), bz_r.xx, vec2(SMTH, -SMTH));

    float out_border = RoundedRect(uvOB, OUT_BZ, bz_r, SMTH.xx);

    vec3 frame_content = mix(content+border.rgb*out_border, mix(content.rgb, border.rgb, border.a), global.ub_border_top);

    const float ambient = bz_ambient;
    const float ambient_out = 1.4*bz_ambient;
    vec3 shine_content = 0.0.xxx;
    vec3 ambient_content = 0.0.xxx;

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

    frame_content += (global.bz_ambient_enable*ambient_content + global.bz_shine_enable*shine_content);

    if (area_inn.x < 0.5) { FragColor = vec4(frame_content, 1.0); return;}

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

    if (bz_lights == 1.0)
    {
        // Bezel texture 
        vec3 bz_color = clamp(BZ_COLOR + rand(uvIB)*0.0125-0.00625, 0.0, 1.0) + 
                                         rand(uvIB+1.0.xx)*0.0625 * cos(0.75*PI*uvIB.x);
        // Inner Bezel and Reflections
//        bezels += bz_color * bezel_inner_area * (Blur + 0.25*(1.0 + corner));
        bezels += (bz_color + Blur) * bezel_inner_area * (0.25*(1.0 + corner));

    	// Outer Bezel
   	bezels += bz_color * bezel_outer_area;
    }
    else
    {
        // Middle Bezel
        bezels -= (BZ_COLOR ) * RoundedRect(uvOB, MID_BZ, bz_r, vec2(SMTH*2.0, -SMTH*10.0)) * 
                                RoundedRect(uvOB, MID_BZ, bz_r, vec2(SMTH*2.0, -SMTH* 2.0));

        // Inner Bezel and Reflections
      //  bezels += BZ_COLOR * bezel_inner_area * (ambient_out * (0.7 + 0.35*(1.0 - corner)) + Blur);
        bezels += (BZ_COLOR + Blur) * bezel_inner_area * (ambient_out * (0.7 + 0.35*(1.0 - corner)) + Blur);

        // Outer Bezel
        bezels += BZ_COLOR * bezel_outer_area * ambient_out;
    }

    bezels = mix(bezels+border.rgb*out_border, mix(bezels, border.rgb, border.a), global.ub_border_top);

    FragColor = vec4(bezels, 1.0);
}
