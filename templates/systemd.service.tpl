[Unit]
Description=OpenClaw AI Gateway
Documentation=https://docs.openclaw.ai/
After=network.target

[Service]
Type=simple
User={{USER}}
Group={{USER}}
WorkingDirectory={{HOME}}

# 环境变量
Environment=PATH={{NPM_BIN}}:/usr/local/bin:/usr/bin:/bin
Environment=NODE_ENV=production
EnvironmentFile=-{{ENV_FILE}}

# 启动命令
ExecStart={{CLI_PATH}} gateway

# 重启策略
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# 安全设置
NoNewPrivileges=true
PrivateTmp=true

# 资源限制
MemoryLimit=2G
CPUQuota=150%

# 日志
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw

[Install]
WantedBy=multi-user.target
