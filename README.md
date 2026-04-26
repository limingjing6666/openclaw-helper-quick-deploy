# 🚀 OpenClaw Quick Deploy

> 面向 Windows 大学生的 OpenClaw 一键部署工具。
> 不懂编程也能用，10 分钟让你的 AI 机器人在 QQ 上陪你聊天。

## 这是什么？

[OpenClaw](https://openclaw.ai) 是一个强大的 AI 机器人运行框架。你可以把它理解成"AI 机器人的操作系统"——它让一个 AI 模型连接到聊天软件（QQ、Telegram 等），然后和你聊天、帮你做事。

但是，配置它有点麻烦。你需要装环境、配模型、连 QQ 机器人平台……

**这个工具就是来解决这个问题的。** 它像一个安装向导一样，一步步带着你：

1. ✅ 自动安装 Node.js（OpenClaw 运行环境）
2. ✅ 自动安装 OpenClaw
3. ✅ 引导你注册 DeepSeek（AI 大脑，便宜又好用）
4. ✅ 引导你注册 QQ 机器人（让你的 AI 上 QQ）
5. ✅ 调用官方配置向导完成设置
6. ✅ 生成机器人性格模板
7. ✅ 一键启动

## 快速开始

### 系统要求

- Windows 10 或 Windows 11（64 位）
- 网络连接正常
- 一个 QQ 号（用来注册机器人）

### 开始部署

```batch
# 1. 下载项目（绿色按钮 Code → Download ZIP，或直接用 git）
git clone https://github.com/limingjing6666/openclaw-helper-quick-deploy.git
cd openclaw-helper-quick-deploy

# 2. 双击运行
quick-start.bat
```

然后跟着屏幕上的提示一步步走就行了。

## 部署流程

```
① 自动安装 Node.js       → 没装就装，版本低就升级
② 自动安装 OpenClaw      → 国内镜像源，不怕墙
③ 引导注册 DeepSeek      → 获取 AI 大脑的 API Key
④ 引导注册 QQ 机器人      → 获取 AppID 和 ClientSecret
⑤ 运行官方配置向导        → 把刚才的信息填进去
⑥ 生成机器人性格模板      → 编辑 prompts/ 目录的文件
⑦ 启动！                 → 去 QQ 上找机器人聊天吧
```

## 常见问题

> 详细版看 [docs/05-troubleshooting.md](docs/05-troubleshooting.md)

**Q: 一定要用 DeepSeek 吗？可以用别的 AI 吗？**
A: DeepSeek 是最便宜最方便的选择（注册送 500 万 tokens，≈1 元/百万 tokens）。但 OpenClaw 支持很多模型，在配置向导里可以自己选。

**Q: 我没有 QQ 机器人怎么办？**
A: 部署向导会引导你去 QQ 开放平台免费注册一个。整个过程约 5 分钟。

**Q: 我完全不懂编程，能搞定吗？**
A: 这个工具就是为你做的！跟着屏幕提示一步步走就行，完全不需要写代码。

## 下一步

部署完成后，编辑 `prompts/` 目录下的文件，给你的机器人设计性格：

| 文件 | 说明 |
|---|---|
| `prompts/IDENTITY.md` | 机器人是谁、叫什么、性格如何 |
| `prompts/SOUL.md` | 机器人的灵魂设定 |
| `prompts/USER.md` | 你的信息（机器人会记住） |
| `prompts/AGENTS.md` | 高级配置（可选） |

模板里有详细注释和示例，照着改就行。

## License

MIT — 随便用、随便改、欢迎提 PR。
