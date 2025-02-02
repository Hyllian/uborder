#version 450

layout(push_constant) uniform Push
{
    float RSUBPIX_R;
    float RSUBPIX_G;
    float RSUBPIX_B;
    float GSUBPIX_R;
    float GSUBPIX_G;
    float GSUBPIX_B;
    float BSUBPIX_R;
    float BSUBPIX_G;
    float BSUBPIX_B;
    float gain;
    float gamma;
    float blacklevel;
    float ambient;
    float BGR;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;

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
    float border_alpha;
    float ub_border_top;
    float black_baoc;
} global;

#define USE_BEZEL_REFLECTIONS_COMMON

#include "../include/uborder_bezel_reflections_params.inc"

#define ub_OutputSize     global.OutputSize
#define ub_OriginalSize   global.OriginalSize
#define ub_Rotation       global.Rotation

#include "../include/uborder_bezel_reflections_common.inc"

#pragma parameter lcd_grid_nonono       "LCD-GRID-V2:"                           0.0  0.0 1.0 1.0
#pragma parameter RSUBPIX_R  "Colour of R subpixel: R" 1.0 0.0 1.0 0.01
#pragma parameter RSUBPIX_G  "Colour of R subpixel: G" 0.0 0.0 1.0 0.01
#pragma parameter RSUBPIX_B  "Colour of R subpixel: B" 0.0 0.0 1.0 0.01
#pragma parameter GSUBPIX_R  "Colour of G subpixel: R" 0.0 0.0 1.0 0.01
#pragma parameter GSUBPIX_G  "Colour of G subpixel: G" 1.0 0.0 1.0 0.01
#pragma parameter GSUBPIX_B  "Colour of G subpixel: B" 0.0 0.0 1.0 0.01
#pragma parameter BSUBPIX_R  "Colour of B subpixel: R" 0.0 0.0 1.0 0.01
#pragma parameter BSUBPIX_G  "Colour of B subpixel: G" 0.0 0.0 1.0 0.01
#pragma parameter BSUBPIX_B  "Colour of B subpixel: B" 1.0 0.0 1.0 0.01
#pragma parameter gain       "Gain"                    1.0 0.5 2.0 0.05
#pragma parameter gamma      "LCD Gamma"               3.0 0.5 5.0 0.1
#pragma parameter blacklevel "Black level"            0.05 0.0 0.5 0.01
#pragma parameter ambient    "Ambient"                 0.0 0.0 0.5 0.01
#pragma parameter BGR        "BGR"                     0 0 1 1

#define outgamma 2.2

#define fetch_offset(coord, offset) (pow(vec3(params.gain) * texelFetchOffset(Source, (coord), 0, (offset)).rgb + vec3(params.blacklevel), vec3(params.gamma)) + vec3(params.ambient))

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 uv;
layout(location = 2) out vec2 border_uv;


void main()
{
    gl_Position = global.MVP * Position;
//   vTexCoord = TexCoord;

    vec2 diff    = TexCoord.xy * vec2(1.000001) - middle;
    vTexCoord    = middle + diff/fr_scale - fr_center;

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
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D BORDER;

// integral of (1 - x^2 - x^4 + x^6)^2
float coeffs_x[7] = float[](1.0, -2.0/3.0, -1.0/5.0, 4.0/7.0, -1.0/9.0, -2.0/11.0, 1.0/13.0);
// integral of (1 - 2x^4 + x^6)^2
float coeffs_y[7] = float[](1.0,      0.0, -4.0/5.0, 2.0/7.0,  4.0/9.0, -4.0/11.0, 1.0/13.0);

float intsmear_func(float z, float coeffs[7])
{
    float z2 = z*z;
    float zn = z;
    float ret = 0.0;
    for (int i = 0; i < 7; i++) {
        ret += zn*coeffs[i];
        zn *= z2;
    }
    return ret;
}

float intsmear(float x, float dx, float d, float coeffs[7])
{
    float zl = clamp((x-dx*0.5)/d,-1.0,1.0);
    float zh = clamp((x+dx*0.5)/d,-1.0,1.0);
    return d * ( intsmear_func(zh,coeffs) - intsmear_func(zl,coeffs) )/dx;
}


vec3 get_content(vec2 vTex, vec2 uv)
{
    vec2 texelSize = global.SourceSize.zw;
    /* float2 range = IN.video_size / (IN.output_size * IN.texture_size); */
    vec2 range = global.OutputSize.zw;

    vec3 cred   = pow(vec3(params.RSUBPIX_R, params.RSUBPIX_G, params.RSUBPIX_B), vec3(outgamma));
    vec3 cgreen = pow(vec3(params.GSUBPIX_R, params.GSUBPIX_G, params.GSUBPIX_B), vec3(outgamma));
    vec3 cblue  = pow(vec3(params.BSUBPIX_R, params.BSUBPIX_G, params.BSUBPIX_B), vec3(outgamma));

    ivec2 tli = ivec2(floor(vTex/texelSize-vec2(0.4999)));

    vec3 lcol, rcol;
    float subpix = (vTex.x/texelSize.x - 0.4999 - float(tli.x))*3.0;
    float rsubpix = range.x/texelSize.x * 3.0;

    lcol = vec3(intsmear(subpix+1.0, rsubpix, 1.5, coeffs_x),
                intsmear(subpix    , rsubpix, 1.5, coeffs_x),
                intsmear(subpix-1.0, rsubpix, 1.5, coeffs_x));
    rcol = vec3(intsmear(subpix-2.0, rsubpix, 1.5, coeffs_x),
                intsmear(subpix-3.0, rsubpix, 1.5, coeffs_x),
                intsmear(subpix-4.0, rsubpix, 1.5, coeffs_x));

    if (params.BGR > 0.5) {
        lcol.rgb = lcol.bgr;
        rcol.rgb = rcol.bgr;
    }

    float tcol, bcol;
    subpix = vTex.y/texelSize.y - 0.4999 - float(tli.y);
    rsubpix = range.y/texelSize.y;
    tcol = intsmear(subpix    ,rsubpix, 0.63, coeffs_y);
    bcol = intsmear(subpix-1.0,rsubpix, 0.63, coeffs_y);

    vec3 topLeftColor     = fetch_offset(tli, ivec2(0,0)) * lcol * vec3(tcol);
    vec3 bottomRightColor = fetch_offset(tli, ivec2(1,1)) * rcol * vec3(bcol);
    vec3 bottomLeftColor  = fetch_offset(tli, ivec2(0,1)) * lcol * vec3(bcol);
    vec3 topRightColor    = fetch_offset(tli, ivec2(1,0)) * rcol * vec3(tcol);

    vec3 averageColor = topLeftColor + bottomRightColor + bottomLeftColor + topRightColor;

    averageColor = mat3(cred, cgreen, cblue) * averageColor;

   return pow(averageColor, vec3(1.0/outgamma));
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
