<#
.SYNOPSIS
    OpenClaw 快速部署向导 — Windows 中文新手安装器
.DESCRIPTION
    自动安装 Node.js、OpenClaw，调用官方向导配置，处理端口冲突，
    同步模板文件到工作区，启动 Gateway 服务。
.NOTES
    Version  : 2.0.1
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
$rawConfig  = Import-LocalizedData -BaseDirectory $ScriptRoot -FileName 'config.psd1'

# 运行时转换类型（config.psd1 是纯数据哈希表，不包含表达式）
$Config = @{
    MinimumNodeVersion        = [Version]$rawConfig.MinimumNodeVersionString
    PreferredNodeVersion      = [Version]$rawConfig.PreferredNodeVersionString
    NodeMsiUrl                = $rawConfig.NodeMsiUrl
    NodeInstallerPath         = Join-Path $env:TEMP 'openclaw-node-install.msi'
    OpenClawPackageVersion    = $rawConfig.OpenClawPackageVersion
    CommandTimeoutSeconds     = $rawConfig.CommandTimeoutSeconds
    NpmRegistries             = $rawConfig.NpmRegistries
    PreferredGatewayPort      = $rawConfig.PreferredGatewayPort
    PortScanRange             = $rawConfig.PortScanRange
    DownloadRetryCount        = $rawConfig.DownloadRetryCount
}

# ============================================
# 日志函数
# ============================================
$Host.UI.RawUI.ForegroundColor = $null

function Write-Info   { Write-Host "   $($args[0])" -ForegroundColor Cyan }
function Write-Ok     { Write-Host " [OK] $($args[0])" -ForegroundColor Green }
function Write-Warn   { Write-Host " [!]  $($args[0])" -ForegroundColor Yellow }
function Write-Err    { Write-Host " [X]  $($args[0])" -ForegroundColor Red }
function Write-Step   {
    Write-Host "`n==========================================" -ForegroundColor DarkGray
    Write-Host " $($args[0])" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor DarkGray
}

