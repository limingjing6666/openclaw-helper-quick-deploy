# OpenClaw 快速部署向导

> Windows 中文新手安装器 —— 让不懂技术的小白也能跑起 AI 机器人

## 这是什么？

这是一个面向 **Windows 10/11 x64 中文用户** 的 OpenClaw 一键安装工具。

你只需要**双击 `quick-start.bat`**，脚本会自动完成：

1. 环境检测（操作系统、PowerShell、网络）
2. 检查/安装 Node.js（最低 v22.16.0）
3. 安装 OpenClaw（已测试固定版本）
4. 调用 OpenClaw 官方配置向导
5. 同步机器人模板（IDENTITY.md、SOUL.md 等）到工作区
6. 自动处理 Gateway 端口冲突
7. 启动 AI 机器人

## 系统要求

- Windows 10 或 Windows 11（64 位）
- PowerShell 5.1+
- 网络连接（下载 Node.js 和 npm 包）

## 使用方法

```cmd
# 双击运行
quick-start.bat
```

或者以管理员身份运行（推荐，避免权限问题）。

## 你需要提前准备

OpenClaw 官方向导会要求你提供以下信息：

- **DeepSeek API Key** — 在 https://platform.deepseek.com/ 注册获取
- **QQ Bot AppID 和 ClientSecret** — 在 https://q.qq.com/ 创建机器人获取

## 目录结构

```
├── quick-start.bat          # 双击入口（仅启动 PowerShell）
├── scripts/
│   ├── quick-start.ps1      # 主安装器脚本
│   └── config.psd1          # 版本和策略配置
├── templates/
│   ├── IDENTITY.md           # 机器人身份模板
│   ├── SOUL.md               # 机器人灵魂模板
│   ├── USER.md               # 用户信息模板
│   └── AGENTS.md             # 高级配置模板
├── docs/
│   └── 05-troubleshooting.md # 故障排查
└── README.md
```

## 关于版本策略

本工具默认安装 **已验证的固定版本**，而不是 `latest`，以保证稳定性。

版本配置在 `scripts/config.psd1` 中维护。升级 OpenClaw 时，请先全流程测试通过后再更新配置。

## 故障排查

见 [docs/05-troubleshooting.md](docs/05-troubleshooting.md)。

## License

纯开源 — MIT License
