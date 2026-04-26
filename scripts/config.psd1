#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ====================================
# config.psd1 —— 纯数据，不执行任何表达式
# 所有类型转换在主脚本中完成
# ====================================

@{
    # ---- Node.js ----
    MinimumNodeVersionString        = '22.16.0'
    PreferredNodeVersionString      = '22.16.0'
    NodeMsiUrl                      = 'https://nodejs.org/dist/v22.16.0/node-v22.16.0-x64.msi'

    # ---- OpenClaw ----
    # 'latest' 表示安装最新稳定版（推荐新手）
    OpenClawPackageVersion          = 'openclaw@latest'
    CommandTimeoutSeconds           = 120

    # ---- npm registries（主源失败自动回退） ----
    NpmRegistries                   = @(
        'https://registry.npmmirror.com'
        'https://registry.npmjs.org'
    )

    # ---- Gateway 端口 ----
    PreferredGatewayPort            = 18789
    PortScanRange                   = 20

    # ---- 下载 ----
    DownloadRetryCount              = 3
}
