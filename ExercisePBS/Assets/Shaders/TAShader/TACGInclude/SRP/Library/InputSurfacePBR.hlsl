#ifndef LIGHTWEIGHT_INPUT_SURFACE_PBR_INCLUDED
#define LIGHTWEIGHT_INPUT_SURFACE_PBR_INCLUDED

#include "Core.hlsl"
#include "CommonMaterial.hlsl"
#include "InputSurfaceCommon.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _MainTex_ST;
half4 _Color;
half4 _SpecColor;
half4 _EmissionColor;
half _Cutoff;
half _Glossiness;
half _GlossMapScale;
half _Metallic;
half _BumpScale;
half _OcclusionStrength;
CBUFFER_END

TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_SpecGlossMap);       SAMPLER(sampler_SpecGlossMap);

#ifdef _SPECULAR_SETUP
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
#else
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
#endif

half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
{
    half4 specGloss;

#ifdef _METALLICSPECGLOSSMAP
    specGloss = SAMPLE_METALLICSPECULAR(uv);
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        specGloss.a = albedoAlpha * _GlossMapScale;
    #else
        specGloss.a *= _GlossMapScale;
    #endif
#else
    #if _SPECULAR_SETUP
        specGloss.rgb = _SpecColor.rgb;
    #else
        specGloss.rgb = _Metallic.rrr;
    #endif

    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        specGloss.a = albedoAlpha * _GlossMapScale;
    #else
        specGloss.a = _Glossiness;
    #endif
#endif

    return specGloss;
}

half4 SampleMetallicRough(float2 uv, half albedoAlpha)
{
	half4 specGloss;
	
#ifdef _METALLICGLOSSMAP
	specGloss.r = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv).r;
#else
	specGloss.r = _Metallic;
#endif

#ifdef _SPECGLOSSMAP
	specGloss.a = 1.0f - SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv).r;
#else
	specGloss.a = 1.0f - _Glossiness;
#endif

	return specGloss;
}

half SampleOcclusion(float2 uv)
{
#ifdef _OCCLUSIONMAP
// TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
#if defined(SHADER_API_GLES)
    return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
#else
    half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
    return LerpWhiteTo(occ, _OcclusionStrength);
#endif
#else
    return 1.0;
#endif
}

inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_PARAM(_MainTex, sampler_MainTex));
    outSurfaceData.alpha = Alpha(albedoAlpha.a, _Color, _Cutoff);

#if _ROUGHNESS_SETUP
	half4 specGloss = SampleMetallicRough(uv, albedoAlpha.a);
#else
    half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
#endif
    outSurfaceData.albedo = albedoAlpha.rgb * _Color.rgb;

#if _SPECULAR_SETUP
    outSurfaceData.metallic = 1.0h;
    outSurfaceData.specular = specGloss.rgb;
#elif _ROUGHNESS_SETUP
	outSurfaceData.metallic = specGloss.r;
	outSurfaceData.specular = lerp(unity_ColorSpaceDielectricSpec.rgb, outSurfaceData.albedo, outSurfaceData.metallic);
#else
    outSurfaceData.metallic = specGloss.r;
    outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
#endif

    outSurfaceData.smoothness = specGloss.a;
    outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_PARAM(_BumpMap, sampler_BumpMap), _BumpScale);
    outSurfaceData.occlusion = SampleOcclusion(uv);
    outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_PARAM(_EmissionMap, sampler_EmissionMap));
}

#endif // LIGHTWEIGHT_INPUT_SURFACE_PBR_INCLUDED
