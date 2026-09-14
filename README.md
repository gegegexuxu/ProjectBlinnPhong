# Project BlinnPhong

用 Unity 手写经典光照模型：环境光、兰伯特漫反射与 Blinn-Phong 高光。

[个人技术分享博客](https://www.gexu.games) · [光照模型专栏](https://www.gexu.games/#/column/lighting-models)

## 关于

本项目为个人学习与实践作品，基于 Unity Built-in 渲染管线，使用 ShaderLab / CG 从零实现三种经典光照模型，并在同一场景中直观对比三者的渲染效果：

| 着色器 | 光照模型 | 公式构成 |
| --- | --- | --- |
| Custom/Ambient | 环境光 | 环境光 |
| Custom/Diffuse | 兰伯特（Lambert）漫反射 | 环境光 + 漫反射 |
| Custom/Specular | Phong / Blinn-Phong 高光 | 环境光 + 漫反射 + 高光 |

其中 Specular 着色器内置开关（`_UseBlinnPhong`），可在 Phong（反射向量）与 Blinn-Phong（半程向量）两种高光计算方式间切换，直观对比二者的差异。

场景中的模型可通过鼠标 / 触摸拖拽旋转，便于从不同角度观察光照变化。

## 技术环境

| 项 | 值 |
| --- | --- |
| 引擎 | Unity |
| 编辑器版本 | 2022.3.55f1 (9f374180d209) |
| 渲染管线 | Built-in |
| 目标平台 | 不限（无平台特定功能） |

## WebGL 构建与单文件导出

Unity 导出的 WebGL 版本默认是一组文件（`index.html` + `Build/`），且压缩后的 `.br` 文件必须由服务器带 `Content-Encoding: br` 响应头才能加载，无法直接双击打开。

仓库内置打包脚本可将整个构建内联为**单个 HTML 文件**（`framework` 直接内联，`data` / `wasm` 以 base64 内嵌并拦截 `fetch` 从内存应答），不发起任何网络请求，可直接以 `file://` 双击打开：

```bash
# 前置: 先在 Unity 中执行一次 WebGL Build, 产出 Build/ 目录
node Tools/make-single-html.mjs Build Dist/ProjectBlinnPhong.html
```

> **注意：** 当前 `Build/` 产物存在引擎/数据版本不匹配问题（引擎 wasm 期望 `2022.3.55f1c1`（团结引擎构建），数据文件由标准 Unity 序列化为 `2022.3.55f1`），在所有浏览器中启动即报 `Invalid serialized file version`。经排查，该问题源自 `H:\2022.3.55f1` 编辑器安装本身——其 `Data/PlaybackEngines/WebGLSupport/BuildTools/lib/` 下的引擎静态库为团结引擎 (c1) 版本，与编辑器主体的标准版本不一致。重新安装官方完整的 Unity 2022.3.55f1（或改用团结引擎完整版构建）后重新 Build，再运行打包脚本即可。

## 声明

本项目为个人学习项目，采用 MIT 许可证，仅覆盖本项目中由作者自行编写的代码与资源。
