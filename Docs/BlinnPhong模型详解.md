# Blinn-Phong 光照模型:从理论到逐行代码实现

> 本文以本项目 `Assets/Shaders/BlinnPhong.shader`(环境光 + 漫反射 + 高光,A+D+S 完整经验模型)为蓝本,
> 先讲清每一项的数学来源,再逐行拆解手写实现,最后附上本项目调试过程中踩过的真实深坑。
> 配套的递进 shader:`AmbientLight.shader`(仅 A)→ `LambertDiffuse.shader`(A+D)→ `BlinnPhong.shader`(A+D+S)。

---

## 目录

1. [理论篇:三项从哪来](#1-理论篇三项从哪来)
2. [完整公式与向量关系图](#2-完整公式与向量关系图)
3. [代码篇:Shader 骨架](#3-代码篇shader-骨架)
4. [代码篇:逐行解析](#4-代码篇逐行解析)
5. [手写实现的关键决策](#5-手写实现的关键决策)
6. [调试实录:三次"纯黑"事故](#6-调试实录三次纯黑事故)
7. [参数调节实验指南](#7-参数调节实验指南)
8. [局限与下一步:PBR](#8-局限与下一步pbr)

---

## 1. 理论篇:三项从哪来

Blinn-Phong 属于**经验局部光照模型(Empirical Local Illumination Model)**:

- **局部(Local)**:计算一个像素时只考虑"这个表面点 + 光源方向 + 视线方向",不考虑光在场景中的弹射、遮挡传递;
- **经验(Empirical)**:公式形状来自对真实材质的观察拟合,而不是从辐射度学严格推导——所以它快,但物理上有已知缺陷(见第 8 节)。

模型由三项相加:

```
C = 环境光(A) + 漫反射(D) + 高光(S)
```

### 1.1 环境光项 A(Ambient)

**要解决的问题**:局部模型只看直射光,背光面会得到 `N·L = 0`,纯黑。真实世界里背光面被环境弹射光照亮,不是黑的。环境光就是给这个"缺失的间接光"打的一个补丁。

**定义**:与方向基本无关的一个底色亮度。本项目的实现用的是**球谐(SH)环境光**而非单一常量:

- Unity 把场景级的环境光设置(`Window → Rendering → Lighting → Environment`)烘焙成 **9 个球谐系数**(`unity_SHAr/Ag/Ab/Br/Bg/Bb/C`);
- shader 里 `ShadeSH9(半位向量)` 以**世界法线为方向**采样这组系数;
- 因为法线参与了采样,环境光带有低频方向性:朝上的面偏天空色、朝下的面偏地面色——这就是为什么修复后球体"上蓝下灰"。

环境光来源为 **Skybox** 时,系数需要一次 **Generate Lighting(烘焙)** 才会生成;Color/Gradient 来源则是常量、即时生效。这是本项目的踩坑点之一(第 6 节)。

### 1.2 漫反射项 D(Diffuse,Lambert)

**Lambert 余弦定律**:一束平行光以入射角 Θ 照到表面时,单位面积接收到的能量与 `cosΘ` 成正比。

直观推导:光通量 Φ 垂直照射时覆盖面积 A;斜照 Θ 角时同样一束光铺在 `A / cosΘ` 的面积上,单位面积能量自然是 `Φ·cosΘ / A`。而 `cosΘ = N·L`(N 为法线,L 为指向光源的单位向量),于是:

```
L_diffuse = albedo · lightColor · max(0, N·L)
```

三个细节:

- `max(0, ·)`:光从背面来时 `N·L < 0`,负的能量没有物理意义,截断为 0;
- **与视线无关**:理想朗伯体把接收的能量向半球各方向均匀散射,所以这一项不需要视线向量 V——这也是它和 L1 层(纯环境光)一样"转动物体高光不动、但明暗面跟灯走"的原因;
- 物理正确的 Lambert BRDF 是常数 `ρ/π`(保证能量守恒),游戏惯例把 π 折进光强,直接写成上式。本项目遵循游戏惯例。

### 1.3 高光项 S(Specular)

**物理背景**:镜面反射方向上,表面会把光"集中"弹回来。粗糙表面由无数随机朝向的微镜面组成,法线越集中、高光越锐利。

**Phong 的做法(1975)**:先用反射定律算出反射方向 R,再看视线 V 有多接近 R:

```
R = 2·(N·L)·N − L        (把入射方向关于法线镜像)
spec ∝ (R·V)^gloss
```

`R` 的推导:把 L 分解为法向分量 `(N·L)N` 与切向分量 `L − (N·L)N`;反射时法向分量翻转、切向分量不变:

```
R = (L − (N·L)N) − (N·L)N = 2·(N·L)·N − L
```

**Blinn 的改进(1977)**:引入**半程向量 H**——L 与 V 夹角的角平分方向:

```
H = normalize(L + V)
spec ∝ (N·H)^gloss
```

几何含义:若某微面元法线恰好朝向 H,它把 L 镜面反射后正好射向 V(观察者)。于是 `N·H` 直接度量了"有多少比例的微面元参与镜面反射"。相比 Phong:

| | Phong `(R·V)^n` | Blinn `(N·H)^n` |
|---|---|---|
| 计算量 | 一次 reflect + 一次点积 | 一次向量加法 + 一次归一化 + 一次点积 |
| 掠射角高光形状 | 偏离实测 | 更接近实测 |
| 物理解释 | 反射定律 | 微面元法线分布 |

两种 lobe 视觉近似但不完全等价:同样的指数下 Blinn 高光略宽(经验换算 `(N·H)^(4n) ≈ (R·V)^n`,Lyon 1993)。

**gloss 的作用**:`N·H ∈ [0,1]`,指数越大,只有 `N·H` 极接近 1(法线对得极准)的像素才亮——高光小而锐,趋于镜面;指数小则高光大而柔。

**门控项**:高光必须再乘 `max(0, N·L)`。若光在表面背面,镜面反射不可能进入眼睛;但不加门控时 `N·H` 仍可能为正,会在背光面"漏"出高光。

### 1.4 阴影与衰减(atten)

模型三项之外还有一个乘性系数 atten ∈ [0,1]:

- **接收阴影**:表面在别的物体的影子里的比例(ForwardBase 采样屏幕空间阴影图;ForwardAdd 点光/聚光采样阴影贴图);
- **距离衰减**:点光/聚光随距离的衰减曲线(方向光为 1)。

直接光项(D 和 S)乘 atten;**环境光不乘**——它没有方向,谈不上被某个影子挡住。

---

## 2. 完整公式与向量关系图

```
                       N (法线)
                       ↑
                       |     H = normalize(L + V)
                       |    ↗
                       |  ╱         L(指向光源)
        ───────────────●─────────────────  表面点
                      ╱
                     ╱
                    V(指向相机)
```

```
C = albedo ⊗ SH(N)                                      ← 环境光(⊗ 为逐分量乘)
  + [ albedo · lightColor · max(0, N·L)                 ← 漫反射
    + specColor · lightColor · max(0,N·H)^gloss · max(0, N·L)   ← 高光
    ] · shadow · attenuation
```

项目中的三组对照物体质感即由此公式逐项叠加而来:

| 材质 | 公式 |
|---|---|
| Ambient.mat | `albedo · SH(N)` |
| Diffuse.mat | `albedo · SH(N) + albedo·lightColor·(N·L)·atten` |
| Specular.mat | 完整式(多加高光项) |

---

## 3. 代码篇:Shader 骨架

```
Shader "Custom/BlinnPhong"
├── Properties            // 材质面板暴露的参数(名称须与 CG 内 uniform 同名)
├── CGINCLUDE ... ENDCG   // 两个 Pass 共享的 HLSL(结构体/vert/光照函数)
└── SubShader
    ├── Pass  Tags { "LightMode" = "ForwardBase" }   // 环境光 + 主光源,接收阴影
    ├── Pass  Tags { "LightMode" = "ForwardAdd" }    // 其余光源,Blend One One 逐个叠加
    └── FallBack "VertexLit"                         // 借用它的 ShadowCaster 投射阴影
```

两个 Pass 的分工是内置管线 Forward 渲染的规则:

- **ForwardBase**:渲染"环境光 + 最重要的那盏光"(通常是方向光)。一帧只走一次;
- **ForwardAdd**:场景里每多一盏逐像素光源,就用这个 Pass 多画一遍该物体,以加法混合叠上去。环境光、球谐只在 Base 加一次,Add 里重复加就错了。

---

## 4. 代码篇:逐行解析

> 以下代码即 `Assets/Shaders/BlinnPhong.shader` 当前内容,按文件顺序拆解。

### 4.1 属性块

```shaderlab
Properties
{
    _MainTex          ("Albedo (RGB)", 2D) = "white" {}
    _Color            ("Tint (RGBA)", Color) = (1, 1, 1, 1)
    _AmbientIntensity ("Ambient Intensity (环境光强度)", Range(0, 4)) = 1
    _Specular         ("Specular (高光颜色×强度)", Color) = (1, 1, 1, 1)
    _Gloss            ("Glossiness (高光锐度)", Range(1, 256)) = 32
}
```

- 每行语法:`变量名 ("面板显示名", 类型) = 默认值`。**变量名必须与后面 CG 代码里声明的 uniform 同名**,值才能从材质面板流入 shader;
- `2D = "white" {}`:未指定贴图时用全白默认图(乘上去不改变颜色);
- `_Specular` 用 Color 类型,rgb 同时充当"高光颜色 × 强度"——想要更亮的高光,把颜色调过中灰即可;
- `_Gloss` 下限 1:`pow(x, 0)` 会退化,上限 256 对应接近镜面。

### 4.2 公共代码与变量

```shaderlab
CGINCLUDE
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
```

- `CGINCLUDE ... ENDCG` 写在 Shader 块根部:里面的代码会被**原样拼接进每个 Pass 的 CGPROGRAM 之前**,两个 Pass 共用一套函数;
- `UnityCG.cginc`:`UnityObjectToClipPos`、`TRANSFORM_TEX`、`UnityObjectToWorldNormal`、`ShadeSH9` 等工具;
- `Lighting.cginc`:`_LightColor0`、`_WorldSpaceLightPos0` 的声明;
- `AutoLight.cginc`:阴影/光源坐标的一组宏。

```hlsl
sampler2D _MainTex;
float4    _MainTex_ST;
fixed4    _Color;
half      _AmbientIntensity;
fixed4    _Specular;
half      _Gloss;
```

- 与 Properties 一一同名对应;`_MainTex_ST` 是贴图的平铺/偏移(xy=平铺,zw=偏移),由 `TRANSFORM_TEX` 使用;
- `fixed`/`half` 是低精度类型,桌面平台一般等价 float,移动端省带宽。

### 4.3 顶点输入与输出

```hlsl
struct appdata
{
    float4 vertex : POSITION;   // 模型空间顶点坐标
    float3 normal : NORMAL;     // 模型空间法线
    float2 uv     : TEXCOORD0;  // 第一套 UV
    float2 uv1    : TEXCOORD1;  // 第二套 UV:阴影/光照贴图采样要用
};

struct v2f
{
    float4 pos         : SV_POSITION;   // 裁剪空间坐标(光栅化必需)
    float2 uv          : TEXCOORD0;
    float3 worldNormal : TEXCOORD1;
    float3 worldPos    : TEXCOORD2;
    UNITY_LIGHTING_COORDS(3, 4)         // 引擎宏:按需展开为光源/阴影坐标,占用 3、4 号插值器
};
```

- `appdata` 的语义(POSITION/NORMAL/TEXCOORDn)对应网格资源里实际存储的通道,引擎按语义自动喂值;
- `v2f` 的每个 TEXCOORDn 是**光栅化插值器**:顶点着色器写、插值后片段着色器读。同一编号在一个结构体里只能出现一次;
- `worldNormal`、`worldPos` 把光照计算需要的几何量从顶点带到像素——这就是**逐像素光照**与逐顶点 Gouraud 着色的分水岭:低模上明暗条带 vs 干净的光照边界。

### 4.4 顶点着色器

```hlsl
v2f vert (appdata v)
{
    v2f o;
    o.pos         = UnityObjectToClipPos(v.vertex);
    o.uv          = TRANSFORM_TEX(v.uv, _MainTex);
    o.worldNormal = UnityObjectToWorldNormal(v.normal);
    o.worldPos    = mul(unity_ObjectToWorld, v.vertex).xyz;
    UNITY_TRANSFER_LIGHTING(o, v.uv1);
    return o;
}
```

逐行:

- `UnityObjectToClipPos(v.vertex)`:模型空间 → 裁剪空间(内部即 MVP 矩阵连乘);
- `TRANSFORM_TEX(v.uv, _MainTex)`:展开为 `v.uv * _MainTex_ST.xy + _MainTex_ST.zw`,实现材质面板的 Tiling/Offset;
- `UnityObjectToWorldNormal(v.normal)`:法线变换到世界空间。**为什么不是普通 mul 矩阵?**非均匀缩放会把法线拧歪,严格做法要用模型矩阵的**逆转置**;Unity 内部用 `mul(normal, (float3x3)unity_WorldToObject)`(转置乘法的等价形式)处理了这件事;
- `mul(unity_ObjectToWorld, v.vertex).xyz`:顶点的世界坐标,后面算视线 V、点光方向 L、阴影坐标全靠它;
- `UNITY_TRANSFER_LIGHTING(o, v.uv1)`:把第二套 UV 换算成阴影/光照贴图采样坐标存进插值器。

### 4.5 工具与三个光照函数

```hlsl
half3 SafeNormalize (half3 v)
{
    return v * rsqrt(max(dot(v, v), 1e-6));
}
```

`normalize(x)` 内部是 `x * rsqrt(dot(x,x))`,向量长度为 0 时 `rsqrt(0) = +∞` 得到 NaN。`max(·, 1e-6)` 把底数兜住——半程向量 `L + V` 在"视线正对背光"等极限配置下可能接近零向量,这一行是数值安全垫。

```hlsl
half3 AmbientLight (half3 N)
{
    return ShadeSH9(half4(N, 1.0));
}
```

`ShadeSH9` 接收 `half4`,xyz 是采样方向(世界法线),w 固定 1。内部用 9 个系数计算二阶球谐,返回该方向的环境光颜色。

> ⚠️ **本 shader 曾因此纯黑**:使用 ShadeSH9 的 Pass 必须声明 `Tags { "LightMode" = "ForwardBase" }`。无 LightMode 标签的 Pass 按 Always 模式渲染,引擎不上传光照 uniform(包括 unity_SH*),采样恒为 0。

```hlsl
half3 LambertDiffuse (half3 albedo, half3 lightColor, half3 L, half3 N)
{
    L = SafeNormalize(L);
    N = SafeNormalize(N);

    half NdotL = saturate(dot(N, L));
    return albedo * lightColor * NdotL;
}
```

- `dot(N, L)` 即 cosΘi;`saturate` 等价 `max(x, 0)`,把背面截为 0;
- 物理正确形式是 `albedo/π · E0 · NdotL`,游戏惯例把 π 折进光强,这里从惯例。

```hlsl
half3 BlinnPhongSpecular (half3 specColor, half gloss, half3 lightColor,
                          half3 L, half3 V, half3 N)
{
    L = SafeNormalize(L);
    V = SafeNormalize(V);
    N = SafeNormalize(N);

    half3 H = SafeNormalize(L + V);          // ① 半程向量
    half NdotH = saturate(dot(N, H));        // ② 法线与 H 的对齐度
    half spec = pow(NdotH, gloss);           // ③ 幂次锐化
    half NdotL = saturate(dot(N, L));        // ④ 背面门控

    return spec * specColor * lightColor * NdotL;   // ⑤ 组装
}
```

- ① `L + V` 指向两方向的角平分处,归一化后即 H。若某点法线恰等于 H,该点微面元把光正好反射进眼睛,高光峰值就在这里;
- ② `N·H` = 参与镜面反射的微面元比例的度量;
- ③ `pow` 的底数已被 ② 限制在 [0,1],指数 ≥1,无 NaN 风险;
- ④ 光在背面时高光置零,防止 `(N·H)^gloss` 在背光面漏光;
- ⑤ 高光颜色(含强度)× 光源颜色 × 锐化值 × 门控。

### 4.6 片元着色器:ForwardBase

```hlsl
fixed4 fragBase (v2f i) : SV_Target
{
    half3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
    half3 N = normalize(i.worldNormal);
    half3 V = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);

    half3 L = _WorldSpaceLightPos0.xyz;

    half3 diffuse  = LambertDiffuse(albedo, _LightColor0.rgb, L, N);
    half3 specular = BlinnPhongSpecular(_Specular.rgb, _Gloss,
                                        _LightColor0.rgb, L, V, N);

    UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos)

    fixed4 col;
    col.rgb = albedo * AmbientLight(N) * _AmbientIntensity
            + (diffuse + specular) * atten;
    col.a   = _Color.a;
    return col;
}
```

逐行:

- `tex2D(...).rgb * _Color.rgb`:贴图色 × 染色 = 反照率;
- **`normalize(i.worldNormal)` 不能省**:`worldNormal` 是逐顶点法线插值出来的,两个长度为 1 的向量线性插值后长度普遍小于 1 且方向不变性只在同向时成立——必须逐像素重新归一化,V 同理;
- `_WorldSpaceCameraPos.xyz - i.worldPos`:从像素指向相机的向量,归一化得 V;
- ForwardBase 的主光必为方向光,`_WorldSpaceLightPos0.xyz` 直接就是方向(w 分量为 0 是方向光的标志);
- `UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos)`:AutoLight 宏,展开为一条声明+赋值语句(`fixed atten = ...`),**调用处因此按惯例不写分号**。它合并了阴影采样与距离衰减,得到 0~1 的乘性系数;
- 组装式里注意归属:环境光乘 `_AmbientIntensity` 但**不乘 atten**;直接光(D+S)统一乘 atten;
- `_WorldSpaceLightPos0`、`_LightColor0` 由引擎针对"当前 Pass 正在处理的那盏光"自动填值,不需要(也没法)自己遍历光源。

### 4.7 片元着色器:ForwardAdd

```hlsl
fixed4 fragAdd (v2f i) : SV_Target
{
    half3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
    half3 N = normalize(i.worldNormal);
    half3 V = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);

    #ifdef USING_DIRECTIONAL_LIGHT
        half3 L = _WorldSpaceLightPos0.xyz;
    #else
        half3 L = _WorldSpaceLightPos0.xyz - i.worldPos;
    #endif

    half3 diffuse  = LambertDiffuse(albedo, _LightColor0.rgb, L, N);
    half3 specular = BlinnPhongSpecular(_Specular.rgb, _Gloss,
                                        _LightColor0.rgb, L, V, N);
    UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos)

    return fixed4((diffuse + specular) * atten, 1.0);
}
```

- `USING_DIRECTIONAL_LIGHT` 是引擎按编译变体自动定义的宏:这盏附加光是方向光时,`_WorldSpaceLightPos0.xyz` 存方向;是点光/聚光时存**光源位置**,要减去世界坐标才得到方向,距离衰减则由 atten 里的衰减纹理负责;
- 返回值**不含环境光**:`ForwardBase` 已经加过一次,每个附加光源再叠一次环境光就重复计费了;
- Pass 配置 `Blend One One`(结果 = 已有颜色 + 本光源贡献,加法混合)+ `ZWrite Off`(附加 Pass 不参与深度竞争,只往现有画面上"加光")。

### 4.8 Pass 标签与编译变体

```shaderlab
#pragma multi_compile_fwdbase
```

为 ForwardBase 生成一组关键字变体(有无阴影、有无光照贴图、Shadow Mask 等),配合 AutoLight 宏在正确的变体里采样阴影。缺了它,阴影相关宏会退化为常量 1,物体收不到影子。

```shaderlab
#pragma multi_compile_fwdadd_fullshadows
```

ForwardAdd 用。`fwdadd`(不带 fullshadows)只编译方向光阴影;`fwdadd_fullshadows` 额外编译点光/聚光阴影变体——想让点光投影,必须用后者。

```shaderlab
FallBack "VertexLit"
```

本 shader 自己没写 ShadowCaster Pass(投射阴影的 Pass 与光照计算无关,不想重复造轮子),回退到 VertexLit 借它的 ShadowCaster。**投射阴影(写深度到阴影图)与接收阴影(采样阴影图)是两套独立机制**,互不依赖。

---

## 5. 手写实现的关键决策

| 决策 | 理由 |
|---|---|
| 光照全部在片元里算(逐像素) | 逐顶点(Gouraud)会把光照插糊,低模上出现明暗条带;像素级计算量在现代 GPU 上完全可接受 |
| 环境光只在 ForwardBase 加一次 | ForwardAdd 逐光源执行,加环境光会随光源数量被重复累加 |
| 高光乘 `N·L` 门控 | 背光面 `(N·H)^gloss` 仍可能为正,不门控会漏光 |
| `saturate` 代替 `max(0,)` | 同义,语义更"钳位到 [0,1]",可读性好 |
| `SafeNormalize` 防零向量 | `L+V` 在极端视角下接近零向量,`rsqrt(0)=∞` 会产生 NaN 像素 |
| 用 `half` 存中间量 | 桌面无差,移动端省一半寄存器带宽;注意 `L+V` 极端值可能超出 half 上限的场景才需换 float |
| 三个 shader 严格分层 | A → A+D → A+D+S,每层只多一个函数和几行属性,便于逐项对照学习 |

---

## 6. 调试实录:三次"纯黑"事故

本项目实际踩过的三个坑,排查思路比结论更值钱:

### 事故一:Game 视图全黑,Scene 视图却亮

- **现象**:物体在 Scene 视图有光照,Game 视图纯黑。
- **原因**:场景里一个光源都没有。Scene 视图工具栏的"太阳图标"(Toggle Scene Lighting)关闭时,Unity 会用一盏跟随场景相机的**内置演示灯**照亮 Scene 视图——那不是场景里的光。
- **教训**:Scene 视图会"撒谎",Game 视图才是真实渲染结果。

### 事故二:环境光改了数值毫无反应

- **现象**:环境光 shader 的物体恒为纯黑;改天空盒、调颜色、点 Generate Lighting 都无效;而漫反射/高光组响应正常。
- **排查**:`m_AmbientMode: 0`(Skybox 来源)✓、天空盒已指定 ✓、`LightingData.asset` 已生成 ✓、材质/引用链 ✓——磁盘数据全对,断点只能在 shader 内部。
- **原因**:`AmbientLight.shader` 的 Pass **没写 `LightMode` 标签**。无标签 Pass 按 Always 模式渲染,引擎不为它上传任何光照 uniform(含环境光球谐系数),`ShadeSH9` 恒为 0。数据早就绪,只是从未被送进这个 Pass。
- **教训**:**用了 `ShadeSH9`/`_LightColor0`/阴影宏的 Pass,必须声明对应的 `LightMode`**——哪怕逻辑上"不需要光"。

### 事故三:切到 Skybox 环境光后纯黑(误以为 shader 坏了)

- **现象**:环境光来源从 Color 切成 Skybox 后,物体从"暗灰"变成"真黑"。
- **原因**:当时 `m_SkyboxMaterial` 为 None——Skybox 来源的环境光探针从空天空盒生成,结果为 0;后续又发现 `Auto Generate` 关闭且从未烘焙,指定天空盒后仍需点一次 Generate Lighting。
- **教训**:Skybox 来源的环境光需要"天空盒材质 + 生成一次"两个条件;Color/Gradient 来源则是常量即时生效。

> 排查方法论:磁盘上的场景/材质 YAML 是可 grep 的证据,先验证数据链(对象 → 材质 → shader GUID → 引擎设置),再怀疑代码;数据全对时,怀疑引擎契约(LightMode、变体、宏)。

---

## 7. 参数调节实验指南

| 实验 | 操作 | 预期 |
|---|---|---|
| 高光锐度 | `_Gloss` 从 1 拉到 256 | 高光从一大片柔光收缩成一个亮点 |
| 高光着色 | `_Specular` 调成金色 | 金属感高光(近似,真实金属高光应染色于光谱) |
| 环境光强度 | 三种材质的 `_AmbientIntensity` 全拉 0 | 只剩直接光:背光面重新变黑——直观看到环境光在兜什么底 |
| 视角相关性 | 拖转 SphereADS | 高光点随视角移动;漫反射明暗面不随视角变 |
| 光源数量 | 场景加几盏点光 | 每盏光的 D+S 经 ForwardAdd 逐个叠加,各自带阴影与衰减 |
| 对照实验 | 同形状的 A / AD / ADS 三球并排 | 三项各贡献了什么一目了然 |

进阶排查工具:**Frame Debugger**(`Window → Analysis → Frame Debugger`)能看到每个 draw call 用的 shader、材质与全部 uniform 值(包括 unity_SH*),是定位"引擎到底传了什么"的终极手段。

---

## 8. 局限与下一步:PBR

Blinn-Phong 的已知缺陷,也是 PBR 要解决的问题:

1. **能量不守恒**:高光强度不随粗糙度补偿,gloss 小时高光过亮,表面总能量可能超过入射能量;
2. **无菲涅尔效应**:真实表面掠射角反射率升高(水面远处更亮、皮肤边缘泛光),Blinn-Phong 完全没有这一项;
3. **漫反射/高光割裂**:两者相加可能超过 1,物理上应满足能量分配(漫反射 + 镜面 ≤ 入射);
4. `gloss` 与真实微表面粗糙度没有标定关系。

下一步的自然路径:Half-Lambert(风格化柔化)→ Cook-Torrance BRDF / GGX 分布(Unity Standard 与 URP Lit 的核心),其微面元框架正是 Blinn"半程向量 + 法线分布"思想的严格化。

---

*文档对应代码版本:`Assets/Shaders/BlinnPhong.shader`(A+D+S 分层实现的 L3 层)。*
