@{
    # ============================================
    # OpenClaw Quick-Start 配置
    # ============================================

    # Node.js
    MinimumNodeVersion        = [Version]'22.16.0'
    PreferredNodeVersion      = [Version]'22.16.0'
    NodeMsiUrl                = 'https://nodejs.org/dist/v22.16.0/node-v22.16.0-x64.msi'
    NodeInstallerPath         = "$env:TEMP\openclaw-node-install.msi"

    # OpenClaw
    OpenClawPackageVersion    = 'openclaw@3.1.13'
    CommandTimeoutSeconds     = 120

    # npm registries（主源失败自动回退）
    NpmRegistries             = @(
        'https://registry.npmmirror.com'
        'https://registry.npmjs.org'
    )

    # Gateway 端口
    PreferredGatewayPort      = 18789
    PortScanRange             = 20  # 最多尝试 20 个端口

    # 下载
    DownloadRetryCount        = 3

    # OpenClaw 常用命令
    OpenClawCommands          = @{
        ConfigFile    = 'openclaw config file'
        GatewayStatus = 'openclaw gateway status'
        Doctor        = 'openclaw doctor'
        ConfigValidate = 'openclaw config validate'
    }
}
