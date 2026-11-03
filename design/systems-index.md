# Systems index

One row per system. Add the row in the same pull request that adds the design doc. The vision lives in [vision.md](vision.md); every row should serve one of its pillars.

| System | Owner | Status | Doc | Summary | Depends on |
|---|---|---|---|---|---|
| Overview | creative-director | in review | design/overview.md | 游戏定位、四根支柱、文档地图与商用标准 | vision.md, all system pages |
| Core rules | game-designer | in review | design/core-rules.md | 网格、推动、死锁警告、胜利、计数、撤销与重开契约 | design/level-format.md, design/input-and-controls.md |
| Input and controls | game-designer | in review | design/input-and-controls.md | 键鼠与手柄动作表、输入上下文、重映射与冲突规则 | design/core-rules.md, design/settings-and-save.md |
| Level format | tech-director | in review | design/level-format.md | assets/data/levels/ 的 JSON 格式、图例、校验与新增关卡流程 | design/core-rules.md, design/technical-architecture.md |
| Level progression | game-designer | in review | design/level-progression.md | 20 关战役、难度带、par 值、星级与解锁 | design/core-rules.md, design/level-format.md, design/ui-flow.md |
| Camera and presentation | technical-artist | in review | design/camera-and-presentation.md | 等距相机、遮挡淡出、程序化材质、光照与补间节奏 | design/core-rules.md, design/level-format.md, design/accessibility.md |
| UI flow | game-designer | in review | design/ui-flow.md | 全部界面与导航、HUD、暂停与胜利、危险操作确认、本地化键 | design/core-rules.md, design/input-and-controls.md, design/settings-and-save.md, design/accessibility.md |
| Settings and save | tech-director | in review | design/settings-and-save.md | 设置项、存档结构、版本迁移与损坏恢复 | design/input-and-controls.md, design/ui-flow.md, design/audio.md, design/technical-architecture.md |
| Audio | technical-artist | in review | design/audio.md | 程序生成音效清单、生成方式、混音与许可 | design/ui-flow.md, design/settings-and-save.md, design/accessibility.md |
| Accessibility | game-designer | in review | design/accessibility.md | 形状与颜色独立、字号与 UI 缩放、键盘导航、减少动态效果 | design/ui-flow.md, design/camera-and-presentation.md, design/audio.md, design/settings-and-save.md |
| Technical architecture | tech-director | in review | design/technical-architecture.md | 逻辑与渲染分层、autoload 职责、场景划分、信号契约与性能预算 | design/level-format.md, design/settings-and-save.md, design/core-rules.md |
| Release | release-manager | in review | design/release.md | 版本与平台、许可与致谢、崩溃处理、发布门槛 | design/technical-architecture.md, design/settings-and-save.md, design/accessibility.md, design/audio.md |

Status values:

- draft: being written, not yet a commitment.
- in review: waiting on a human decision. Every row above carries at least one open question in its page.
- approved: implementable, and stories may cite it.
- shipped: implemented and covered by evidence.
- outdated: kept for history, do not implement from it.

Rules:

- Every design doc under design/ has exactly one row here. `design/_template.md` is a template, not a system, and has no row.
- The Doc cell uses forward slashes and starts with design/.
- Doc paths are relative links to real pages and must resolve from this file.
- Summary is one line, in the page's language, and says what the system owns rather than restating its title.
- Depends on lists the pages whose numbers or contracts this page cites; a dependency must also be a row in this table.
- Owner is a role from .dsh/agents/, not a person's name.
- Moving a row to shipped requires an evidence index under production/qa/evidence/ that reports Run result: OBSERVED.
- A page's open questions are tracked there, not here; this table does not carry decisions.
