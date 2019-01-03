Shader "Unlit/ListBlending"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
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
			};

			StructuredBuffer<ListNode> ListNodeBuffer;
			ByteAddressBuffer ListHeadBuffer;

			sampler2D _MainTex;
			float4 _MainTex_ST;

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
				fixed4 col = tex2D(_MainTex, i.uv);

				uint HeadBufferOffset;
				#if UNITY_UV_STARTS_AT_TOP
					HeadBufferOffset = 4 * ((_ScreenParams.x * (_ScreenParams.y - i.vertex.y - 0.5)) + (i.vertex.x - 0.5));
				#else
					HeadBufferOffset = 4 * ((_ScreenParams.x * (i.vertex.y - 0.5)) + (i.vertex.x - 0.5));
				#endif	

				uint NodeIndex = ListHeadBuffer.Load(HeadBufferOffset);
				uint SortedNodeIndex[8];
				int count = 0;
				while (NodeIndex != 0)
				{
					SortedNodeIndex[count++] = NodeIndex;
					if (count >= 8)
						NodeIndex = 0;
					else
						NodeIndex = ListNodeBuffer[NodeIndex].next;
				}

				for (int i = 0; i < count - 1; i++)
				{
					int max = i;
					for (int j = i + 1; j < count; j++)
						if (ListNodeBuffer[SortedNodeIndex[j]].depth > ListNodeBuffer[SortedNodeIndex[max]].depth)
							max = j;
					uint temp = SortedNodeIndex[i];
					SortedNodeIndex[i] = SortedNodeIndex[max];
					SortedNodeIndex[max] = temp;
				}

				for (int i = 0; i < count; i++)
				{
					col = ListNodeBuffer[SortedNodeIndex[i]].pixelColor * ListNodeBuffer[SortedNodeIndex[i]].pixelColor.a + col * (1 - ListNodeBuffer[SortedNodeIndex[i]].pixelColor.a);
				}

				return col;
			}
			ENDCG
		}
	}
}
