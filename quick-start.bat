@echo off
chcp 65001 >nul
color 0B
title OpenClaw 快速部署向导

:: ================================================
::   >> OpenClaw 快速部署向导 v1.0
::   面向 Windows 大学生的一键部署工具
::   纯开源 | MIT License
:: ================================================

setlocal enabledelayedexpansion

set NODE_URL=https://nodejs.org/dist/v22.13.0/node-v22.13.0-x64.msi

cls
echo.
echo ╔═══════════════════════════════════════════╗
echo ║        >> OpenClaw 快速部署向导          ║
echo ║     让不懂技术的小白也能跑起 AI 机器人   ║
echo ╚═══════════════════════════════════════════╝
echo.
echo 本向导将一步步帮你完成：
echo.
echo  ① 检查/安装 Node.js
echo  ② 安装 OpenClaw（AI 机器人运行环境）
echo  ③ 配置 DeepSeek API Key（AI 大脑）
echo  ④ 配置 QQ 机器人（让你在 QQ 上聊天）
echo  ⑤ 运行官方配置向导
echo  ⑥ 启动你的 AI 机器人
echo.
echo 按任意键开始部署，按 Ctrl+C 退出...
pause >nul

:: ================================================
::   第一步：检查 / 安装 Node.js
:: ================================================
:step1
cls
echo.
echo ═══════════════════════════════════════════
echo   第一步：检查 Node.js
echo ═══════════════════════════════════════════
echo.

where node >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [*] 你的电脑上还没有 Node.js，正在自动下载安装...
    echo.
    curl -# -o "%TEMP%\node-install.msi" "%NODE_URL%"
    if %ERRORLEVEL% neq 0 (
        echo.
        echo [X] 下载失败！可能是网络问题。
        echo.
        echo 解决办法：手动打开 https://nodejs.org/
        echo 点击左侧 LTS 版本下载安装，然后重新运行本脚本。
        echo.
        pause
        exit /b
    )
    echo.
    echo [OK] 下载完成，正在自动安装...
    start /wait msiexec /i "%TEMP%\node-install.msi" /qn
    echo [OK] 安装完成！
    echo.
    echo [!]  请关闭当前窗口，重新打开命令提示符后再次运行本脚本。
    pause
    exit /b
)

for /f "tokens=*" %%i in ('node --version') do set NODE_VER=%%i
set NODE_VER_NUM=%NODE_VER:~1%

echo [OK] Node.js 已安装！版本：%NODE_VER%

for /f "tokens=1 delims=." %%a in ("%NODE_VER_NUM%") do (
    if %%a LSS 22 (
        echo [!]  当前版本过低（需要 v22 以上）。
        echo [*] 正在自动卸载旧版并安装新版...
        echo.
        wmic product where "name like '%%Node.js%%'" call uninstall /nointeractive >nul 2>nul
        echo [OK] 旧版已卸载。
        echo [*] 正在下载 Node.js v22.13.0...
        curl -# -o "%TEMP%\node-install.msi" "%NODE_URL%"
        if %ERRORLEVEL% neq 0 (
            echo [X] 下载失败！请手动安装：
            echo   打开 https://nodejs.org/ 下载 LTS 版
            pause
            exit /b
        )
        echo [OK] 下载完成，正在安装...
        start /wait msiexec /i "%TEMP%\node-install.msi" /qn
        echo [OK] 安装完成！
        echo.
        echo [!]  请关闭当前窗口，重新打开命令提示符后再次运行本脚本。
        pause
        exit /b
    )
)

echo.
echo [OK] 第一步完成！按任意键进入下一步...
pause >nul

:: ================================================
::   第二步：安装 / 更新 OpenClaw
:: ================================================
:step2
cls
echo.
echo ═══════════════════════════════════════════
echo   第二步：安装 OpenClaw
echo ═══════════════════════════════════════════
echo.
echo OpenClaw 是 AI 机器人运行的核心程序。
echo.
echo [*] 正在切换国内镜像源（npmmirror），防止网络问题...
npm config set registry https://registry.npmmirror.com
echo [OK] 已切换完成
echo.

