# 逃课模拟器

Godot 4.6 课堂潜行原型。玩家观察老师动向，以课桌为掩体，向宿舍出口门移动。

## 运行方式

在 Godot 中打开此文件夹并运行主场景：

- 项目文件：`project.godot`
- 主场景：`welcome.tscn`
- 视口分辨率：`1050x620`

## 玩法规则

- 老师在黑板前水平巡逻。
- 老师面向教室时，会显示一个锥形视野区域。
- 玩家在以下任一条件成立时被抓住：
  - 玩家位于第一排课桌之上。
  - 玩家处于老师视野锥形范围内，且没有课桌阻挡玩家的垂直遮挡线。
- 被抓住的第一帧，老师会显示一个愤怒对话气泡。老师和玩家都会暂停足够长的时间以便阅读气泡内容；之后玩家被强制送回出生点，输入暂时禁用。
- 被抓住 3 次后，游戏结束并显示 `你已成为老师关注对象`。
- 游戏结束弹窗绘制在场景之上，包含一个 `重新开始` 按钮，点击后重新加载当前场景。
- 课桌是天然掩体。遮挡检测从玩家位置向上朝老师的 y 位置投射射线，将 `Desks/Desk*` 物体视为遮挡物。
- 宿舍出口是房间右下角的棕色门。
- 到达门口后切换到 `building_downstairs.tscn`，而非显示胜利消息。

## 项目结构

- `welcome.tscn` - `逃课模拟器` 的启动欢迎界面，包含生成的像素风格封面图以及 `开始游戏` 和 `退出游戏` 按钮。
- `welcome.gd` - 欢迎界面按钮逻辑；开始进入 `main.tscn`，退出来退出游戏。
- `dorm_building.tscn` - 宿舍楼下场景；使用白色大理石地板和一个复用教室移动/动画设置的玩家角色。第二行和第四行的楼层网格行是独立的单元格障碍物，装饰为像素风格宿舍房间，第二行第五个单元格为开放状态。
- `dorm_building.gd` - 将宿舍楼下单元格障碍物装饰为带 3D 房间立面的像素宿舍房间；第二行房间显示较低的前门，第四行房间显示半透明的上方前门，场景顶部添加木质门楣。当玩家站在任意宿舍门/门楣附近时，气泡提示 `按F进入宿舍`；按 F 键将玩家隐藏在该宿舍内，再次按 F 键从同一扇门退出。
- 在 `dorm_building.tscn` 中，被宿管发现会显示该宿管的 `想溜走？快回教室！` 气泡，然后重新加载当前宿舍楼关卡，玩家和宿管从出生状态重新开始。被发现次数在重新加载后保留；累计 3 次后，弹窗显示 `你被宿管记住了`，并提供 `重新开始` 和 `从此关重新开始`。
- 左下角的 `Row4Col1` 宿舍是胜利目标。按 F 进入后打印 `成功回到宿舍，游戏胜利`。
- `Row4Col1` 以金色高亮和 `我的宿舍` 标识进行视觉标记，便于玩家快速识别。
- `dorm_supervisor.gd` - `dorm_building.tscn` 中三个可视化宿管使用的无碰撞宿管巡逻逻辑。
- `building_downstairs.tscn` - 教学楼楼下场景；可过渡到 `dorm_building.tscn`。
- `main.tscn` - 教室场景，包含节点、碰撞形状、视觉装饰和导出的节点路径。
- `building_downstairs.gd` - 楼下场景逻辑。
- `main.gd` - 根场景辅助函数，包括重新开始按钮的回调。
- `teacher.gd` - 老师巡逻、转身计时、锥形视野、愤怒气泡、行走动画、写字动画。
- `player.gd` - 玩家移动、最低 y 边界、朝向、行走动画。左右移动时精灵旋转面向移动方向。
- `player.gd` 同时保存出生位置，并在被抓住后处理强制返回。
- `desks.gd` - 为 `Desks` 下的每张课桌应用 `assets/desk.png`。
- `dorm.gd` - 门过渡逻辑。
- `assets/` - 生成的像素风格 PNG 精灵和 Godot 导入元数据。

## 像素素材

当前已生成的素材：

- `assets/teacher.png`
- `assets/teacher_write.png`
- `assets/player.png`
- `assets/desk.png`
- `assets/door.png`
- `assets/blackboard.png`
- `assets/welcome_cover.png`

将精灵放在 `Sprite2D` 上时使用最近邻过滤（`texture_filter = 1`）以保留像素风格。

## 调参要点

`teacher.gd` 中老师的导出参数：

- `patrol_left_x`、`patrol_right_x` - 沿黑板的巡逻范围。
- `vision_range`、`vision_half_angle_degrees`、`vision_segments` - 视野锥形区域的行为和显示。
- `first_desk_row_y` - 第一排课桌的 y 阈值，超过此线即判定为被抓状态。
- `min_move_time`、`max_move_time`、`min_blackboard_time`、`max_blackboard_time` - 老师状态的时间参数。
- `max_caught_count` - 游戏结束前被抓的最大次数。

`player.gd` 中玩家的导出参数：

- `speed` - 移动速度。
- `min_y` - 防止玩家走到教室游戏区域上方过远的位置。
- `forced_return_speed` - 老师将玩家送回出生点时使用的速度。
- `forced_return_delay` - 强制返回开始前的暂停时间；老师根据 `anger_bubble_time` 设置。

在 `building_downstairs.tscn` 中，本地 `Player` 使用 `min_y = 0.0`，因此教室的上边界规则不会限制楼下场景。

`dorm_building.tscn` 中宿舍楼下宿管的巡逻：

- `SupervisorRow1` 在第一行楼层网格行内随机水平巡逻，每次转向前暂停。
- `SupervisorCol5` 在第五列楼层网格列内随机垂直巡逻，每次转向前暂停。
- `SupervisorRow3` 在第三行楼层网格行内随机水平巡逻，每次转向前暂停。
- 每次暂停后，宿管在相反方向选择一个随机目标。`SupervisorRow1` 从左侧开始先向右移动；另外两个宿管随机生成出生点和初始方向。
- 宿管在其当前朝向上监视所在行或列的整条直线。检测包含玩家的碰撞体积，因此即使紧贴房间方块或屏幕边缘，只要玩家在视线内仍会被发现。
- 宿管是 `Node2D` 视觉巡逻对象，无物理碰撞，因此与玩家、房间或其他宿管重叠不会阻碍移动。

## 开发注意事项

- 更改课桌外观时不要删除 `StaticBody2D` 节点或碰撞形状；检测和遮挡依赖它们。
- 如果添加更多课桌，请将其放在 `Desks` 节点下，并以 `Desk` 前缀命名，以确保遮挡检测和 `desks.gd` 正常工作。
- 保持 `Teacher/AngerBubble` 通过 `anger_bubble` 与老师关联。
- 保持 `GameOverPopup` 通过 `game_over_popup` 与老师关联。
- 保持 `Player/Sprite2D` 和 `Teacher/Sprite2D` 路径不变，除非需要更新脚本中的导出路径。