Shader "Unlit/ListBlending"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_AntiAliasing("AntiAliasing", Int) = 1
	}
	SubShader
	{
		Tags { "Queue" = "Transparent" "IgnoreProjector" = "true" "RenderType" = "Transparent" }
		LOD 100

		Pass
		{
			ZTest Always
			Cull Off
			ZWrite Off

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
				float4 vertex : SV_POSITION;
			};

			struct ListNode
			{
				float4 pixelColor;
				float depth;
				uint next;
				uint coverage;
			};

			StructuredBuffer<ListNode> listNodeBuffer;
			ByteAddressBuffer listHeadBuffer;

			sampler2D _MainTex;
			float4 _MainTex_ST;
			int _AntiAliasing;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				// sample the texture
				//fixed4 col = tex2D(_MainTex, i.uv);
				fixed4 col[8];
				col[0] = tex2D(_MainTex, i.uv);
				for (int index = 1; index < _AntiAliasing; index++)
					col[index] = col[0];

				uint headBufferOffset;
				#if UNITY_UV_STARTS_AT_TOP
					headBufferOffset = 4 * ((_ScreenParams.x * (_ScreenParams.y - i.vertex.y - 0.5)) + (i.vertex.x - 0.5));
				#else
					headBufferOffset = 4 * ((_ScreenParams.x * (i.vertex.y - 0.5)) + (i.vertex.x - 0.5));
				#endif

				uint nodeIndex = listHeadBuffer.Load(headBufferOffset);
				uint sortedNodeIndex[8];
				int count = 0;
				while (nodeIndex != 0)
				{
					sortedNodeIndex[count++] = nodeIndex;
					if (count >= 8)
						nodeIndex = 0;
					else
						nodeIndex = listNodeBuffer[nodeIndex].next;
				}

				for (int i = 0; i < count - 1; i++)
				{
					int max = i;
					for (int j = i + 1; j < count; j++)
						if (listNodeBuffer[sortedNodeIndex[j]].depth > listNodeBuffer[sortedNodeIndex[max]].depth)
							max = j;
					uint temp = sortedNodeIndex[i];
					sortedNodeIndex[i] = sortedNodeIndex[max];
					sortedNodeIndex[max] = temp;
				}

				for (int i = 0; i < count; i++)
				{
					if (_AntiAliasing == 1)
					{
						col[0] = listNodeBuffer[sortedNodeIndex[i]].pixelColor * listNodeBuffer[sortedNodeIndex[i]].pixelColor.a + col[0] * (1 - listNodeBuffer[sortedNodeIndex[i]].pixelColor.a);
					}
					else
					{
						uint coverage = listNodeBuffer[sortedNodeIndex[i]].coverage;
						for (int c = 0; coverage; c++)
						{
							if (coverage & 1)
								col[c] = listNodeBuffer[sortedNodeIndex[i]].pixelColor * listNodeBuffer[sortedNodeIndex[i]].pixelColor.a + col[c] * (1 - listNodeBuffer[sortedNodeIndex[i]].pixelColor.a);
							coverage >>= 1;
						}
					}
				}

				fixed4 resolveColor = col[0];
				for (int index = 1; index < _AntiAliasing; index++)
					resolveColor += col[index];

				return resolveColor / _AntiAliasing;
			}
			ENDCG
		}
	}
}
