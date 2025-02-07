#version 450

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
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
    float h_x_tilt;
    float h_y_tilt;
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

#include "../include/uborder_bezel_reflections_params.inc"

#define ub_OutputSize     params.OutputSize
#define ub_OriginalSize   params.OriginalSize
#define ub_Rotation       global.Rotation

#include "../include/uborder_bezel_reflections_common.inc"

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 uv;
layout(location = 2) out vec2 vTexOri;
layout(location = 3) out vec2 border_uv;

void main()
{
   gl_Position = global.MVP * Position;
   vTexOri = TexCoord;


    vec2 diff = TexCoord.xy * vec2(1.000001) - middle;
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
layout(location = 2) in vec2 vTexOri;
layout(location = 3) in vec2 border_uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 4) uniform sampler2D BORDER;


vec3 get_content(vec2 vTex, vec2 uv)
{
//   FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
   return texture(Source, vTex).rgb;
}

#define ReflexSrc Source

// Yeah, an unorthodox 'include' usage.
#include "../include/uborder_bezel_reflections_main.inc"
