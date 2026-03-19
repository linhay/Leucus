# Infinite Canvas M1（网点背景 + 空节点卡片）

## 背景
- 当前阶段只做画布基础能力，不做节点类型与终端绑定。
- 画布能力拆分为独立 SPM target，避免和终端逻辑耦合。

## 范围
- 独立 target：`InfiniteCanvasKit`
- 无限画布视口能力：平移、缩放、坐标转换
- 背景样式：网点背景
- 节点形态：空卡片（仅占位，类型待定）

## 非目标
- 不做节点类型系统
- 不做节点拖拽编辑、连线、持久化（M2/M3）
- 不做终端渲染挂载

## BDD 验收场景
1. Given 用户打开 Example
   When 应用完成渲染
   Then 可见网点背景和至少 1 张空卡片

2. Given 用户在画布上拖动/滚动
   When 触发平移
   Then 画布内容可连续移动且无跳变

3. Given 用户进行缩放（pinch 或 Command+滚轮）
   When 缩放围绕锚点计算
   Then 锚点对应世界坐标保持稳定

4. Given 连续极限缩放
   When 超出约束
   Then scale 被 clamp 在最小/最大范围内
