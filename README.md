# Project BlinnPhong

用 Unity 手写经典光照模型：环境光、兰伯特漫反射与 Blinn-Phong 高光。

## 关于

本项目为个人学习与实践作品，基于 Unity Built-in 渲染管线，使用 ShaderLab / CG 从零实现三种经典光照模型，并在同一场景中直观对比三者的渲染效果：

- **AmbientLight** —— 环境光
- **LambertDiffuse** —— 兰伯特（Lambert）漫反射
- **BlinnPhong** —— Blinn-Phong 高光

场景中的模型可通过鼠标 / 触摸拖拽旋转（`Assets/Scripts/Control.cs`），便于从不同角度观察光照变化。光照模型的推导与原理详见 [Docs/BlinnPhong模型详解.md](Docs/BlinnPhong模型详解.md)。

## 声明

本项目为个人学习项目，采用 MIT 许可证，仅覆盖本项目中由作者自行编写的代码与资源。

## 技术环境

| 项 | 值 |
| --- | --- |
| 引擎 | Unity |
| 编辑器版本 | 2022.3.55f1 (9f374180d209) |
| 渲染管线 | Built-in |
| 目标平台 | 不限（无平台特定功能） |

## 作者

- 个人技术分享博客：[www.gexu.games](https://www.gexu.games)
