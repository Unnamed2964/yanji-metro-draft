# RMP 导出 SVG：中文站名抬升 1px

> 以下文本由 Cursor 生成，但已经过人工检查确认没有事实性错误

## 背景

Rail Map Painter（RMP）导出本项目制作的线路图 SVG 时，站名通常按「中文 + 朝文 + 英文」三行排版。本项目把朝文填在 RMP 模板的英文字段中；在朝文比英文行高更大的情况下，中文与朝文容易重叠。在这种情况，本项目约定：**中文站名在 RMP 默认位置基础上再向上抬 1px**，作为防重叠补偿。

## 脚本

仓库内脚本：[`scripts/adjust_zh_dy.py`](/scripts/adjust_zh_dy.py)

脚本会扫描 SVG 中 `id="stn_name_…"` 的站名组，将其中 SimHei（黑体）中文 `<text>` 的 `dy="-1"` 批量改为 `dy="-2"`，并写回文件。

## 环境要求

- Python 3.6 及以上
- 无第三方依赖

## 用法

在仓库根目录执行。

### 处理 RMP 线路图（常用）

RMP 中编辑完成后导出 `RMP.svg`，再运行：

```powershell
python scripts/adjust_zh_dy.py RMP.svg
```

### 处理高铁示意图（默认路径）

不传参数时，脚本默认处理 `hsr map/拼接.svg`：

```powershell
python scripts/adjust_zh_dy.py
```

或显式指定：

```powershell
python scripts/adjust_zh_dy.py "hsr map/拼接.svg"
```

### 指定任意 SVG

第一个命令行参数为目标 SVG 路径（相对或绝对均可）：

```powershell
python scripts/adjust_zh_dy.py path/to/your-map.svg
```

## 输出说明

脚本在标准输出打印：

- 匹配到的站名组数量（`groups matched`）
- 实际修改的中文 `<text>` 数量（`zh texts updated`）
- 每个 `stn_name_…` 组内的修改条数

若 `zh texts updated` 为 0，则不会写回文件（`no changes`）。

## 注意事项

- **幂等性**：脚本只匹配 `dy="-1"`。已抬升过的 SVG（`dy="-2"`）再次运行不会产生变化。
- **适用范围**：仅处理 RMP 站名模板结构［`stn_name_*` 组内的 SimHei（黑体）文本］。标题、图例、手动添加的其它文本不受影响。
- **重新导出**：若在 RMP 中重新导出 SVG，请记得重新运行本脚本。
