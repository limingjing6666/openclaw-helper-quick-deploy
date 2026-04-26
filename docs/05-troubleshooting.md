# ❓ 常见问题

## 安装问题

### Node.js 下载失败
- 检查网络连接是否正常
- 可以手动打开 https://nodejs.org/ 下载 LTS 版本
- 下载后双击安装，然后重新运行部署向导

### npm install 安装 OpenClaw 失败
- 部署向导已经帮你切换了国内镜像源（npmmirror）
- 如果仍然失败，可能是网络问题，试试：
  1. 关闭代理软件后重试
  2. 或者开启代理后手动执行：`set HTTPS_PROXY=http://127.0.0.1:你的端口` 再试

### 安装过程中命令提示符乱码
- 部署向导会自动切换到 UTF-8 编码
- 如果仍然乱码，在命令提示符输入 `chcp 65001` 然后回车

## 配置问题

### DeepSeek API Key 从哪里获取？
1. 打开 https://platform.deepseek.com/
2. 注册账号（手机号即可）
3. 登录后左侧菜单「API Keys」→「创建 API Key」
4. 复制生成的 sk- 开头的密钥

### QQ 机器人 AppID 和 ClientSecret 在哪里？
1. 打开 https://q.qq.com/
2. 登录后进入机器人管理页面
3. 左侧「开发配置」可以看到

### 官方配置向导不会用
跟着屏幕提示走就行：
- 模型选择：选 DeepSeek
- API Key：粘贴刚才复制的 Key
- 通道选择：选 QQBot
- 其他选项：直接回车使用默认值

## 启动问题

### openclaw gateway start 启动失败
可能原因：
1. **端口被占用**：OpenClaw 默认使用 3000 端口，检查是否有其他程序占用
2. **配置错误**：重新运行 `openclaw setup` 检查配置
3. **权限不足**：以管理员身份运行命令提示符

### 启动成功后 QQ 机器人没反应
1. 检查你的 QQ 号是否在机器人的沙箱用户列表里
2. 确认 AppID 和 ClientSecret 配置正确
3. 给机器人发消息后，看命令提示符窗口有没有日志输出

## 使用问题

### 怎么修改机器人的性格？
编辑项目目录下的 `prompts/` 文件：
- `IDENTITY.md`：机器人的身份和性格
- `SOUL.md`：更深层的行为准则
- `USER.md`：你的个人信息
- `AGENTS.md`：高级规则

修改完后保存，重启 OpenClaw 即可生效。

### 机器人回复太慢了
可能是 DeepSeek API 的响应时间。在非高峰时段使用会快一些。

### 想用其他 AI 模型怎么办？
在 `openclaw setup` 时可以手动选择其他模型提供方。

### 这个工具会收费吗？
免费开源，MIT 协议，随便用。你只需要自己承担 DeepSeek API 的使用费（非常便宜）。

## 其他问题

### 如何更新 OpenClaw？
```batch
npm update -g openclaw
```

### 如何卸载 OpenClaw？
```batch
npm uninstall -g openclaw
```

### 想一键部署到服务器（Linux）？
目前只支持 Windows 一键部署。Linux 用户可以手动安装。

### 遇到这里没写的问题？
可以：[提交 Issue](https://github.com/limingjing6666/openclaw-helper-quick-deploy/issues) 或联系作者。
