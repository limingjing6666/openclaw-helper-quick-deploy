<#
.SYNOPSIS
    OpenClaw 快速部署向导 — Windows 中文新手安装器
.DESCRIPTION
    自动安装 Node.js、OpenClaw，调用官方向导配置，处理端口冲突，
    同步模板文件到工作区，启动 Gateway 服务。
.NOTES
    Version  : 2.0
    Author   : limingjing6666
    Requires : Windows 10/11 x64, PowerShell 5.1+
#>

#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================
# 加载配置
# ============================================
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptRoot
$ConfigPath = Join-Path $ScriptRoot 'config.psd1'
$Config     = Import-LocalizedData -BaseDirectory $ScriptRoot -FileName 'config.psd1'

# ============================================
# 日志函数
# ============================================
$Host.UI.RawUI.ForegroundColor = $null  # reset

function Write-Info   { Write-Host "   $($args[0])" -ForegroundColor Cyan }
function Write-Ok     { Write-Host " [OK] $($args[0])" -ForegroundColor Green }
function Write-Warn   { Write-Host " [!]  $($args[0])" -ForegroundColor Yellow }
function Write-Err    { Write-Host " [X]  $($args[0])" -ForegroundColor Red }
function Write-Step   { Write-Host "`n==========================================" -ForegroundColor DarkGray; Write-Host " $($args[0])" -ForegroundColor White; Write-Host "==========================================" -ForegroundColor DarkGray }

function Exit-WithError {
    param([string]$Step, [string]$Hint)
    Write-Err "步骤「$Step」失败！"
    if ($Hint) { Write-Warn "建议：$Hint" }
    Write-Info "`n--- 故障排查信息 ---"
    Write-Info "OpenClaw 配置文件路径：$(openclaw config file 2>$null | Out-String)"
    Write-Info "OpenClaw 工作区路径：$(openclaw config get agents.defaults.workspace 2>$null | Out-String)"
    try { openclaw doctor 2>$null } catch {}
    Write-Info "`n你也可以手动运行以下命令检查状态："
    Write-Info "  openclaw config file"
    Write-Info "  openclaw gateway status"
    Write-Info "  openclaw doctor"
    Write-Info "  openclaw config validate"
    exit 1
}

# ============================================
# 工具函数
# ============================================
function Test-Command {
    param([string]$Command)
    if (Get-Command $Command -ErrorAction SilentlyContinue) { return $true }
    return $false
}

function Get-VersionObject {
    param([string]$VersionString)
    try { return [Version]($VersionString.TrimStart('v').TrimStart('V')) } catch { return $null }
}

function Invoke-NpmWithFallback {
    param([string[]]$Arguments)
    $npm = (Get-Command npm).Source
    foreach ($reg in $Config.NpmRegistries) {
        Write-Info "尝试镜像源：$reg"
        $argsWithReg = $Arguments + @('--registry', $reg)
        $proc = Start-Process -FilePath $npm -ArgumentList $argsWithReg -Wait -NoNewWindow -PassThru
        if ($proc.ExitCode -eq 0) { return $true }
        Write-Warn "镜像源 $reg 失败，尝试下一个..."
    }
    return $false
}