where openclaw >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [*] 正在安装 OpenClaw（约 1-2 分钟）...
    echo.
    call npm install -g openclaw
    if %ERRORLEVEL% neq 0 (
        echo.
        echo [X] 安装失败！常见原因：
        echo.
        echo  ① 网络问题
        echo     如果你在用代理，试试在命令提示符输入：
        echo       set HTTPS_PROXY=http://127.0.0.1:你的代理端口
        echo       npm install -g openclaw
        echo.
        echo  ② 镜像源不可用
        echo     可以换回官方源后重试：
        echo       npm config set registry https://registry.npmjs.org
        echo       npm install -g openclaw
        echo.
        echo  ③ 磁盘空间不足
        echo.
        pause
        goto step2
    )
    echo [OK] OpenClaw 安装成功！
) else (
    for /f "tokens=*" %%i in ('openclaw --version 2^>nul') do set OCV=%%i
    echo [OK] OpenClaw 已安装！版本：%OCV%
    echo.
    echo 是否检查更新到最新版？（推荐）
    set /p UP=更新到最新版？(Y/N): 
    if /i "!UP!"=="Y" (
        echo [*] 正在更新...
        call npm update -g openclaw
        if %ERRORLEVEL% neq 0 (
            echo [X] 更新失败，请稍后手动尝试：npm update -g openclaw
            pause
            goto step3
        )
        echo [OK] 更新完成！
    )
)

echo.
echo [OK] 第二步完成！按任意键进入下一步...
pause >nul

:: ================================================
::   第三步：配置 DeepSeek API Key
:: ================================================
:step3
cls
echo.
echo ═══════════════════════════════════════════
echo   第三步：配置 AI 大脑（DeepSeek API Key）
echo ═══════════════════════════════════════════
echo.
echo DeepSeek 是 AI 机器人的"大脑"，让机器人能理解你说的话。
echo 注册即送 500 万 tokens，正常聊天可以用很久很久～
echo.
echo 获取方法（超级简单，2 分钟搞定）：
echo.
echo  ① 打开浏览器访问 https://platform.deepseek.com/
echo  ② 点击右上角「登录/注册」
echo     - 手机号就能注册，也可以用邮箱
echo  ③ 登录后点击左侧菜单「API Keys」
echo  ④ 点击「创建 API Key」
echo  ⑤ 复制那一串以 sk- 开头的密钥
echo.
echo [!]  密钥长这样：sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
echo.
echo 准备好了吗？拿到 Key 后粘贴到下面。
echo.

:ask_ds_key
set /p DS_KEY=请输入你的 DeepSeek API Key（粘贴后按回车）: 

if "%DS_KEY%"=="" (
    echo [X] Key 不能为空！请重新输入
    pause
    goto ask_ds_key
)

echo.
echo [OK] DeepSeek API Key 已记录！稍后会在配置向导中使用。
echo.
echo [OK] 第三步完成！按任意键进入下一步...
pause >nul

:: ================================================
::   第四步：配置 QQ 机器人
:: ================================================
:step4
cls
echo.
echo ═══════════════════════════════════════════
echo   第四步：配置 QQ 机器人
echo ═══════════════════════════════════════════
echo.
echo 想让你的 AI 机器人上 QQ 和你聊天吗？
echo.
echo 如果暂时不想弄，也可以跳过，以后再来配置。
echo.
echo [Y] 现在配置 QQ 机器人（推荐）
echo [S] 跳过，以后再说
echo.
set /p QQ_CHOICE=请选择 (Y/S): 

if /i "!QQ_CHOICE!"=="S" (
    echo.
    echo 好的～以后想配置了看 docs/03-qqbot.md 就行
    goto step5
)

echo.
echo 配置 QQ 机器人需要两个东西：
echo.
echo   ① AppID（应用 ID）—— 一串数字
echo   ② ClientSecret（客户端密钥）—— 一串字母数字
echo.
echo 获取方法（约 5 分钟）：
echo.
echo  ① 打开浏览器访问 https://q.qq.com/
echo  ② 点击右上角「登录」
echo     - 用你的 QQ 号扫码登录
echo  ③ 登录后点击「创建机器人」→「机器人」
echo  ④ 填一个名字和简介（随便写就行）
echo  ⑤ 创建成功后，在「开发配置」页面找到：
echo     - AppID（一串数字，比如 1234567890）
echo     - ClientSecret（一串字母数字）
echo.
echo 准备好了吗？按任意键开始输入...
pause >nul

:ask_appid
echo.
set /p APPID=请输入你的 AppID（一串数字）: 
if "%APPID%"=="" (
    echo [X] 不能为空！
    goto ask_appid
)

