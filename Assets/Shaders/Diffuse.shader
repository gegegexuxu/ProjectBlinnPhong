Shader "Custom/Diffuse"
{
    Properties
    {
        _Ka ("环境光反射系数", Color) = (0.5, 0.5, 0.5, 1)
        _Ia ("环境光强度", Color) = (0.3, 0.3, 0.3, 1)
        
        _Kd ("漫反射系数", Color) = (0.5, 0.5, 0.5, 1)
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
                float3 normal : NORMAL;     // 顶点法线
            };

            struct v2f
            {
                float4 pos : SV_POSITION;           // 裁剪空间位置
                float3 world_normal : TEXCOORD0;    // 世界空间法线（传递给片元）
            };

            float4 _Ka;
            float4 _Ia;
            float4 _Kd;

            v2f vert (appdata v)
            {
                v2f o;
                // 顶点变换
                o.pos = UnityObjectToClipPos(v.vertex);
                // 法线转世界空间
                o.world_normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 world_normal = normalize(i.world_normal);
                float3 light_dir = normalize(_WorldSpaceLightPos0.xyz);

                // 环境光
                fixed3 la = _Ka.rgb * _Ia.rgb;

                // 漫反射
                fixed3 ld = _Kd.rgb * _LightColor0.rgb * max(0, dot(world_normal, light_dir));
                
                // 最终颜色
                fixed3 final_color = la + ld;
                return fixed4(final_color, 1.0);
            }
            ENDCG
        }
    }
}
