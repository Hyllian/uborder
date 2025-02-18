
layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

#define USE_BEZEL_REFLECTIONS_COMMON


layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
#include "../../include/uborder_bezel_reflections_global_declarations.inc"
} global;


#include "../../include/uborder_bezel_reflections_params.inc"

#define ub_OutputSize     params.OutputSize
#define ub_OriginalSize   params.OriginalSize
#define ub_Rotation       global.Rotation

#include "../../include/uborder_bezel_reflections_common.inc"

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
layout(set = 0, binding = 3) uniform sampler2D BORDER;
#ifdef USE_AMBIENT_LIGHT
layout(set = 0, binding = 4) uniform sampler2D ambi_temporal_pass;
#endif


vec3 get_content(vec2 vTex, vec2 uv)
{
//   FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
   return texture(Source, vTex).rgb;
}

#define ReflexSrc Source

// Yeah, an unorthodox 'include' usage.
#include "../../include/uborder_bezel_reflections_main.inc"