function Exit-WithError {
    param([string]$Step, [string]$Hint)
    Write-Err "步骤「$Step」失败！"
    if ($Hint) { Write-Warn "建议：$Hint" }
    Write-Info "`n--- 故障排查信息 ---"
    try {
        $cfgFile = & openclaw config file --json 2>$null | ConvertFrom-Json
        if ($cfgFile) { Write-Info "OpenClaw 配置文件：$cfgFile" }
    } catch {
        Write-Info "OpenClaw 配置文件路径：(无法获取)"
    }
    try {
        $ws = & openclaw config get agents.defaults.workspace 2>$null
        Write-Info "OpenClaw 工作区路径：$($ws.Trim())"
    } catch {
        Write-Info "OpenClaw 工作区路径：(无法获取)"
    }
    Write-Info "`n建议运行以下诊断命令："
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
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-VersionObject {
    param([string]$VersionString)
    if (-not $VersionString) { return $null }
    try { return [Version]($VersionString.TrimStart('v').TrimStart('V')) } catch { return $null }
}

function Invoke-CommandCheck {
    <#
    .SYNOPSIS
        执行命令并安全返回 exit code，不会被 write 调用篡改
    #>
    param([scriptblock]$ScriptBlock)
    $global:__LAST_EXITCODE = $null
    & $ScriptBlock
    $global:__LAST_EXITCODE = $LASTEXITCODE
    return $LASTEXITCODE
}

function Invoke-NpmWithFallback {
    param([string[]]$Arguments)
    $npm = (Get-Command npm).Source
    foreach ($reg in $Config.NpmRegistries) {
        Write-Info "尝试镜像源：$reg"
        $argsWithReg = $Arguments + @('--registry', $reg)
        $proc = Start-Process -FilePath $npm -ArgumentList $argsWithReg -Wait -NoNewWindow -PassThru
        if ($proc.ExitCode -eq 0) {
            return $true
        }
        Write-Warn "镜像源 $reg 失败，尝试下一个..."
    }
    return $false
}

function Test-UrlReachable {
    param([string]$Url)
    try {
        $req = [System.Net.WebRequest]::CreateHttp($Url)
        $req.Timeout = 5000
        $req.Method = 'GET'  # GET 比 HEAD 兼容性更好
        $resp = $req.GetResponse()
        $resp.Close()
        return $true
    } catch {
        return $false
    }
}

# ============================================
# 1. 环境预检
# ============================================
function Invoke-PrerequisitesCheck {
    Write-Step "环境预检"

    if ($env:OS -ne 'Windows_NT') {
        Exit-WithError -Step '环境预检' -Hint '本工具仅支持 Windows 10/11 x64。'
    }
    if (-not [Environment]::Is64BitProcess) {
        Exit-WithError -Step '环境预检' -Hint '本工具仅支持 64 位 Windows。'
    }
    Write-Ok "操作系统：Windows 10/11 x64"

    if ($PSVersionTable.PSVersion -lt [Version]'5.1') {
        Exit-WithError -Step '环境预检' `
            -Hint "PowerShell 版本过低（$($PSVersionTable.PSVersion)），需要 5.1+。请升级 Windows Management Framework。"
    }
    Write-Ok "PowerShell 版本：$($PSVersionTable.PSVersion)"

    if (-not (Test-Path $env:TEMP)) {
        Exit-WithError -Step '环境预检' -Hint "临时目录 $env:TEMP 不可用。"
    }
    Write-Ok "临时目录可用：$env:TEMP"

    $userDir = [Environment]::GetFolderPath('UserProfile')
    if (-not (Test-Path $userDir)) {
        Exit-WithError -Step '环境预检' -Hint "用户目录 $userDir 不可用。"
    }
    Write-Ok "用户目录可用：$userDir"

    # 测试是否有写入权限
    try {
        $testFile = Join-Path $env:TEMP 'openclaw-precheck-test.txt'
        'test' | Out-File -FilePath $testFile -Encoding UTF8
        Remove-Item $testFile -Force
        Write-Ok "目录写入权限正常"
    } catch {
        Exit-WithError -Step '环境预检' -Hint "临时目录写入失败，请检查磁盘空间和权限。"
    }

    # 网络测试
    $reachable = $false
    foreach ($reg in $Config.NpmRegistries) {
        if (Test-UrlReachable $reg) {
            $reachable = $true
            Write-Ok "网络可达：$reg"
            break
        } else {
            Write-Warn "网络不可达：$reg"
        }
    }
    if (-not $reachable) {
        Exit-WithError -Step '环境预检' -Hint '无法访问任何 npm 镜像源，请检查网络连接。'
    }
}

# ============================================
# 2. Node.js 检查与安装
# ============================================
function Ensure-Node {
    Write-Step "检查 Node.js"

    $nodeInstalled = $false
    $nodeVersion = $null

    if (Test-Command node) {
        $rawVersion = Try { & node --version 2>$null } Catch { '' }
        $nodeVersion = Get-VersionObject $rawVersion
        if ($nodeVersion) {
            Write-Ok "Node.js 已安装，版本：$nodeVersion"
            if ($nodeVersion -ge $Config.MinimumNodeVersion) {
                $nodeInstalled = $true
            } else {
                Write-Warn "版本过低（$nodeVersion），需要 $($Config.MinimumNodeVersion)，即将升级..."
            }
        } else {
            Write-Warn "无法解析 Node.js 版本，将重新安装..."
        }
    }

    if (-not $nodeInstalled) {
        Write-Info "正在下载 Node.js $($Config.PreferredNodeVersion)..."
        $retry = 0
        $downloaded = $false
        $msiPath = $Config.NodeInstallerPath

        # 清除旧的下载缓存
        if (Test-Path $msiPath) { Remove-Item $msiPath -Force }

        while ($retry -lt $Config.DownloadRetryCount -and -not $downloaded) {
            try {
                Write-Info "  下载中... ($($retry + 1)/$($Config.DownloadRetryCount))"
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($Config.NodeMsiUrl, $msiPath)
                $downloaded = $true
                Write-Ok "下载完成"
            } catch {
                $retry++
                if ($retry -ge $Config.DownloadRetryCount) {
                    Exit-WithError -Step '安装 Node.js' `
                        -Hint "下载失败，请手动打开 $($Config.NodeMsiUrl) 下载安装，再重新运行本脚本。"
                }
                Write-Warn "下载失败，重试 $retry/$($Config.DownloadRetryCount)..."
                Start-Sleep -Seconds 2
            }
        }

        Write-Info "正在安装 Node.js（静默安装，请勿关闭窗口）..."
        $msiArgList = "/i `"$msiPath`" /qn /norestart"
        $proc = Start-Process -FilePath msiexec.exe -ArgumentList $msiArgList -Wait -PassThru -NoNewWindow
        # 0 = 成功, 3010 = 成功但需要重启
        if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
            Exit-WithError -Step '安装 Node.js' `
                -Hint "MSI 安装程序退出码 $($proc.ExitCode)。可尝试手动安装：$($Config.NodeMsiUrl)"
        }

        # 刷新 PATH（合并 machine + user path）
        try {
            $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine') ?? ''
            $userPath    = [Environment]::GetEnvironmentVariable('Path', 'User') ?? ''
            $env:Path = "$machinePath;$userPath"
        } catch {
            Write-Warn "无法自动刷新 PATH，请手动重启终端后重新运行"
        }

        # 多次验证安装
        $retry = 0
        $verified = $false
        while ($retry -lt 5 -and -not $verified) {
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
            Write-Warn "Node.js 安装后验证失败。新的环境变量可能需要重启终端生效。"
            Write-Warn "请关闭当前窗口，重新以管理员身份运行本脚本。"
            Pause
            exit 1
        }
    }

    # 确保 npm 可用
    if (-not (Test-Command npm)) {
        Exit-WithError -Step '检查 npm' -Hint 'Node.js 安装不完整，npm 不可用。请手动安装 Node.js 后重试。'
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

        # 安装后验证
        $rawVer = Try { & openclaw --version 2>$null } Catch { $null }
        if (-not $rawVer) {
            Exit-WithError -Step '验证 OpenClaw 安装' -Hint '安装成功但无法执行 openclaw 命令。请检查 PATH 环境变量。'
        }
        Write-Ok "OpenClaw 安装成功，版本：$rawVer"
    } else {
        $rawVer = Try { & openclaw --version 2>$null } Catch { $null }
        Write-Ok "OpenClaw 已安装，版本：$rawVer"

        try {
            $choice = Read-Host "升级到脚本推荐版本 $($Config.OpenClawPackageVersion)？(Y/n)"
        } catch {
            $choice = 'n'
            Write-Warn "无法读取输入，保留当前版本"
        }
        if ($choice -eq '' -or $choice -match '^[Yy]$') {
            Write-Info "正在升级到 $($Config.OpenClawPackageVersion)..."
            $ok = Invoke-NpmWithFallback -Arguments @('update', '-g', $Config.OpenClawPackageVersion)
            if (-not $ok) {
                Write-Warn "升级失败，保留当前版本。稍后可手动执行：npm update -g openclaw"
            } else {
                Write-Ok "升级完成"
                $rawVer = Try { & openclaw --version 2>$null } Catch { $null }
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

    try { $resp = Read-Host "准备好了吗？按 Enter 启动配置向导，输入 S 跳过" }
    catch { $resp = 'S'; Write-Warn "无法读取输入，将跳过配置向导" }

    if ($resp -eq 'S' -or $resp -eq 's') {
        Write-Warn "跳过配置向导。稍后可手动运行：openclaw setup"
        return
    }

    $useOnboard = $false
    try {
        $helpText = & openclaw --help 2>&1 | Out-String
        if ($helpText -match 'onboard') { $useOnboard = $true }
    } catch {}

    $cmdResult = $null
    if ($useOnboard) {
        Write-Info "启动 onboarding 向导..."
        & openclaw onboard --install-daemon 2>&1
        $cmdResult = $LASTEXITCODE
    } else {
        Write-Info "启动 setup 向导..."
        & openclaw setup 2>&1
        $cmdResult = $LASTEXITCODE
    }

    if ($cmdResult -and $cmdResult -ne 0) {
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
        if ($ws) { $ws = $ws.Trim() }
    } catch {}

    if (-not $ws) {
        $ws = Join-Path $env:USERPROFILE '.openclaw\workspace'
        Write-Warn "工作区未配置，使用默认路径：$ws"
    }

    if (-not (Test-Path $ws)) {
        New-Item -ItemType Directory -Path $ws -Force | Out-Null
        Write-Info "创建工作区目录：$ws"
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
    if (-not (Test-Path $tplDir)) {
        Write-Warn "模板目录 $tplDir 不存在，跳过模板同步"
        return
    }

    $templates = Get-ChildItem -Path $tplDir -Filter '*.md' -ErrorAction SilentlyContinue
    if (-not $templates -or $templates.Count -eq 0) {
        Write-Warn "模板目录为空，跳过"
        return
    }

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
        Write-Info "模板位于：$Workspace"
        Write-Info "编辑这些文件可以定制机器人的性格和说话方式。"
    }
}

# ============================================
# 7. 端口检测
# ============================================
function Test-PortInUse {
    param([int]$Port)
    try {
        $props = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
        $listeners = $props.GetActiveTcpListeners()
        return ($listeners | Where-Object { $_.Port -eq $Port }) -ne $null
    } catch {
        # 无法检测时假定被占用（安全策略）
        return $true
    }
}

function Get-FreePort {
    param([int]$PreferredPort)
    for ($i = 0; $i -lt $Config.PortScanRange; $i++) {
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

    $currentPort = $null
    try {
        $cp = & openclaw config get gateway.port 2>$null
        if ($cp -match '\d+') { $currentPort = [int]($cp.Trim()) }
    } catch {}

    if ($currentPort -and $currentPort -gt 0) {
        Write-Info "当前配置端口：$currentPort"
        if (Test-PortInUse $currentPort) {
            # 检查是否是 OpenClaw 自己占用的
            & openclaw gateway status --require-rpc 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Warn "Gateway 服务已在运行（端口 $currentPort），跳过安装"
                return $false
            }

            Write-Warn "端口 $currentPort 被其他程序占用，正在扫描空闲端口..."
            $freePort = Get-FreePort -PreferredPort $Config.PreferredGatewayPort
            if (-not $freePort) {
                Exit-WithError -Step '端口配置' `
                    -Hint "无法找到空闲端口（从 $($Config.PreferredGatewayPort) 起扫描 $($Config.PortScanRange) 个端口均被占用）"
            }
            Write-Ok "找到空闲端口：$freePort"

            & openclaw config set gateway.port $freePort --strict-json 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Exit-WithError -Step '端口配置' `
                    -Hint "设置端口失败。手动执行：openclaw config set gateway.port $freePort --strict-json"
            }
            $currentPort = $freePort
            Write-Ok "端口已设为：$currentPort"
        } else {
            Write-Ok "端口 $currentPort 可用"
        }
    } else {
        # 未配置端口
        $currentPort = $Config.PreferredGatewayPort
        if (Test-PortInUse $currentPort) {
            Write-Warn "首选端口 $currentPort 被占用，正在扫描空闲端口..."
            $freePort = Get-FreePort -PreferredPort $Config.PreferredGatewayPort
            if (-not $freePort) {
                Exit-WithError -Step '端口配置' -Hint '无法找到空闲端口，请手动释放端口后重试。'
            }
            $currentPort = $freePort
            Write-Ok "找到空闲端口：$currentPort"
        }

        & openclaw config set gateway.port $currentPort --strict-json 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Exit-WithError -Step '端口配置' -Hint "设置端口失败。手动执行：openclaw config set gateway.port $currentPort --strict-json"
        }
        Write-Ok "端口已设为：$currentPort"
    }

    Write-Step "安装 Gateway 服务"

    Write-Info "正在安装 Gateway 服务（端口 $currentPort）..."
    & openclaw gateway install --force --port $currentPort 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "服务安装返回非零退出码，尝试继续..."
    } else {
        Write-Ok "Gateway 服务安装完成"
    }

    return $true
}

