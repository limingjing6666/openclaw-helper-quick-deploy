# 故障排查

## Node.js 安装失败

**现象**：Node.js 下载失败或安装过程报错。

**解决**：
1. 手动打开 https://nodejs.org/ 下载 LTS 版本（v22.16+）
2. 安装完成后重新运行 `quick-start.bat`

**检查安装**：
```cmd
node --version
npm --version
```

---

## npm 源失败

**现象**：安装 OpenClaw 时卡住或报网络错误。

**原因**：默认镜像源不可用。

**解决**：
本脚本已配置镜像回退机制（npmmirror → npmjs），如果仍然失败：
```cmd
npm install -g openclaw --registry=https://registry.npmjs.org
```

---

## OpenClaw 安装失败

**现象**：`npm install -g openclaw` 报错。

**常见原因**：
- 网络问题（检查代理设置）
- 磁盘空间不足
- 全局安装权限不足（尝试以管理员身份运行）

**手动安装**：
```cmd
npm install -g openclaw
```

---

## 配置向导失败

**现象**：`openclaw setup` 或 `openclaw onboard` 报错。

**解决**：
1. 确保已准备好 DeepSeek API Key
2. 手动运行配置向导：
```cmd
openclaw setup
```

---

## Gateway 端口被占用

**现象**：提示端口冲突，或 Gateway 无法启动。

**自动处理**：本脚本会自动从预设端口（默认 18789）开始扫描空闲端口，无需手动干预。

**手动查看最终端口**：
```cmd
openclaw config get gateway.port
```

**如果服务未启动**：
```cmd
openclaw gateway install --force
openclaw gateway start
```

---

## Gateway 启动失败

**现象**：Gateway 无法启动或状态异常。

**诊断命令**：
```cmd
openclaw config file            # 查看配置文件路径
openclaw gateway status         # 查看服务状态
openclaw doctor                 # 运行诊断
openclaw config validate        # 验证配置
```

---

## 模板文件未生效

**现象**：修改了工作区中的 IDENTITY.md 但机器人没变化。

**检查路径**：
```cmd
openclaw config get agents.defaults.workspace
```

模板文件应放在上述路径下。只有在文件不存在时脚本才会创建，不会覆盖已有内容。

---

## 机器人没反应

**检查步骤**：
1. Gateway 是否在运行：`openclaw gateway status --require-rpc`
2. 机器人配置是否正确：`openclaw config validate`
3. QQ 机器人已添加到频道/群聊
4. 查看日志：
```cmd
openclaw gateway --logs
```

---

## 如何完全卸载重装

```cmd
# 卸载 OpenClaw
npm uninstall -g openclaw

# 卸载 Node.js
# 控制面板 → 程序和功能 → Node.js → 卸载
```