# ============================================
# 1. 环境预检
# ============================================
function Invoke-PrerequisitesCheck {
    Write-Step "环境预检"

    # 操作系统
    if ($env:OS -ne 'Windows_NT') { Exit-WithError -Step '环境预检' -Hint '本工具仅支持 Windows 10/11 x64。' }
    if ([Environment]::Is64BitProcess -eq $false) { Exit-WithError -Step '环境预检' -Hint '本工具仅支持 64 位 Windows。' }
    Write-Ok "操作系统：Windows 10/11 x64"

    # PowerShell 版本
    if ($PSVersionTable.PSVersion.Major -lt 5 -or ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -lt 1)) {
        Exit-WithError -Step '环境预检' -Hint "PowerShell 版本过低（$($PSVersionTable.PSVersion)），需要 5.1+。请升级 Windows Management Framework。"
    }
    Write-Ok "PowerShell 版本：$($PSVersionTable.PSVersion)"

    # 临时目录
    if (-not (Test-Path $env:TEMP)) { Exit-WithError -Step '环境预检' -Hint "临时目录 $env:TEMP 不可用。" }
    Write-Ok "临时目录可用：$env:TEMP"

    # 用户目录
    $userDir = [Environment]::GetFolderPath('UserProfile')
    if (-not (Test-Path $userDir)) { Exit-WithError -Step '环境预检' -Hint "用户目录 $userDir 不可用。" }
    Write-Ok "用户目录可用：$userDir"

    # 网络 — 测试 Node 下载和 npm 源
    $reachable = $false
    foreach ($reg in $Config.NpmRegistries) {
        try {
            $req = [System.Net.WebRequest]::CreateHttp($reg)
            $req.Timeout = 5000
            $req.Method = 'HEAD'
            $resp = $req.GetResponse()
            $resp.Close()
            $reachable = $true
            Write-Ok "网络可达：$reg"
            break
        } catch {
            Write-Warn "网络不可达：$reg"
        }
    }
    if (-not $reachable) { Exit-WithError -Step '环境预检' -Hint '无法访问任何 npm 镜像源，请检查网络连接。' }
}