function Start-GatewayService {
    Write-Step "启动 Gateway"

    Write-Info "正在启动 Gateway..."
    & openclaw gateway start 2>&1 | Out-Null
    $startCode = $LASTEXITCODE
    if ($startCode -ne 0) {
        Exit-WithError -Step '启动 Gateway' -Hint "启动失败（退出码 $startCode）。稍后可手动执行：openclaw gateway start"
    }

    Write-Info "等待 Gateway 启动..."
    Start-Sleep -Seconds 3

    Write-Info "检查服务状态..."
    & openclaw gateway status --require-rpc 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Gateway 运行正常"
    } else {
        Write-Warn "Gateway 状态检查未通过（可能还在启动中）"
        Write-Warn "几分钟后请手动确认：openclaw gateway status --require-rpc"
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

    try {
        $cfgPath = (& openclaw config file 2>$null | Out-String).Trim()
        if ($cfgPath) { Write-Info "配置文件：$cfgPath" }
    } catch {}

    Write-Info ""
    Write-Info "=== 下一步 ==="
    Write-Info "1. 去 QQ 上给你的机器人发消息试试吧！"
    Write-Info "2. 编辑工作区中的 IDENTITY.md、SOUL.md 定制机器人性格"
    Write-Info "3. 如果遇到问题，运行以下诊断命令："
    Write-Info "   openclaw gateway status"
    Write-Info "   openclaw doctor"
    Write-Info "   openclaw config validate"
}

