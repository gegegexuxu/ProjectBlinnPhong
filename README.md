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

## 声明

本项目为个人学习项目，采用 MIT 许可证，仅覆盖本项目中由作者自行编写的代码与资源。
