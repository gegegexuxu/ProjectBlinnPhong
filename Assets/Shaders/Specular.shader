Shader "Custom/Specular"
{
    Properties
    {
        _Ka ("环境光反射系数", Color) = (0.5, 0.5, 0.5, 1)
        _Ia ("环境光强度", Color) = (0.3, 0.3, 0.3, 1)
        
        _Kd ("漫反射系数", Color) = (0.5, 0.5, 0.5, 1)
        
        [Toggle]
        _UseBlinnPhong ("启用半程向量优化", Float) = 1
        _Ks ("高光颜色", Color) = (1, 1, 1, 1)
        _P ("高光锐度", Range(1, 100)) = 50
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
                float3 world_pos : TEXCOORD1;
            };

            float4 _Ka;
            float4 _Ia;
            float4 _Kd;
            float4 _Ks;
            float _UseBlinnPhong;
            float _P;

            v2f vert (appdata v)
            {
                v2f o;
                // 顶点变换
                o.pos = UnityObjectToClipPos(v.vertex);
                // 法线转世界空间
                o.world_normal = UnityObjectToWorldNormal(v.normal);
                // 顶点世界坐标（用于计算视线方向）
                o.world_pos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 法线方向
                float3 world_normal = normalize(i.world_normal);
                // 光源方向
                float3 light_dir = normalize(_WorldSpaceLightPos0.xyz);
                // 视线方向
                float3 view_dir = normalize(UnityWorldSpaceViewDir(i.world_pos));

                // 环境光
                fixed3 la = _Ka.rgb * _Ia.rgb;

                // 漫反射
                fixed3 ld = _Kd.rgb * _LightColor0.rgb * max(0, dot(world_normal, light_dir));

                // 高光(平行光源不考虑衰减)
                fixed3 ls;
                if (_UseBlinnPhong > 0.5)
                {
                    // 半程向量
                    float3 half_dir = normalize(light_dir + view_dir);
                    ls = _Ks.rgb * _LightColor0.rgb * pow(max(0, dot(world_normal, half_dir)), _P);
                }
                else
                {
                    // 反射向量
                    float3 reflect_dir = reflect(-light_dir, world_normal);
                    ls = _Ks.rgb * _LightColor0.rgb * pow(max(0, dot(view_dir, reflect_dir)), _P);
                }
                
                // 最终颜色
                fixed3 final_color = la + ld + ls;
                return fixed4(final_color, 1.0);
            }
            ENDCG
        }
    }
}
