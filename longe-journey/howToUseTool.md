# 工具使用说明

本文档记录本仓库中已经制作、可直接调用的工具，包括名称、储存位置、用途和使用方式，方便后续拓展内容时查阅与登记。

## 一、工具总览

| 工具名称 | 储存位置 | 用途 |
| --- | --- | --- |
| 统一 CLI（`lj_cli.py`） | `tools/lj_cli.py` | 主线 Lore 管理入口，提供检查、重建索引、导出、导入命令 |
| 旧版 Lore 检查脚本（`check_lore_canon.py`） | `tools/check_lore_canon.py` | 旧版薄壳，无参数，调用统一 CLI 的 `check-lore` 逻辑 |
| 旧版索引重建脚本（`update_lore_index.py`） | `tools/update_lore_index.py` | 旧版薄壳，无参数，调用统一 CLI 的 `update-index` 逻辑 |
| Twine 迁移脚本（`extract_twine.py`） | `tools/extract_twine.py` | 临时辅助脚本，从旧 Twine 导出 HTML 提取剧情文本 |
| 资源引用扫描脚本 | `scripts/resource_reference_scan.ps1` | 扫描 `docs/`、`lore/`、`scenes/`、`scripts/` 中的 `res://` 引用，生成引用清单 |
| 资源引用校验脚本 | `scripts/resource_reference_validate.ps1` | 对照资源清单与引用清单，检查缺失、孤儿、不一致项 |
| 资源导出备份脚本 | `scripts/resource_export_backup.ps1` | 按资源清单备份资源文件及 `.import` 文件，记录校验值 |

## 二、前置条件

- Python 3.10 及以上（`lj_cli.py` 使用了 `list[str]`、`Path | None` 等新语法）
- PowerShell 5.1 及以上
- Godot 4.6.2（仅 `resource_export_backup.ps1` 可选需要，用于 headless 导入刷新 `.import` 文件）

## 三、Lore 工具

### 1. 统一 CLI：`tools/lj_cli.py`

这是当前推荐使用的入口。默认以脚本上级目录作为项目根目录，也可以通过 `--root` 指定其他路径。

全局参数：

| 参数 | 说明 |
| --- | --- |
| `--root PATH` | 指定项目根目录，默认使用脚本所在目录的上级目录 |

子命令：

| 子命令 | 参数 | 说明 |
| --- | --- | --- |
| `check-lore` | 无 | 检查 Lore 条目格式、索引一致性等，有问题会输出错误信息 |
| `update-index` | 无 | 扫描 `lore/` 并重建 `INDEX.md`（不要手工编辑索引） |
| `export-lore` | `--out <zip 或目录>` | 导出全部 Lore。导出为 zip 时条目以 `lore/...` 为前缀；导出为目录时会在目标目录下生成 `lore/` |
| `import-lore` | `--from <zip 或目录>` | 从 zip 或目录导入 Lore，导入后自动重建 `INDEX.md` 并执行 `check-lore` |

使用示例：

```powershell
# 检查 Lore
python tools/lj_cli.py check-lore

# 重建索引
python tools/lj_cli.py update-index

# 导出为 zip
python tools/lj_cli.py export-lore --out lore-backup.zip

# 导入 zip
python tools/lj_cli.py import-lore --from lore-backup.zip

# 指定项目根目录
python tools/lj_cli.py --root . check-lore
```

### 2. 旧版薄壳脚本

以下两个脚本保持向后兼容，无命令行参数，内部直接调用统一 CLI 的对应逻辑。

```powershell
python tools/check_lore_canon.py
python tools/update_lore_index.py
```

## 四、Twine 迁移工具

`tools/extract_twine.py` 是临时迁移辅助脚本，仅用于从旧 Twine HTML 中提取剧情文本。

- 无命令行参数
- 源 HTML 路径硬编码为 `D:\LongeJourney\长路漫记\长路漫记.html`
- 输出文件：`tools/_twine_extract.txt`（生成产物，供后续迁移使用）

```powershell
python tools/extract_twine.py
```

> 注意：该脚本是迁移专用工具，不是通用 CLI，源路径和输出路径如需调整请直接改脚本。

## 五、资源管理工具

这三个 PowerShell 脚本配合 `docs/resource_manifest.json` 使用。执行策略受限时，请加 `-ExecutionPolicy Bypass`。

### 1. 资源引用扫描：`scripts/resource_reference_scan.ps1`

扫描 `docs/`、`lore/`、`scenes/`、`scripts/` 中的 `res://` 引用，并把结果写入 `docs/resource_references.json`。无参数。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/resource_reference_scan.ps1
```

### 2. 资源引用校验：`scripts/resource_reference_validate.ps1`

对照 `docs/resource_manifest.json` 与 `docs/resource_references.json`，检查缺失资源、孤儿资源和清单不一致项，结果写入 `docs/resource_validation.json`。发现异常时脚本返回非零退出码。

参数（均有默认值）：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `-ManifestPath` | `docs/resource_manifest.json` | 资源清单路径 |
| `-ReferencesPath` | `docs/resource_references.json` | 引用清单路径 |
| `-OutputPath` | `docs/resource_validation.json` | 校验结果输出路径 |

```powershell
powershell -ExecutionPolicy Bypass -File scripts/resource_reference_validate.ps1
powershell -ExecutionPolicy Bypass -File scripts/resource_reference_validate.ps1 -OutputPath docs/my_validation.json
```

### 3. 资源导出备份：`scripts/resource_export_backup.ps1`

按 manifest 备份资源文件及对应的 `.import` 文件，输出到 `backups/resources/yyyyMMdd-HHmmss/`，内含 `backup_manifest.json`，记录每个文件的 SHA256 并做 roundtrip 校验。可选调用 Godot headless 执行 `--import` 刷新资源导入。

参数：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `-ManifestPath` | `docs/resource_manifest.json` | 资源清单路径 |
| `-BackupRoot` | `backups/resources` | 备份根目录 |
| `-GodotExe` | `E:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64.exe` | Godot 可执行文件路径 |
| `-SkipGodot` | `$false` | 跳过 Godot headless 导入步骤 |

```powershell
# 完整备份（含 Godot 导入刷新）
powershell -ExecutionPolicy Bypass -File scripts/resource_export_backup.ps1

# 只备份文件，不调用 Godot
powershell -ExecutionPolicy Bypass -File scripts/resource_export_backup.ps1 -SkipGodot
```

## 六、拓展指南

新增工具时建议遵守以下约定：

1. 新工具放入 `tools/`（Python）或 `scripts/`（PowerShell），命名与用途一致。
2. 在本文件总览表登记新工具，并在 `tools/README.md` 同步补充说明。
3. `INDEX.md` 由 `update-index` 自动生成，不要手工编辑。
4. 生成的临时文件（如 `tools/_twine_extract.txt`）不属于正式工具，勿把它当作源码提交。
5. 涉及 Lore 的工具优先复用 `lj_cli.py` 的逻辑，避免新旧入口行为分叉。
