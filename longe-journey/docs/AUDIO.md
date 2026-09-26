# 音效绑定

选择来源：`D:/Downloads/音效选择清单 (1).json`。40 个选中资源已导入；在原录音外制作 6 个短片段，裁剪时间、作者、许可和来源见 `audio/sfx_catalog.json`，署名汇总见 `audio/CREDITS.md`。

## 播放约定

- `ambience`：环境循环，走 SFX 总线；切换场景时淡入或停止。
- `action`：剧情动作，明确不循环；对应文本推进完毕后停止，场景入口清理两个频道。
- UI 点击与打字音走 UI 总线；BGM、SFX、UI 音量沿用设置面板独立滑块。
- 动作素材中的多次录音不全部播放：桶落地、木质撞击、拿手机、藤篮、女声耳语已制作短片段；荧光灯保留连续嗡声段。
- 耳语短片段长 0.90 秒，仅作贴耳声提示，不是中文台词配音；原录音仍保留。

## 使用位置

| 音效类别 | 时间线 / 界面 |
| --- | --- |
| 01_UI点击 | 业务按钮、Dialogic 选项 |
| 02_打字推进 | 剧情文本框 |
| 03_走路 | `05_shiling`、`07_maze_entry`、`07_maze_right` |
| 04_奔跑喘气 | `06_luyuan`、`07_maze_middle` |
| 05_楼梯石廊脚步 | `06_luyuan`、`07_maze_middle`、`08_wife_room`、`09_ending` |
| 08_厚门猛关 | `07_maze_entry`、`09_ending` |
| 09_公交环境 | `00_start` |
| 11_植物花茎折断 | `05_shiling`、`06_luyuan`、`07_maze_middle` |
| 12_火焰喷火 | `05_shiling` |
| 14_风声 | `01_hospital`、`03_crossroads`、`04_flower_shop`、`05_shiling`、`07_maze_entry`、`07_maze_exit`、`07_maze_middle`、`09_ending` |
| 19_哭声呜咽 | `10_morgue` |
| 20_医院病房停尸房底噪 | `02_ward`、`08_wife_room`、`09_ending`、`10_morgue` |
| 21_园林森林虫鸣 | `06_luyuan`、`07_maze_right` |
| 24_硬币车费 | `03_crossroads`、`05_shiling` |
| 25_bus_arrival | `00_start`、`03_crossroads` |
| 26_hospital_door | `02_ward` |
| 27_curtain | `08_wife_room` |
| 28_bucket_spill | `04_flower_shop` |
| 29_road_steps | `03_crossroads`、`07_maze_exit` |
| 30_fire_loop | `05_shiling` |
| 31_banquet | `07_maze_entry`、`07_maze_left` |
| 32_female_humming | `07_maze_middle` |
| 34_body_scuffle | `07_maze_middle` |
| 35_muffled_voices | `07_maze_right` |
| 36_light_buzz | `09_ending` |
| 37_phone_handling | `01_hospital` |
| 38_soil_rummage | `04_flower_shop` |
| 39_basket_handling | `10_morgue` |
| 40_female_whisper | `08_wife_room` |

## 备用资源

以下资源已导入，当前没有适合的现场动作或已经由更匹配的选项替代：

06_门锁铁门、07_帘子卷帘门、10_公交到站离站、13_仪式庙宇、15_雨声、16_水滴滴水、17_水流气泡、18_低语恐怖、22_人群宴席远声、23_手机提示音、33_wood_impact。

木棒“被敲进地里”描述既成状态，不新增现场敲击。当前故事没有下雨、滴水或流水场景，不添加无依据的触发。

## 重新导入

在仓库根目录执行；第二步必须在重新导入后执行，以恢复游戏使用的派生片段记录：

```powershell
python long-journey/tools/import_selected_sfx.py 'D:/Downloads/音效选择清单 (1).json' --project-root long-journey
python long-journey/tools/prepare_sfx_clips.py --ffmpeg .local-tools/audio-python/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe
```

裁剪工具需要 FFmpeg，可用 `--ffmpeg` 指定实际路径。裁剪配方绑定本次选中的 track_id；换选其他录音必须重新检查剪辑点，工具不会套用其他候选。WAV 导入规范为 PCM16，MP3 原录音保持不变。

回归覆盖：`tests/audio_binding_test.gd`、`tests/ui_audio_test.gd`、`tools/tests/test_import_selected_sfx.py`、`tools/tests/test_prepare_sfx_clips.py`。完整验证通过 `tools/verify.py` 在独立项目副本和用户目录运行。
