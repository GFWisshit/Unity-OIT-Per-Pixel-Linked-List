﻿Shader "Unlit/ListCreation"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" "IgnoreProjector" = "true" "RenderType" = "Transparent" }
        LOD 100

        Pass
        {
			//ZTest Always
			ZWrite Off
			ColorMask 0

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma target 5.0
			#pragma enable_d3d11_debug_symbols

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
				float4 scrPos : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

			struct ListNode
			{
				float4 pixelColor;
				float depth;
				uint next;
				uint coverage;
			};

			RWStructuredBuffer<ListNode> listNodeBuffer : register(u1);
			RWByteAddressBuffer listHeadBuffer : register(u2);

            sampler2D _MainTex;
            float4 _MainTex_ST;
			sampler2D _CameraDepthTexture;
			fixed4 _Color;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.scrPos = ComputeScreenPos(o.vertex);
                return o;
            }

            fixed4 frag (v2f i, in uint coverage : SV_Coverage) : SV_Target
            {
                // sample the texture
                // fixed4 col = tex2D(_MainTex, i.uv);
				fixed4 col = _Color;

				float depth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.scrPos));

				if (Linear01Depth(i.vertex.z) <= Linear01Depth(depth))
				{
					uint count = listNodeBuffer.IncrementCounter();
					uint headBufferOffset = 4 * ((_ScreenParams.x * (i.vertex.y - 0.5)) + (i.vertex.x - 0.5));
					uint oldHeadNodeIndex;
					listHeadBuffer.InterlockedExchange(headBufferOffset, count, oldHeadNodeIndex);
					ListNode node;
					node.pixelColor = col;
					node.depth = Linear01Depth(i.vertex.z);
					node.next = oldHeadNodeIndex;
					node.coverage = coverage;
					listNodeBuffer[count] = node;
				}
                return col;
            }
            ENDCG
        }
    }
}