# ============================================
# 2. Node.js 检查与安装
# ============================================
function Ensure-Node {
    Write-Step "检查 Node.js"

    $nodeInstalled = $false
    $nodeVersion = $null

    if (Test-Command node) {
        $rawVersion = & node --version 2>$null
        $nodeVersion = Get-VersionObject $rawVersion
        if ($nodeVersion) {
            Write-Ok "Node.js 已安装，版本：$nodeVersion"
            if ($nodeVersion -ge $Config.MinimumNodeVersion) {
                $nodeInstalled = $true
            } else {
                Write-Warn "版本过低（$nodeVersion），需要 $($Config.MinimumNodeVersion)，即将升级..."
            }
        }
    }

    if (-not $nodeInstalled) {
        Write-Info "正在下载 Node.js $($Config.PreferredNodeVersion)..."
        $retry = 0
        $downloaded = $false
        while ($retry -lt $Config.DownloadRetryCount -and -not $downloaded) {
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($Config.NodeMsiUrl, $Config.NodeInstallerPath)
                $downloaded = $true
                Write-Ok "下载完成"
            } catch {
                $retry++
                if ($retry -ge $Config.DownloadRetryCount) {
                    Exit-WithError -Step '安装 Node.js' -Hint "下载失败，请手动打开 $($Config.NodeMsiUrl) 下载安装，再重新运行本脚本。"
                }
                Write-Warn "下载失败，重试 $retry/$($Config.DownloadRetryCount)..."
                Start-Sleep -Seconds 2
            }
        }

        Write-Info "正在安装 Node.js（静默安装）..."
        $proc = Start-Process -FilePath msiexec.exe -ArgumentList "/i `"$($Config.NodeInstallerPath)`" /qn /norestart" -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
            Exit-WithError -Step '安装 Node.js' -Hint "安装程序退出码 $($proc.ExitCode)。可尝试手动打开 $($Config.NodeMsiUrl) 安装。"
        }

        # 刷新 PATH
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

        # 验证
        $retry = 0
        $verified = $false
        while ($retry -lt 3 -and -not $verified) {
            try {
                $rawVersion = & node --version 2>$null
                $newVer = Get-VersionObject $rawVersion
                if ($newVer -and $newVer -ge $Config.MinimumNodeVersion) {
                    $verified = $true
                    Write-Ok "Node.js 安装成功，版本：$newVer"
                }
            } catch {}
            if (-not $verified) {
                $retry++
                Start-Sleep -Seconds 2
            }
        }

        if (-not $verified) {
            Write-Warn "Node.js 安装后检测不到。新环境变量可能需要重启终端。"
            Write-Warn "请关闭当前窗口，重新以管理员身份运行本脚本。"
            pause
            exit 1
        }
    }

    # 确保 npm 可用
    if (-not (Test-Command npm)) {
        Exit-WithError -Step '检查 npm' -Hint 'Node.js 安装失败，npm 不可用。请手动安装 Node.js 后重试。'
    }
    Write-Ok "npm 可用"
}

# ============================================
# 3. OpenClaw 检查与安装
# ============================================
function Ensure-OpenClaw {
    Write-Step "安装 / 更新 OpenClaw"

    $ocInstalled = Test-Command openclaw

    if (-not $ocInstalled) {
        Write-Info "正在安装 $($Config.OpenClawPackageVersion)..."
        $ok = Invoke-NpmWithFallback -Arguments @('install', '-g', $Config.OpenClawPackageVersion)
        if (-not $ok) {
            Exit-WithError -Step '安装 OpenClaw' -Hint 'npm install 失败。请检查网络，或手动执行：npm install -g openclaw'
        }
        Write-Ok "OpenClaw 安装成功"
    } else {
        $rawVer = & openclaw --version 2>$null
        Write-Ok "OpenClaw 已安装，版本：$rawVer"

        $choice = Read-Host "升级到脚本推荐版本 $($Config.OpenClawPackageVersion)？(Y/n)"
        if ($choice -eq '' -or $choice -eq 'Y' -or $choice -eq 'y') {
            Write-Info "正在升级到 $($Config.OpenClawPackageVersion)..."
            $ok = Invoke-NpmWithFallback -Arguments @('update', '-g', $Config.OpenClawPackageVersion)
            if (-not $ok) {
                Write-Warn "升级失败，保留当前版本。稍后可手动执行：npm update -g openclaw"
            } else {
                Write-Ok "升级完成"
                $rawVer = & openclaw --version 2>$null
                Write-Ok "当前版本：$rawVer"
            }
        } else {
            Write-Info "保留当前版本"
        }
    }
}

# ============================================
# 4. 调用官方向导
# ============================================
function Invoke-OpenClaWizard {
    Write-Step "配置 OpenClaw"

    Write-Info "OpenClaw 官方向导将帮助你配置："
    Write-Info "  1. AI 模型（如 DeepSeek）和 API Key"
    Write-Info "  2. QQ 机器人 AppID 和 ClientSecret"
    Write-Info "  3. 其他可选设置"
    Write-Warn "请提前准备好以下信息："
    Write-Warn "  - DeepSeek API Key（https://platform.deepseek.com/）"
    Write-Warn "  - QQ Bot AppID 和 ClientSecret（https://q.qq.com/）"
    Write-Info ""
    $resp = Read-Host "准备好了吗？按 Enter 启动配置向导，输入 S 跳过"
    if ($resp -eq 'S' -or $resp -eq 's') {
        Write-Warn "跳过配置向导。稍后可手动运行：openclaw setup"
        return
    }

    # 优先尝试 onboarding（更现代的流程）
    $useOnboard = $false
    try {
        $helpText = & openclaw --help 2>&1 | Out-String
        if ($helpText -match 'onboard') { $useOnboard = $true }
    } catch {}

    if ($useOnboard) {
        Write-Info "启动 onbaording 向导..."
        & openclaw onboard --install-daemon 2>&1
    } else {
        Write-Info "启动 setup 向导..."
        & openclaw setup 2>&1
    }

    if ($LASTEXITCODE -ne 0) {
        Exit-WithError -Step '配置向导' -Hint '配置向导执行失败。请确保已准备好 API Key，稍后手动运行：openclaw setup'
    }
    Write-Ok "配置完成"
}

# ============================================
# 5. 读取工作区
# ============================================
function Get-OpenClawWorkspace {
    $ws = $null
    try {
        $ws = & openclaw config get agents.defaults.workspace 2>$null
        $ws = $ws.Trim()
    } catch {}
    if (-not $ws -or $ws -eq '') {
        $ws = "$env:USERPROFILE\.openclaw\workspace"
        Write-Warn "工作区未配置，使用默认路径：$ws"
    }
    if (-not (Test-Path $ws)) {
        New-Item -ItemType Directory -Path $ws -Force | Out-Null
    }
    Write-Ok "工作区路径：$ws"
    return $ws
}

# ============================================
# 6. 同步模板文件
# ============================================
function Sync-TemplateFiles {
    param([string]$Workspace)

    Write-Step "同步机器人模板"

    $tplDir = Join-Path $RepoRoot 'templates'
    if (-not (Test-Path $tplDir)) { Write-Warn "模板目录不存在，跳过"; return }

    $templates = Get-ChildItem -Path $tplDir -Filter '*.md'
    $copied = 0
    $skipped = 0

    foreach ($tpl in $templates) {
        $dest = Join-Path $Workspace $tpl.Name
        if (Test-Path $dest) {
            Write-Info "  跳过（已存在）：$($tpl.Name)"
            $skipped++
        } else {
            Copy-Item -Path $tpl.FullName -Destination $dest
            Write-Ok "已创建：$($tpl.Name)"
            $copied++
        }
    }

    Write-Info "完成：新建 $copied 个，跳过 $skipped 个"
    if ($copied -gt 0) {
        Write-Info "模板文件位于：$Workspace"
        Write-Info "编辑这些文件可以定制机器人的性格和说话方式。"
    }
}

# ============================================
# 7. 检查端口
# ============================================
function Test-PortInUse {
    param([int]$Port)
    try {
        $listener = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
        $connections = $listener.GetActiveTcpListeners()
        return ($connections | Where-Object { $_.Port -eq $Port }) -ne $null
    } catch { return $false }
}

function Get-FreePort {
    param([int]$PreferredPort)
    $maxScan = $Config.PortScanRange
    for ($i = 0; $i -lt $maxScan; $i++) {
        $port = $PreferredPort + $i
        if (-not (Test-PortInUse $port)) { return $port }
    }
    return $null
}

# ============================================
# 8. 安装并启动 Gateway
# ============================================
function Install-GatewayService {
    param([int]$Port)

    Write-Step "配置 Gateway 端口"

    # 读取当前端口
    $currentPort = $null
    try {
        $cp = & openclaw config get gateway.port 2>$null
        if ($cp -and $cp.Trim() -ne '') { $currentPort = [int]($cp.Trim()) }
    } catch {}

    if ($currentPort) {
        Write-Info "当前配置端口：$currentPort"
        if (Test-PortInUse $currentPort) {
            if ($currentPort -eq $Config.PreferredGatewayPort) {
                # 检查是否被自己占用
                $status = & openclaw gateway status --require-rpc 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Warn "Gateway 服务可能已在运行（端口 $currentPort）"
                    return $false  # 已在运行，不需要重复启动
                }
            }
            Write-Warn "端口 $currentPort 被占用，正在扫描空闲端口..."
            $freePort = Get-FreePort -PreferredPort $Config.PreferredGatewayPort
            if (-not $freePort) {
                Exit-WithError -Step '端口配置' -Hint "无法找到空闲端口（从 $($Config.PreferredGatewayPort) 起扫描 $($Config.PortScanRange) 个端口均被占用）"
            }
            Write-Ok "找到空闲端口：$freePort"
            & openclaw config set gateway.port $freePort --strict-json 2>$null
            if ($LASTEXITCODE -ne 0) {
                Exit-WithError -Step '端口配置' -Hint "设置端口失败。手动执行：openclaw config set gateway.port $freePort --strict-json"
            }
            $currentPort = $freePort
            Write-Ok "端口已设为：$currentPort"
        } else {
            Write-Ok "端口 $currentPort 可用"
        }
    } else {
        $currentPort = $Config.PreferredGatewayPort
        if (Test-PortInUse $currentPort) {
            Write-Warn "首选端口 $currentPort 被占用，正在扫描空闲端口..."
            $freePort = Get-FreePort -PreferredPort $Config.PreferredGatewayPort
            if (-not $freePort) {
                Exit-WithError -Step '端口配置' -Hint "无法找到空闲端口。"
            }
            Write-Ok "找到空闲端口：$freePort"
            $currentPort = $freePort
        }
        & openclaw config set gateway.port $currentPort --strict-json 2>$null
        if ($LASTEXITCODE -ne 0) {
            Exit-WithError -Step '端口配置' -Hint "设置端口失败。"
        }
        Write-Ok "端口已设为：$currentPort"
    }

    Write-Step "安装 Gateway 服务"

    Write-Info "正在安装 Gateway 服务（端口 $currentPort）..."
    & openclaw gateway install --force --port $currentPort 2>&1
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError -Step '安装 Gateway 服务' -Hint "服务安装失败。可手动执行：openclaw gateway install --force --port $currentPort"
    }
    Write-Ok "Gateway 服务安装完成"

    return $true
}

function Start-GatewayService {
    Write-Step "启动 Gateway"

    Write-Info "正在启动 Gateway..."
    & openclaw gateway start 2>&1
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError -Step '启动 Gateway' -Hint '启动失败。稍后可手动执行：openclaw gateway start'
    }

    # 等待启动
    Start-Sleep -Seconds 3

    # 健康检查
    Write-Info "检查服务状态..."
    & openclaw gateway status --require-rpc 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Gateway 运行正常"
    } else {
        Write-Warn "Gateway 状态检查未通过（可能还在启动中）"
        Write-Warn "稍后可手动确认：openclaw gateway status --require-rpc"
    }
}

# ============================================
# 9. 总结输出
# ============================================
function Show-Summary {
    param([string]$Workspace, [int]$Port)

    Write-Step "部署完成"
    Write-Ok "恭喜！OpenClaw 已成功安装并启动！"
    Write-Info ""
    Write-Info "=== 重要信息 ==="
    Write-Info "工作区路径：$Workspace"
    Write-Info "Gateway 端口：$Port"
    Write-Info "配置文件：$((& openclaw config file 2>$null | Out-String).Trim())"
    Write-Info ""
    Write-Info "=== 下一步 ==="
    Write-Info "1. 在 QQ 上给机器人发消息试试吧！"
    Write-Info "2. 编辑工作区中的 IDENTITY.md、SOUL.md 定制机器人性格"
    Write-Info "3. 如果遇到问题："
    Write-Info "   openclaw gateway status"
    Write-Info "   openclaw doctor"
    Write-Info "   openclaw config validate"
}

# ============================================
# 主流程
# ============================================
function Main {
    Write-Host "===========================================" -ForegroundColor DarkGray
    Write-Host " OpenClaw 快速部署向导" -ForegroundColor White
    Write-Host " 让不懂技术的小白也能跑起 AI 机器人" -ForegroundColor DarkGray
    Write-Host "===========================================" -ForegroundColor DarkGray
    Write-Host ""

    Invoke-PrerequisitesCheck
    Ensure-Node
    Ensure-OpenClaw
    Invoke-OpenClaWizard

    $workspace = Get-OpenClawWorkspace
    Sync-TemplateFiles -Workspace $workspace

    $needStart = Install-GatewayService -Port $Config.PreferredGatewayPort
    if ($needStart) {
        Start-GatewayService
    } else {
        Write-Warn "Gateway 服务已在运行，跳过启动步骤"
    }

    # 获取最终端口
    $finalPort = $Config.PreferredGatewayPort
    try {
        $cp = & openclaw config get gateway.port 2>$null
        if ($cp -and $cp.Trim() -ne '') { $finalPort = [int]($cp.Trim()) }
    } catch {}

    Show-Summary -Workspace $workspace -Port $finalPort
}

# 执行
Main
