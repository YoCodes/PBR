Shader "Hidden/DEPipeline/Sampling"
{
    Properties
    {
        _MainTex("Albedo", 2D) = "white" {}
    }

    HLSLINCLUDE
    #include "./Library/Core.hlsl"

    struct VertexInput
    {
        float4 vertex   : POSITION;
        float2 texcoord : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Interpolators
    {
        float4  pos      : SV_POSITION;
        float2  texcoord : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    Interpolators Vertex(VertexInput i)
    {
        Interpolators o;
        UNITY_SETUP_INSTANCE_ID(i);
        UNITY_TRANSFER_INSTANCE_ID(i, o);

        o.pos = TransformObjectToHClip(i.vertex.xyz);
        o.texcoord.xy = i.texcoord;
        return o;
    }

    half4 DownsampleBox4Tap(TEXTURE2D_ARGS(tex, samplerTex), float2 uv, float2 texelSize, float amount)
    {
        float4 d = texelSize.xyxy * float4(-amount, -amount, amount, amount);

        half4 s;
        s =  (SAMPLE_TEXTURE2D(tex, samplerTex, uv + d.xy));
        s += (SAMPLE_TEXTURE2D(tex, samplerTex, uv + d.zy));
        s += (SAMPLE_TEXTURE2D(tex, samplerTex, uv + d.xw));
        s += (SAMPLE_TEXTURE2D(tex, samplerTex, uv + d.zw));

        return s * 0.25h;
    }

    ENDHLSL

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "DEPipeline"}
        LOD 100

        // 0 - Downsample - Box filtering
        Pass
        {
            Name "Default"
            Tags { "LightMode" = "DEForward"}

            ZTest Always
            ZWrite Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma vertex Vertex
            #pragma fragment FragBoxDownsample

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
			
			CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_TexelSize;
			CBUFFER_END

            float _SampleOffset;

            half4 FragBoxDownsample(Interpolators i) : SV_Target
            {
                half4 col = DownsampleBox4Tap(TEXTURE2D_PARAM(_MainTex, sampler_MainTex), i.texcoord, _MainTex_TexelSize.xy, _SampleOffset);
                return half4(col.rgb, 1);
            }
            ENDHLSL
        }
    }
}
