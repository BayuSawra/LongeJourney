# Longe Journey lore 工具

阶段0 提供两个 lore 工具，帮助你以正典形式维护故事内容：

- `update_lore_index.py`：根据 `lore/` 下的条目自动生成 `lore/INDEX.md`。
- `check_lore_canon.py`：校验 `lore/` 是否符合规范，校验失败时返回非零退出码。

## 使用

在项目根目录运行：

```powershell
python tools/check_lore_canon.py
python tools/update_lore_index.py
```

每次新增或修改 lore 条目后，先运行校验，再重新生成索引。

## 新增内容

### 新增角色

1. 复制 `lore/characters/protagonist.md` 的格式，在 `lore/characters/` 下新建文件。
2. 文件名使用小写连字符英文，例如 `alice-reed.md`。
3. `- 状态:` 只能写 `unknown`、`alive`、`dead`、`missing`、`sealed`、`destroyed`。
4. `- 已知信息:` 下每一条都以 `（来源：...）` 结尾。
5. 运行两个脚本。

### 新增地点 / 物品

方式同上，分别放在 `lore/locations/` 和 `lore/items/`，套用同目录已有文件的字段。

### 新增事件

1. 在 `lore/events/` 新建小写连字符文件名的 Markdown 文件。
2. 至少填写 `时间`、`地点`、`参与角色`、`结果`、`来源` 字段。
3. 运行两个脚本。

### 新增伏笔

1. 打开 `lore/plot-threads.md`，在末尾新增一个 `## 伏笔名` 小节。
2. 节内必须有 `- 状态:`，只允许 `open`、`paid-off`、`abandoned`。
3. 建议同时填写 `埋设`、`回收`、`关联角色/地点`、`说明`。
4. 运行两个脚本。

## 链接规范

- 条目内指向其他条目的链接一律相对 `lore/` 写，例如 `[医院](locations/hospital.md)`。
- 校验脚本会检查这些链接目标是否存在。

## 校验失败怎么办

- 看报错给出的文件与字段，按报错修复后重新运行 `python tools/check_lore_canon.py`。
- 常见问题：已知信息漏写来源、事件没有来源、文件名不是小写连字符、链接目标写错、伏笔状态写错。
- 校验通过后再运行 `python tools/update_lore_index.py`，让 `lore/INDEX.md` 与实际内容保持一致。