# ============================================
# 卸载功能
# ============================================
function Uninstall-All {
    Write-Step "卸载 OpenClaw"

    Write-Warn "即将执行以下操作："
    Write-Warn "  1. 停止并卸载 Gateway 服务"
    Write-Warn "  2. 卸载 npm 全局 openclaw 包"
    Write-Info ""

    $confirm = Read-Host "确认卸载？输入 yes 继续"
    if ($confirm -ne 'yes') {
        Write-Info "已取消"
        exit 0
    }

    # 停止服务
    if (Test-Command openclaw) {
        Write-Info "停止 Gateway 服务..."
        & openclaw gateway stop 2>$null | Out-Null
        Write-Info "卸载 Gateway 服务..."
        & openclaw gateway uninstall 2>$null | Out-Null
        Write-Ok "Gateway 已停止并卸载"
    } else {
        Write-Warn "未检测到 openclaw 命令，跳过服务卸载"
    }

    # 卸载 npm 包
    if (Test-Command npm) {
        Write-Info "卸载 openclaw npm 包..."
        & npm uninstall -g openclaw 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "openclaw npm 包已卸载"
        } else {
            Write-Warn "npm 卸载返回非零退出码，请检查"
        }
    } else {
        Write-Warn "未检测到 npm，跳过包卸载"
    }

    Write-Info ""
    Write-Ok "卸载完成！"
    Write-Info "如果你还想卸载 Node.js，请在 Windows 控制面板 - 程序和功能 中手动操作。"
    Write-Info "工作区文件保留在：$env:USERPROFILE\.openclaw"
    exit 0
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

    try {
        Invoke-PrerequisitesCheck
        Ensure-Node
        Ensure-OpenClaw
        Invoke-OpenClaWizard
    } catch {
        Write-Err "安装环境阶段发生意外错误：$($_.Exception.Message)"
        Write-Info "如果你在安装 Node.js 或 OpenClaw 时遇到问题，请参考 docs/05-troubleshooting.md"
        Pause
        exit 1
    }

    try {
        $workspace = Get-OpenClawWorkspace
        Sync-TemplateFiles -Workspace $workspace
    } catch {
        Write-Warn "工作区/模板处理失败，继续启动 Gateway"
        $workspace = Join-Path $env:USERPROFILE '.openclaw\workspace'
    }

    try {
        $needStart = Install-GatewayService -Port $Config.PreferredGatewayPort
        if ($needStart) { Start-GatewayService }
        else { Write-Warn "Gateway 服务已在运行，跳过启动步骤" }
    } catch {
        Write-Err "Gateway 启动阶段发生错误：$($_.Exception.Message)"
        Exit-WithError -Step 'Gateway 配置与启动' -Hint '请检查端口是否被占用，并参考 docs/05-troubleshooting.md'
    }

    $finalPort = $Config.PreferredGatewayPort
    try {
        $cp = & openclaw config get gateway.port 2>$null
        if ($cp) { $cpNum = [int]($cp.Trim()); if ($cpNum -gt 0) { $finalPort = $cpNum } }
    } catch {}

    Show-Summary -Workspace $workspace -Port $finalPort
}

