﻿// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

/* ***************************************************************************
     Adapted shader from: Makin' Stuff Look Good With Unity (Youtube Channel)
	 Link: https://www.youtube.com/watch?v=C6lGEgcHbWc

	 Adapted by: Flavio Freitas de Sousa
	 Contact: flaviofreitas.h@gmail.com
   *************************************************************************** */


// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "GGJ2017/GlowShield"
{
	Properties
	{
		_MainTex ("Hexagon", 2D) = "white" {}
		_HealthyColor("Healthy Color", Color) = (0, 0, 1, 0)
		_MiddleColor("Middle Color", Color) = (1, 1, 0, 0)
		_DamagedColor("Damaged Color", Color) = (1, 0, 0, 0)
		_CrackedTex("Crackes", 2D) = "white" {}
		_CrackedIntensity("Cracks Intensity", Range(0, 1)) = 0.5
		_CrackedColor("Cracks Color", Color) = (0.8, 0.8, 0, 0)
	}

	SubShader
	{
		Blend One One
		ZWrite Off
		Cull Off

		Tags
		{
			"RenderType"="Transparent"
			"Queue"="Transparent"
		}

		Pass
		{
			CGPROGRAM
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float2 screenuv : TEXCOORD1;
				float3 viewDir : TEXCOORD2;
				float3 objectPos : TEXCOORD3;
				float2 crackedUV : TEXCOORD4;
				float4 vertex : SV_POSITION;
				float depth : DEPTH;
				float3 normal : NORMAL;
			};

			sampler2D _MainTex;
			sampler2D _CrackedTex;
			float4 _MainTex_ST;
			float4 _CrackedTex_ST;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.crackedUV = TRANSFORM_TEX(v.uv, _CrackedTex);

				o.screenuv = ((o.vertex.xy / o.vertex.w) + 1)/2;
				o.screenuv.y = 1 - o.screenuv.y;
				o.depth = -mul(UNITY_MATRIX_MV, v.vertex).z *_ProjectionParams.w;

				o.objectPos = v.vertex.xyz;		
				o.normal = UnityObjectToWorldNormal(v.normal);
				o.viewDir = normalize(UnityWorldSpaceViewDir(mul(unity_ObjectToWorld, v.vertex)));

				return o;
			}
			
			sampler2D _CameraDepthNormalsTexture;
			fixed4 _HealthyColor;
			fixed4 _MiddleColor;
			fixed4 _DamagedColor;
			fixed _CrackedIntensity;
			fixed4 _CrackedColor;

			float triWave(float t, float offset, float yOffset)
			{
				return saturate(abs(frac(offset + t) * 2 - 1) + yOffset);
			}

			fixed4 texColor(v2f i, float rim)
			{
				fixed4 mainTex = tex2D(_MainTex, i.uv);
				mainTex.r *= triWave(_Time.x * 5, abs(i.objectPos.y) * 2, -0.7) * 6;
				// I ended up saturaing the rim calculation because negative values caused weird artifacts
				mainTex.g *= saturate(rim) * (sin(_Time.z + mainTex.b * 5) + 1);
				fixed4 _Color1 = fixed4(lerp(_HealthyColor, _MiddleColor,_CrackedIntensity));
				fixed4 _Color2 = fixed4(lerp(_MiddleColor, _DamagedColor, _CrackedIntensity));
				fixed4 _Color = fixed4(lerp(_Color1, _Color2, _CrackedIntensity));
				return mainTex.r * _Color + mainTex.g * _Color;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float screenDepth = DecodeFloatRG(tex2D(_CameraDepthNormalsTexture, i.screenuv).zw);
				float diff = screenDepth - i.depth;
				float intersect = 0;
				
				intersect = (diff > 0) * intersect + (diff <= 0) * (1 - smoothstep(0, _ProjectionParams.w * 0.5, diff));

				float rim = 1 - abs(dot(i.normal, normalize(i.viewDir))) * 2;
				float northPole = (i.objectPos.y - 0.45) * 20;
				float glow = max(max(intersect, rim), northPole);

				fixed4 _Color1 = fixed4(lerp(_HealthyColor, _MiddleColor, _CrackedIntensity));
				fixed4 _Color2 = fixed4(lerp(_MiddleColor, _DamagedColor, _CrackedIntensity));
				fixed4 _Color = fixed4(lerp(_Color1, _Color2, _CrackedIntensity));
				fixed4 glowColor = fixed4(lerp(_Color.rgb, fixed3(1, 1, 1), pow(glow, 4)), 1);
				
				fixed4 hexes = texColor(i, rim);
				fixed4 cracksAdd = tex2D(_CrackedTex, i.crackedUV);
				fixed4 cracksSub = (2 * cracksAdd - 1) * _CrackedIntensity;
				fixed4 cracksColor = cracksAdd * _CrackedColor * _CrackedIntensity;
				//fixed4 cracks = ( 2*tex2D(_CrackedTex, i.crackedUV) - 1) * _CrackedColor;
				//cracks *= _CrackedIntensity;
				fixed4 crackWave = cracksAdd * _CrackedIntensity * triWave(_Time.x * 5, abs(i.objectPos.y) * 2, -0.7) * 6;
				fixed4 crackFinal = 0.5* cracksColor + crackWave + 0.2*cracksSub;

				fixed4 col = _Color * _Color.a + glowColor * glow + hexes + crackFinal;
				return col;
			}
			ENDCG
		}
	}
}
