Shader "Custom/Ambient"
{
    Properties
    {
        _Ka ("环境光反射系数", Color) = (0.5, 0.5, 0.5, 1)
        _Ia ("环境光强度", Color) = (0.3, 0.3, 0.3, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;   // 顶点位置
            };

            struct v2f
            {
                float4 pos : SV_POSITION;   // 裁剪空间位置
            };

            float4 _Ka;
            float4 _Ia;

            v2f vert (appdata v)
            {
                v2f o;
                // 顶点变换
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 环境光
                fixed3 la = _Ka.rgb * _Ia.rgb;

                // 最终颜色
                fixed3 final_color = la;
                return fixed4(final_color, 1.0);
            }
            ENDCG
        }
    }
}