# ============================================
# 入口
# ============================================
param(
    [switch]$Uninstall,
    [switch]$Help
)

if ($Help) {
    Write-Host "用法："
    Write-Host "  双击 quick-start.bat           全新安装/重装"
    Write-Host "  powershell .\scripts\quick-start.ps1 -Uninstall  完全卸载"
    exit 0
}

if ($Uninstall) {
    Uninstall-All
} else {
    # 检测已有安装，询问分支
    if (Test-Command openclaw) {
        Write-Host "===========================================" -ForegroundColor DarkGray
        Write-Host " OpenClaw 快速部署向导" -ForegroundColor White
        Write-Host "===========================================" -ForegroundColor DarkGray
        Write-Host ""
        Write-Info "检测到 OpenClaw 已安装！"
        $rawVer = Try { & openclaw --version 2>$null } Catch { '未知' }
        Write-Info "当前版本：$rawVer"
        Write-Info ""
        Write-Info "[1] 重新安装（保留配置，覆盖安装）"
        Write-Info "[2] 仅更新到最新版"
        Write-Info "[3] 跳过安装，直接启动"
        Write-Info "[4] 完全卸载"
        Write-Info ""
        $choice = Read-Host "请选择 (1/2/3/4)"
        switch ($choice) {
            '2' {
                $ok = Invoke-NpmWithFallback -Arguments @('update', '-g', $Config.OpenClawPackageVersion)
                if (-not $ok) { Write-Err "更新失败" }
                else { Write-Ok "已更新" }
            }
            '3' {
                Write-Ok "跳过安装"
            }
            '4' {
                Uninstall-All
            }
            default {
                Write-Info "执行全新安装..."
                Main
            }
        }
    } else {
        Main
    }
}
