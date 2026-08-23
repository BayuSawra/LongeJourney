# Longe Journey 内容工具统一契约

## 命令入口

统一入口为 `tools/lj_cli.py`：

- `check-lore`：校验 `lore/` 是否符合格式与目录约定，失败返回非零退出码
- `update-index`：重新生成 `lore/INDEX.md`
- `export-lore`：批量导出 `lore/`（含 `INDEX.md`）到 zip 或目录
- `import-lore`：从 zip 或目录批量导入 `lore/`，导入后自动重建 `INDEX.md` 并执行 `check-lore`

常用示例：

```powershell
python tools/lj_cli.py check-lore
python tools/lj_cli.py update-index
python tools/lj_cli.py export-lore --out lore-backup.zip
python tools/lj_cli.py export-lore --out D:/lore-export
python tools/lj_cli.py import-lore --from lore-backup.zip
python tools/lj_cli.py import-lore --from D:/lore-export
```

旧脚本 `tools/check_lore_canon.py`、`tools/update_lore_index.py` 保留，但仅作为兼容包装，不再作为新的接口入口。

### 资源导出/备份

按 `docs/resource_manifest.json` 导出/备份资源并做往返校验：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/resource_export_backup.ps1
```

- 备份输出至 `backups/resources/<时间戳>/`
- `backup_manifest.json` 记录资源清单、备份时间，以及每个文件的相对路径、SHA256、大小、字节数
- 导出→导入（还原）→校验通过后输出 `roundtrip=passed validation=passed`

## 导入导出约定

- `export-lore --out xxx.zip`：zip 内条目以 `lore/...` 为前缀，包含 `lore/INDEX.md`
- `export-lore --out 目录`：在目标目录下生成 `lore/`
- `import-lore --from` 接受 zip 或目录；兼容 `lore/...` 布局，也兼容直接包含 `characters/`、`locations/`、`items/`、`events/`、`plot-threads.md`、`INDEX.md` 的展开布局
- 导入路径会做安全检查，拒绝绝对路径、`..` 或越出 `lore/` 的条目

## 项目根目录

命令默认以 `tools/lj_cli.py` 所在位置的上级目录作为项目根。也可用 `--root` 显式指定项目根，相对路径和绝对路径都支持：

```powershell
python tools/lj_cli.py --root . check-lore
python tools/lj_cli.py --root D:/AnyProject update-index
```

## 工作流约定

每次新增或修改 lore 内容后：

1. 先运行 `check-lore`
2. 校验通过后再运行 `update-index`
3. `lore/INDEX.md` 为生成文件，不手工编辑

## 目录与文件格式

- `lore/characters/`、`lore/locations/`、`lore/items/`、`lore/events/`：条目文件名使用小写连字符英文，如 `alice-reed.md`
- 每个条目文件只有一个一级标题 `# ...`
- 角色/地点/物品的“已知信息”列表每条以 `（来源：...）` 结尾
- 事件条目必须有 `来源` 字段
- `lore/plot-threads.md` 使用 `## 伏笔名` 小节，状态只允许 `open` / `paid-off` / `abandoned`
- 条目内指向其他条目的链接统一相对 `lore/` 书写，且目标必须存在，例如 `[地点](locations/hospital.md)`

## 校验失败时的处理

`check-lore` 会列出具体文件与规则问题并返回非零退出码。修复后重新运行校验，再生成索引：

```powershell
python tools/lj_cli.py check-lore
python tools/lj_cli.py update-index
```
