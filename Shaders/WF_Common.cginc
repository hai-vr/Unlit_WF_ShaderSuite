﻿/*
 *  The MIT License
 *
 *  Copyright 2018-2019 whiteflare.
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 *  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 *  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#ifndef INC_UNLIT_WF_COMMON
#define INC_UNLIT_WF_COMMON

    /*
     * authors:
     *      ver:2019/11/24 whiteflare,
     */

    #include "UnityCG.cginc"
    #include "Lighting.cginc"

    #define _MATCAP_VIEW_CORRECT_ENABLE
    #define _MATCAP_ROTATE_CORRECT_ENABLE

    #define TGL_ON(value)   (0.5 <= value)
    #define TGL_OFF(value)  (value < 0.5)
    #define TGL_01(value)   step(0.5, value)

    static const float3 MEDIAN_GRAY = IsGammaSpace() ? float3(0.5, 0.5, 0.5) : GammaToLinearSpace( float3(0.5, 0.5, 0.5) );
    static const float3 BT601 = { 0.299, 0.587, 0.114 };
    static const float3 BT709 = { 0.21, 0.72, 0.07 };

    #define MAX3(r, g, b)   max(r, max(g, b) )
    #define AVE3(r, g, b)   ((r + g + b) / 3)
    #define MAX_RGB(v)      max(v.r, max(v.g, v.b))
    #define AVE_RGB(v)      ((v.r + v.g + v.b) / 3)

    #define WF_SAMPLE_TEX2D_LOD(tex, coord, lod)                        tex.SampleLevel(sampler##tex,coord, lod)
    #define WF_SAMPLE_TEX2D_SAMPLER_LOD(tex, samplertex, coord, lod)    tex.SampleLevel(sampler##samplertex, coord, lod)

#if 1
    // サンプラー節約のための差し替えマクロ
    // 節約にはなるけど最適化などで _MainTex のサンプリングが消えると途端に破綻する諸刃の剣
    #define DECL_MAIN_TEX2D(name)           UNITY_DECLARE_TEX2D(name)
    #define DECL_SUB_TEX2D(name)            UNITY_DECLARE_TEX2D_NOSAMPLER(name)
    #define PICK_MAIN_TEX2D(tex, uv)        UNITY_SAMPLE_TEX2D(tex, uv)
    #define PICK_SUB_TEX2D(tex, name, uv)   UNITY_SAMPLE_TEX2D_SAMPLER(tex, name, uv)
#else
    // 通常版
    #define DECL_MAIN_TEX2D(name)           sampler2D name
    #define DECL_SUB_TEX2D(name)            sampler2D name
    #define PICK_MAIN_TEX2D(tex, uv)        tex2D(tex, uv)
    #define PICK_SUB_TEX2D(tex, name, uv)   tex2D(tex, uv)
