#version 450

/*
   Phosphor Afterglow Shader pass 0
   
   Copyright (C) 2020 - 2022 guest(r) - guest.r@gmail.com

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
   vec4 SourceSize;
   vec4 OriginalSize;
   vec4 OutputSize;
   uint FrameCount;
   float PR, PG, PB;
} params;

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

#pragma parameter border_nonono       "BORDER:"                            0.0  0.0 1.0 1.0
#pragma parameter ub_border_top       "    On top: [ Frame | Border ]"     0.0  0.0 1.0 1.0
#pragma parameter border_alpha_cutoff "    Frame 'On Top' Transparency"    0.38  0.0 1.0 0.01
#pragma parameter border_luma_trans   "        Luma Transp. [ Off | On ]" 1.0  0.0 1.0 1.0
#pragma parameter border_scale        "    Border Scale"                   1.0  0.5 5.0 0.002
#pragma parameter border_center_x     "    Border Center X"                0.0 -0.5 0.5 0.001
#pragma parameter border_center_y     "    Border Center Y"                0.0 -0.5 0.5 0.001
#pragma parameter border_mirror_y     "    Border Mirror (Y)"              0.0  0.0 1.0 1.0

#pragma parameter RF_NONONO              "REFLECTIONS:"                    0.0  0.0 1.0 1.0
#pragma parameter AdjustView             "    Reflection Adjust View"      0.0  0.0 1.0 1.0
#pragma parameter reflection_strength    "    Reflection Strengh"          0.25 0.0 1.0 0.01
#pragma parameter ref_outer_warp         "    Disable Outer Curvature"     0.0  0.0 1.0 1.0
#pragma parameter ref_warp_x                 "    Reflection Warp X"       0.0  0.0 1.0 0.01
#pragma parameter ref_warp_y                 "    Reflection Warp Y"       0.0  0.0 1.0 0.01
#pragma parameter frame_w                "    Reflection Width"            0.67 0.0 1.0 0.001
#pragma parameter frame_h                "    Reflection Height"           0.87 0.0 1.0 0.001
#pragma parameter bezel_w                "    Reflection Thickness X"      0.02 0.0 1.0 0.001
#pragma parameter bezel_h                "    Reflection Thickness Y"      0.02 0.0 1.0 0.001
#pragma parameter bezel_center_x         "    Reflection Center X"         0.0 -0.5 0.5 0.001
#pragma parameter bezel_center_y         "    Reflection Center Y"         0.0 -0.5 0.5 0.001
#pragma parameter reflection_scr_distance_x  "    Reflection Starting X"   0.0 -0.04 0.04 0.001
#pragma parameter reflection_scr_distance_y  "    Reflection Starting Y"   0.0 -0.04 0.04 0.001
#pragma parameter inner_corner_radius    "    Inner Corner Radius"         0.05 0.0 1.0 0.01
#pragma parameter outer_corner_radius    "    Outer Corner Radius"         0.0  0.0 1.0 0.01

#pragma parameter gadv_nonono       "CRT-GUEST-ADVANCED:"                           0.0  0.0 1.0 1.0
#pragma parameter bogus_afterglow "[ AFTERGLOW SETTINGS ]:" 0.0 0.0 1.0 1.0
#pragma parameter PR "          Persistence Red" 0.32 0.0 0.50 0.01
#pragma parameter PG "          Persistence Green"  0.32 0.0 0.50 0.01
#pragma parameter PB "          Persistence Blue"  0.32 0.0 0.50 0.01

#define PR params.PR
#define PG params.PG
#define PB params.PB

#define COMPAT_TEXTURE(c,d) texture(c,d)

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D OriginalHistory0;
layout(set = 0, binding = 3) uniform sampler2D AfterglowPassFeedback;

#define TEX0 vTexCoord


void main()
{
	vec2 dx = vec2(params.OriginalSize.z, 0.0);
	vec2 dy = vec2(0.0, params.OriginalSize.w);
	
	vec3 color0  = COMPAT_TEXTURE(OriginalHistory0, TEX0.xy).rgb;
	vec3 color1  = COMPAT_TEXTURE(OriginalHistory0, TEX0.xy - dx).rgb;
	vec3 color2  = COMPAT_TEXTURE(OriginalHistory0, TEX0.xy + dx).rgb;
	vec3 color3  = COMPAT_TEXTURE(OriginalHistory0, TEX0.xy - dy).rgb;
	vec3 color4  = COMPAT_TEXTURE(OriginalHistory0, TEX0.xy + dy).rgb;	

	vec3 color = (2.5 * color0 + color1 + color2 + color3 + color4)/6.5;
	
	vec3 accumulate = COMPAT_TEXTURE(AfterglowPassFeedback, TEX0.xy).rgb;

	float w = 1.0;
	if ((color0.r + color0.g + color0.b < 5.0/255.0)) { w = 0.0; }

	vec3 result = mix( max(mix(color, accumulate, 0.49 + vec3(PR, PG, PB))- 1.25/255.0, 0.0), color, w);

	FragColor = vec4(result, w);
}
