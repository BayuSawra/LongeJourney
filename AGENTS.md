# 开发约定

- 言简意赅，不做兜底；失败要暴露原因，不用跳过检查换取通过。
- 游戏根目录为 `longe-journey/`。工程入口见 `longe-journey/docs/DEVELOPMENT.md`。
- 保留现有 Dialogic 与业务 Autoload 分工、GL Compatibility 渲染；不引入模板业务框架。
- 修改业务行为时同步补充 `longe-journey/tests/` 回归测试。
- 提交前运行 Python 工具测试及 `tools/verify.py`；不直接在真实用户数据目录运行存档测试。
- `addons/` 是第三方代码；必要补丁保持最小，并登记 `docs/THIRD_PARTY.md`。
- 不提交 `.godot/`、验证报告、工具下载、密钥和本地配置。不自动提交或推送。