#endif

    #define INVERT_MASK_VALUE(rgba, inv)            saturate( TGL_OFF(inv) ? rgba : float4(1 - rgba.rgb, rgba.a) )
    #define SAMPLE_MASK_VALUE(tex, uv, inv)         INVERT_MASK_VALUE( PICK_SUB_TEX2D(tex, _MainTex, uv), inv )
    #define SAMPLE_MASK_VALUE_LOD(tex, uv, inv)     INVERT_MASK_VALUE( tex2Dlod(tex, float4(uv.x, uv.y, 0, 0)), inv )

    #define NZF                                     0.00390625
    #define NON_ZERO_FLOAT(v)                       max(v, NZF)
    #define NON_ZERO_VEC3(v)                        max(v, float3(NZF, NZF, NZF))
    #define ZERO_VEC3                               float3(0, 0, 0)
    #define ONE_VEC3                                float3(1, 1, 1)

    #if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
        #define _LMAP_ENABLE
    #endif

    inline float2 SafeNormalizeVec2(float2 in_vec) {
        float lenSq = dot(in_vec, in_vec);
        if (lenSq < 0.0001) {
            return float2(0, 0);
        }
        return in_vec * rsqrt(lenSq);
    }

    inline float3 SafeNormalizeVec3(float3 in_vec) {
        float lenSq = dot(in_vec, in_vec);
        if (lenSq < 0.0001) {
            return float3(0, 0, 0);
        }
        return in_vec * rsqrt(lenSq);
    }

    inline float calcBrightness(float3 color) {
        return dot(color, BT601);
    }

    inline float3 calcPointLight1Pos() {
        return float3(unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x);
    }

    inline float3 calcPointLight1Color(float3 ws_pos) {
        float3 ws_lightPos = calcPointLight1Pos();
        if (ws_lightPos.x == 0 && ws_lightPos.y == 0 && ws_lightPos.z == 0) {
            return float3(0, 0, 0); // XYZすべて0はポイントライト未設定と判定する
        }
        float3 ls_lightPos = ws_lightPos - ws_pos;
        float lengthSq = dot(ls_lightPos, ls_lightPos);
        float atten = 1.0 / (1.0 + lengthSq * unity_4LightAtten0.x);
        return unity_LightColor[0].rgb * atten;
    }

    inline float3 OmniDirectional_ShadeSH9() {
        // UnityCG.cginc にある ShadeSH9 の等方向版
        float3 col = 0;
        col += ShadeSH9( float4(+1, 0, 0, 1) );
        col += ShadeSH9( float4(-1, 0, 0, 1) );
        col += ShadeSH9( float4(0, 0, +1, 1) );
        col += ShadeSH9( float4(0, 0, -1, 1) );
        col /= 4;
        col += ShadeSH9( float4(0, +1, 0, 1) );
        col += ShadeSH9( float4(0, -1, 0, 1) );
        return col / 3;
    }

    inline float3 OmniDirectional_Shade4PointLights(
        float4 lpX, float4 lpY, float4 lpZ,
        float3 col0, float3 col1, float3 col2, float3 col3,
        float4 lightAttenSq, float3 ws_pos) {
        // UnityCG.cginc にある Shade4PointLights の等方向版

        if ( !any(float3(lpX.x, lpY.x, lpZ.x)) ) {
            col0.rgb = 0;
        }

        float4 toLightX = lpX - ws_pos.x;
        float4 toLightY = lpY - ws_pos.y;
        float4 toLightZ = lpZ - ws_pos.z;

        float4 lengthSq
            = toLightX * toLightX
            + toLightY * toLightY
            + toLightZ * toLightZ;
        // ws_normal との内積は取らない。これによって反射光の強さではなく、頂点に当たるライトの強さが取れる。

        // attenuation
        float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);

        float3 col
            = col0 * atten.x
            + col1 * atten.y
            + col2 * atten.z
            + col3 * atten.w;
        return col;
    }

    inline float calcLightPower(float4 ls_vertex) {
        // directional light
        float3 lightColor = _LightColor0;
        // ambient
        lightColor += OmniDirectional_ShadeSH9();
        // not important lights
        lightColor += OmniDirectional_Shade4PointLights(
            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
            unity_LightColor[0].rgb,
            unity_LightColor[1].rgb,
            unity_LightColor[2].rgb,
            unity_LightColor[3].rgb,
            unity_4LightAtten0,
            mul(unity_ObjectToWorld, ls_vertex)
        );
        return calcBrightness(saturate(lightColor));
    }

    inline float3 worldSpaceCameraPos() {
        #ifdef USING_STEREO_MATRICES
            return (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]) * 0.5;
        #else
            return _WorldSpaceCameraPos;
        #endif
    }

    inline float3 worldSpaceViewDir(float4 ls_vertex) {
        float4 ws_vertex = mul(unity_ObjectToWorld, ls_vertex);
        return SafeNormalizeVec3(worldSpaceCameraPos() - ws_vertex.xyz);
    }

    inline float3 localSpaceViewDir(float4 ls_vertex) {
        float4 ls_camera_pos = mul(unity_WorldToObject, float4(worldSpaceCameraPos(), 1));
        return SafeNormalizeVec3(ls_camera_pos.xyz - ls_vertex.xyz);
    }

    inline bool isInMirror() {
        return unity_CameraProjection[2][0] != 0.0f || unity_CameraProjection[2][1] != 0.0f;
    }

    inline float3 pickLightmap(float2 uv_lmap) {
        float3 color = ZERO_VEC3;
        #ifdef LIGHTMAP_ON
        {
            float2 uv = uv_lmap.xy * unity_LightmapST.xy + unity_LightmapST.zw;
            float4 lmap_tex = UNITY_SAMPLE_TEX2D(unity_Lightmap, uv);
            float3 lmap_color = DecodeLightmap(lmap_tex);
            color += lmap_color;
        }
        #endif
        #ifdef DYNAMICLIGHTMAP_ON
        {
            float2 uv = uv_lmap.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
            float4 lmap_tex = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, uv);
            float3 lmap_color = DecodeRealtimeLightmap(lmap_tex);
            color += lmap_color;
        }
        #endif
        return color;
    }

    inline float3 pickLightmapLod(float2 uv_lmap) {
        float3 color = ZERO_VEC3;
        #ifdef LIGHTMAP_ON
        {
            float2 uv = uv_lmap.xy * unity_LightmapST.xy + unity_LightmapST.zw;
            float4 lmap_tex = WF_SAMPLE_TEX2D_LOD(unity_Lightmap, uv, 0);
            float3 lmap_color = DecodeLightmap(lmap_tex);
            color += lmap_color;
        }
        #endif
        #ifdef DYNAMICLIGHTMAP_ON
        {
            float2 uv = uv_lmap.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
            float4 lmap_tex = WF_SAMPLE_TEX2D_LOD(unity_DynamicLightmap, uv, 0);
            float3 lmap_color = DecodeRealtimeLightmap(lmap_tex);
            color += lmap_color;
        }
        #endif
        return color;
    }

    ////////////////////////////
    // Alpha Transparent
    ////////////////////////////

    float           _Cutoff;

    #ifdef _AL_ENABLE
        int             _AL_Source;
        float           _AL_Power;
        sampler2D       _AL_MaskTex;
        float           _AL_Fresnel;

        #ifndef _AL_CustomValue
            #define _AL_CustomValue 1
        #endif

        inline float pickAlpha(float2 uv, float alpha) {
            if (_AL_Source == 1) {
                return tex2D(_AL_MaskTex, uv).r;
            }
            else if (_AL_Source == 2) {
                return tex2D(_AL_MaskTex, uv).a;
            }
            else {
                return alpha;
            }
        }

        inline void affectAlpha(float2 uv, inout float4 color) {
            float baseAlpha = pickAlpha(uv, color.a);

            #if defined(_AL_CUTOUT)
                if (baseAlpha < _Cutoff) {
                    discard;
                } else {
                    color.a = 1.0;
                }
            #elif defined(_AL_CUTOUT_UPPER)
                if (baseAlpha < _Cutoff) {
                    discard;
                } else {
                    baseAlpha *= _AL_Power * _AL_CustomValue;
                }
            #elif defined(_AL_CUTOUT_LOWER)
                if (baseAlpha < _Cutoff) {
                    baseAlpha *= _AL_Power * _AL_CustomValue;
                } else {
                    discard;
                }
            #else
                baseAlpha *= _AL_Power * _AL_CustomValue;
            #endif

            color.a = baseAlpha;
        }

        inline void affectAlphaWithFresnel(float2 uv, float3 normal, float3 viewdir, inout float4 color) {
            float baseAlpha = pickAlpha(uv, color.a);

            #if defined(_AL_CUTOUT)
                if (baseAlpha < _Cutoff) {
                    discard;
                } else {
                    color.a = 1.0;
                }
            #elif defined(_AL_CUTOUT_UPPER)
                if (baseAlpha < _Cutoff) {
                    discard;
                } else {
                    baseAlpha *= _AL_Power * _AL_CustomValue;
                }
            #elif defined(_AL_CUTOUT_LOWER)
                if (baseAlpha < _Cutoff) {
                    baseAlpha *= _AL_Power * _AL_CustomValue;
                } else {
                    discard;
                }
            #else
                baseAlpha *= _AL_Power * _AL_CustomValue;
            #endif

            #ifndef _AL_FRESNEL_ENABLE
                // ベースアルファ
                color.a = baseAlpha;
            #else
                // フレネルアルファ
                float maxValue = max( pickAlpha(uv, color.a) * _AL_Power, _AL_Fresnel ) * _AL_CustomValue;
                float fa = 1 - abs( dot( SafeNormalizeVec3(normal), SafeNormalizeVec3(viewdir) ) );
                color.a = lerp( baseAlpha, maxValue, fa * fa * fa * fa );
            #endif
        }
    #else
        #define affectAlpha(uv, color)                              color.a = 1.0
        #define affectAlphaWithFresnel(uv, normal, viewdir, color)  color.a = 1.0
    #endif

    ////////////////////////////
    // Highlight and Shadow Matcap
    ////////////////////////////

    inline float3 calcMatcapVector(in float4 ls_vertex, in float3 ls_normal) {
        float3 vs_normal = mul(UNITY_MATRIX_IT_MV, float4(ls_normal, 1)).xyz;

        #ifdef _MATCAP_VIEW_CORRECT_ENABLE
            float3 ws_view_dir = worldSpaceViewDir(ls_vertex);
            float3 base = mul( (float3x3)UNITY_MATRIX_V, ws_view_dir ) * float3(-1, -1, 1) + float3(0, 0, 1);
            float3 detail = vs_normal.xyz * float3(-1, -1, 1);
            vs_normal = base * dot(base, detail) / base.z - detail;
        #endif

        #ifdef _MATCAP_ROTATE_CORRECT_ENABLE
            float2 vs_topdir = mul( (float3x3)UNITY_MATRIX_V, float3(0, 1, 0) ).xy;
            if (any(vs_topdir)) {
                vs_topdir = normalize(vs_topdir);
                float top_angle = sign(vs_topdir.x) * acos( clamp(vs_topdir.y, -1, 1) );
                float2x2 matrixRotate = { cos(top_angle), sin(top_angle), -sin(top_angle), cos(top_angle) };
                vs_normal.xy = mul( vs_normal.xy, matrixRotate );
            }
        #endif

        return normalize( vs_normal );
    }

    ////////////////////////////
    // Color Change
    ////////////////////////////

    #ifdef _CL_ENABLE
        inline float3 rgb2hsv(float3 c) {
            // i see "https://qiita.com/_nabe/items/c8ba019f26d644db34a8"
            static float4 k = float4( 0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0 );
            static float e = 1.0e-10;
            float4 p = lerp( float4(c.bg, k.wz), float4(c.gb, k.xy), step(c.b, c.g) );
            float4 q = lerp( float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r) );
            float d = q.x - min(q.w, q.y);
            return float3( abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x );
        }

        inline float3 hsv2rgb(float3 c) {
            // i see "https://qiita.com/_nabe/items/c8ba019f26d644db34a8"
            static float4 k = float4( 1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0 );
            float3 p = abs( frac(c.xxx + k.xyz) * 6.0 - k.www );
            return c.z * lerp( k.xxx, saturate(p - k.xxx), c.y );
        }

        float       _CL_Enable;
        float       _CL_DeltaH;
        float       _CL_DeltaS;
        float       _CL_DeltaV;
        float       _CL_Monochrome;

        inline void affectColorChange(inout float4 color) {
            if (TGL_ON(_CL_Enable)) {
                if (TGL_ON(_CL_Monochrome)) {
                    color.r += color.g + color.b;
                    color.g = (color.r - 1) / 2;
                    color.b = (color.r - 1) / 2;
                }
                float3 hsv = rgb2hsv( saturate(color.rgb) );
                hsv += float3( _CL_DeltaH, _CL_DeltaS, _CL_DeltaV);
                hsv.r = frac(hsv.r);
                color.rgb = saturate( hsv2rgb( saturate(hsv) ) );
            }
        }

    #else
        // Dummy
        #define affectColorChange(color)
    #endif

    ////////////////////////////
    // Emissive Scroll
    ////////////////////////////

    #ifdef _ES_ENABLE
        float       _ES_Enable;
        sampler2D   _EmissionMap;
        float4      _EmissionColor;
        float       _ES_BlendType;

        int         _ES_Shape;
        float4      _ES_Direction;
        float       _ES_LevelOffset;
        float       _ES_Sharpness;
        float       _ES_Speed;
        float       _ES_AlphaScroll;

        inline float calcEmissiveWaving(float4 ls_vertex) {
	        float4 ws_vertex = mul(unity_ObjectToWorld, ls_vertex);
            float time = _Time.y * _ES_Speed - dot(ws_vertex, _ES_Direction.xyz);
            // 周期 2PI、値域 [-1, +1] の関数で光量を決める
            if (_ES_Shape == 0) {
                // 励起波
                float v = pow( 1 - frac(time * UNITY_INV_TWO_PI), _ES_Sharpness + 2 );
                float waving = 8 * v * (1 - v) - 1;
                return saturate(waving + _ES_LevelOffset);
            }
            else if (_ES_Shape == 1) {
                // のこぎり波
                float waving = 1 - 2 * frac(time * UNITY_INV_TWO_PI);
                return saturate(waving * _ES_Sharpness + _ES_LevelOffset);
            }
            else if (_ES_Shape == 2) {
                // 正弦波
                float waving = sin( time );
                return saturate(waving * _ES_Sharpness + _ES_LevelOffset);
            }
            else {
                // 定数
                float waving = 1;
                return saturate(waving + _ES_LevelOffset);
            }
        }

        inline void affectEmissiveScroll(float4 ls_vertex, float2 mask_uv, inout float4 color) {
            if (TGL_ON(_ES_Enable)) {
                float waving    = calcEmissiveWaving(ls_vertex);
                float3 es_mask  = tex2D(_EmissionMap, mask_uv).rgb;
                float es_power  = MAX_RGB(es_mask);
                float3 es_color = _EmissionColor.rgb * es_mask.rgb + lerp(color.rgb, ZERO_VEC3, _ES_BlendType);

                color.rgb = lerp(color.rgb,
                    lerp(color.rgb, es_color, waving),
                    es_power);

                #ifdef _ES_FORCE_ALPHASCROLL
                    color.a = max(color.a, waving * _EmissionColor.a * es_power);
                #else
                    if (TGL_ON(_ES_AlphaScroll)) {
                        color.a = max(color.a, waving * _EmissionColor.a * es_power);
                    }
                #endif
            }
        }

    #else
        // Dummy
        #define affectEmissiveScroll(ls_vertex, mask_uv, color)
    #endif

    ////////////////////////////
    // ReflectionProbe Sampler
    ////////////////////////////

    inline float4 pickReflectionProbe(float4 ls_vertex, float3 ls_normal, float lod) {
        float4 ws_vertex = mul(unity_ObjectToWorld, ls_vertex);
        float3 ws_camera_dir = normalize(_WorldSpaceCameraPos.xyz - ws_vertex );
        float3 reflect_dir = reflect(-ws_camera_dir, UnityObjectToWorldNormal(ls_normal));

        float3 dir0 = BoxProjectedCubemapDirection(reflect_dir, ws_vertex, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        float3 dir1 = BoxProjectedCubemapDirection(reflect_dir, ws_vertex, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);

        float4 color0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, dir0, lod);
        float4 color1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, dir1, lod);

        color0.rgb = DecodeHDR(color0, unity_SpecCube0_HDR);
        color1.rgb = DecodeHDR(color1, unity_SpecCube1_HDR);

        return lerp(color1, color0, unity_SpecCube0_BoxMin.w);
    }

    inline float3 pickReflectionCubemap(samplerCUBE cubemap, half4 cubemap_HDR, float4 ls_vertex, float3 ls_normal, float lod) {
        float4 ws_vertex = mul(unity_ObjectToWorld, ls_vertex);
        float3 ws_camera_dir = normalize(_WorldSpaceCameraPos.xyz - ws_vertex );
        float3 reflect_dir = reflect(-ws_camera_dir, UnityObjectToWorldNormal(ls_normal));

        float4 color = texCUBElod(cubemap, float4(reflect_dir, lod) );
        return DecodeHDR(color, cubemap_HDR);
    }

#endif