:ask_secret
set /p SECRET=请输入你的 ClientSecret（一串字母数字）: 
if "%SECRET%"=="" (
    echo [X] 不能为空！
    goto ask_secret
)

echo.
echo [OK] QQ 机器人信息已记录！稍后会在配置向导中使用。
echo.
echo [OK] 第四步完成！按任意键进入下一步...
pause >nul

:: ================================================
::   第五步：运行官方配置向导 + 启动
:: ================================================
:step5
cls
echo.
echo ═══════════════════════════════════════════
echo   第五步：运行官方配置向导
echo ═══════════════════════════════════════════
echo.
echo 接下来会启动 OpenClaw 的官方配置向导。
echo.
echo 请根据屏幕提示输入以下信息：
echo.
echo   - 选择模型时选 DeepSeek
if not "%DS_KEY%"=="" (
    echo   - API Key 粘贴你刚才复制的：
    echo     %DS_KEY:~0,20%......
)
if not "%APPID%"=="" (
    echo   - QQ 机器人 AppID 粘贴：%APPID%
    echo   - QQ 机器人 ClientSecret 粘贴：%SECRET:~0,10%......
)
echo.
echo 其他选项可以一路回车用默认值。
echo.
echo 按任意键启动配置向导...
pause >nul

echo.
openclaw setup

echo.
echo [OK] 配置完成！
echo.
echo [*] 正在生成机器人性格模板...
mkdir prompts 2>nul

:: 写出 IDENTITY.md.example
(
echo # IDENTITY.md —— 机器人身份
echo.
echo 在这里写下你的 AI 机器人是谁。
echo 它是男生还是女生？叫什么名字？什么性格？
echo.
echo --- 示例 ---
echo.
echo 名字：小助手
echo 性别：女性
echo 年龄：22 岁
echo 性格：温柔、耐心、乐于助人
echo 说话风格：自然亲切，像朋友一样
echo.
echo --- 修改下面这行开始 ---
echo.
echo 我是[你的机器人名字]，一个[性格描述]的 AI 助手。
) > prompts\IDENTITY.md.example

:: 写出 SOUL.md.example
(
echo # SOUL.md —— 机器人的灵魂
echo.
echo 更深层的设定，决定机器人如何思考和行为。
echo.
echo --- 示例 ---
echo.
echo 我存在的意义是帮助用户解决问题。
echo 我是一个友好、专业的 AI 助手。
echo 我喜欢用清晰易懂的方式解释复杂概念。
echo 当我不确定时，我会诚实地说不知道。
echo.
echo --- 修改下面 ---
echo.
echo 我的使命是：
echo 我的原则是：
) > prompts\SOUL.md.example

:: 写出 USER.md.example
(
echo # USER.md —— 你的信息
echo.
echo 告诉机器人关于你的事情，这样它能更好地了解你。
echo.
echo --- 示例 ---
echo.
echo 名字：张三
echo 身份：大学生，软件工程专业
echo 兴趣：编程、游戏、音乐
echo.
echo --- 修改下面 ---
echo.
echo 名字：
echo 身份：
echo 兴趣：
) > prompts\USER.md.example

:: 写出 AGENTS.md.example
(
echo # AGENTS.md —— 高级配置
echo.
echo 如果你想让机器人有特定的行为规则，可以写在这里。
echo 如果不确定，留空即可。
echo.
echo 示例规则：
echo - 每天早上 8 点主动说早安
echo - 用户提到"帮助"时要详细解答
echo - 不要主动询问用户的隐私信息
echo.
echo --- 你的规则 ---
) > prompts\AGENTS.md.example

echo [OK] 模板已生成！编辑 prompts/ 目录的文件可定制机器人性格。
echo.
echo [*] 正在启动 OpenClaw...
echo.
openclaw gateway start

echo.
echo ╔═══════════════════════════════════════════╗
echo ║        !! 恭喜！部署完成！               ║
echo ║                                           ║
echo ║  你的 AI 机器人已经启动！                 ║
echo ║  去 QQ 上给你的机器人发消息试试吧！       ║
echo ║                                           ║
echo ║  下一步：                                 ║
echo ║   - 编辑 prompts/ 里的文件               ║
echo ║     可以定制机器人的性格和说话方式       ║
echo ║                                           ║
echo ║  [?] 遇到问题？看 docs/05-troubleshooting.md ║
echo ╚═══════════════════════════════════════════╝
echo.
pause
