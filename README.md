# 大模型切换 · ai-switch

飞牛 fnOS 应用：**Web 面板一键切换远程 GPU 主机上的 AI 服务模式**。

适用于"一台 GPU 主机上跑了多个互斥的 AI 服务（LLM 对话 / 视频生成 / vLLM 推理）"的场景——显存是排他资源，同一时间只能跑一种服务，本应用把 SSH 敲命令的流程做成了 NAS 桌面应用。

## 功能

- **四种模式一键切换**：LLM 对话（NInfer :8080）/ 视频生成（ComfyUI :8188）/ vLLM（:8000）/ 全部关停
- **实时状态**：主机在/离线、当前模式、双 GPU 显存与利用率、各 systemd 服务状态、HTTP 端点探活（15 秒轮询）
- **WOL 唤醒**：主机休眠时一键发魔法包
- **自动休眠联动**：切换到工作模式时自动停用 auto-power 休眠计时器，`off` 后恢复
- **操作日志**：每次切换 / 唤醒留痕

## 架构

```
飞牛 NAS (应用容器, 端口 8479)
├── Web UI (单文件 HTML)
└── ai-switchd (Python 纯标准库)
    ├── HTTP API + 15s 轮询
    ├── SSH/sshpass ──→ 远程 GPU 主机
    │                    └── ai-mode.sh (模式切换 + JSON 状态)
    └── WOL 魔法包 ──→ (休眠时唤醒)
```

## 安装

1. 飞牛应用中心 → 手动安装 → 选 [ai-switch.fpk](./ai-switch.fpk)
2. 安装向导填写远程主机 SSH 信息（IP / 用户名 / 密码）与 WOL MAC 地址
3. 桌面打开「大模型切换」

> 远程主机需要先部署 `ai-mode.sh`（见 [ai-mode-v3.sh](./ai-mode-v3.sh)）并配置 `/etc/sudoers.d/ai-mode` 免密 sudo，方法见 [开发记录](./docs/开发记录.md)。

## 使用

- 点击模式卡片即切换；LLM↔视频来回切约 40 秒内完成服务交接（取决于模型加载速度）
- 主机休眠时面板显示离线，点「WOL 唤醒主机」
- 想改成管理自己的服务：编辑 `ai-mode.sh` 里的服务名和 `ai-switchd` 里的 MODES 描述

## 开发记录

完整的踩坑过程（sudoers 多参数不匹配、休眠计时器背刺、pkill 自杀等 7 个坑）见 [docs/开发记录.md](./docs/开发记录.md)。

## 相关项目

- [auto-power-fnos](https://github.com/guoxizheng/auto-power-fnos) — 远程电源管理飞牛应用（休眠/WOL，本应用的好搭档）
- [model-convert-fnos](https://github.com/guoxizheng/model-convert-fnos) — 模型转换飞牛应用（fp8/bf16→fp16，切到视频模式前先转权重）

## License

MIT
