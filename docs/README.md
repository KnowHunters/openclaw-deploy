# OpenClaw Deploy 🚀

> **终极版一键部署脚本** | The Ultimate One-Click Deployment Script for OpenClaw
> 
> **By KnowHunters (知识猎人)**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-green.svg)]()
[![Author](https://img.shields.io/badge/author-KnowHunters-orange.svg)](https://github.com/KnowHunters)

---

## 📌 前置条件 | Prerequisites

本脚本仅在 **Ubuntu 24.04** 系统中测试通过。如果你的服务器是其他系统，建议使用 [reinstall](https://github.com/bin456789/reinstall) 项目 DD 成纯净版 Ubuntu：

```bash
# 下载 reinstall 脚本
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -O reinstall.sh https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh

# DD 成 Ubuntu 24.04 (会重装系统，请提前备份数据！)
bash reinstall.sh ubuntu 24.04
```

> ⚠️ **警告**: 此操作会清除服务器所有数据，请确保已备份重要文件！

---

## ⚡ Quick Start

```bash
# ⚡️ 新版安装 (推荐)
bash <(curl -fsSL https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main/scripts/manager.sh)

# 备用安装 (传统方式)
bash <(curl -fsSL https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main/install.sh)
```

<details>
<summary>📌 高级选项</summary>

```bash
# 非交互式安装 (CI/CD 环境，需设置环境变量)
export TELEGRAM_BOT_TOKEN="your_token"
export API_KEY="your_api_key"
curl -fsSL https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main/install.sh -o install.sh && sudo -E bash install.sh -n

# 仅更新 (保留配置)
curl -fsSL https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main/install.sh -o install.sh && sudo bash install.sh -u

# 自定义网关配置
export GATEWAY_BIND="0.0.0.0"
export GATEWAY_PORT="8080"
curl -fsSL https://raw.githubusercontent.com/KnowHunters/openclaw-deploy/main/install.sh -o install.sh && sudo -E bash install.sh
```

</details>

## ⚙️ 配置说明

安装完成后，脚本会自动启动配置向导：

1.  **自动运行** `openclaw onboard` (5秒倒计时后)
2.  **配置完成** 后，脚本会自动启动服务并保存 pm2 进程

无需手动执行任何额外命令。

如果需要手动重新配置：
```bash
sudo -u openclaw openclaw onboard
```



---

## ✨ Features

| 🔒 **安全优先** | 默认绑定 `127.0.0.1`，支持重装确认、配置备份 |
| 📊 **监控套件** | 5 个运维脚本：健康检查、日志清理、自动备份、恢复、管理面板 |
| 🎨 **极致体验** | Spinner 进度条、结构化汇总面板、彩色日志 |
| 🛠 **开发者工具链** | GitHub CLI、ripgrep、fd、bat、htop、yt-dlp、pandas |
| 🔄 **更新模式** | `-u` 参数仅更新核心组件，保留所有配置 |

---

## 📁 Project Structure

```
openclaw-deploy/
├── install.sh              # 主安装脚本
├── README.md
├── LICENSE
├── scripts/                # 监控与运维套件
│   ├── health-monitor.sh   # 健康检查 + 自动恢复
│   ├── log-cleanup.sh      # 日志轮转清理
│   ├── backup.sh           # 自动配置备份
│   ├── restore.sh          # 交互式恢复向导
│   └── manager.sh          # 一键管理面板
└── docs/
    └── ...
```

---

## 🖥 Management Panel

安装完成后，运行管理面板：

```bash
/home/openclaw/openclaw-scripts/manager.sh
```

功能菜单：
- 启动/停止/重启服务
- 查看实时日志
- 运行健康检查
- 查看性能统计
- 创建/恢复备份
- 清理日志
- 更新 OpenClaw

---

## 📋 Automated Tasks

脚本自动配置以下 Cron 任务：

| 任务 | 频率 | 说明 |
|------|------|------|
| 健康检查 | 每 5 分钟 | 自动检测服务状态，故障时自动重启 |
| 自动备份 | 每日凌晨 3 点 | 备份配置文件，保留 30 天 |
| 日志清理 | 每周日凌晨 2 点 | 清理过期日志，释放磁盘空间 |

> 💡 **性能监控**: 使用 PM2 内置功能 `pm2 monit` 查看实时 CPU/内存

---

## 🔧 Environment Variables

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `GATEWAY_BIND` | `127.0.0.1` | 网关绑定地址 (推荐保持默认) |
| `GATEWAY_PORT` | `18789` | 网关端口 |
| `TELEGRAM_BOT_TOKEN` | - | Telegram Bot Token (非交互模式必填) |
| `API_KEY` | - | AI 模型 API Key (非交互模式必填) |
| `API_BASE_URL` | `https://api.openai.com` | API 服务商地址 |

---

## 🛡 Security Best Practices

1. **默认本地绑定**: 网关默认绑定 `127.0.0.1`，仅允许本地访问
2. **远程访问推荐**: 使用 SSH 隧道或 Nginx 反向代理 + HTTPS
3. **配置备份**: 重装前自动备份，防止数据丢失
4. **权限隔离**: 使用专用 `openclaw` 用户运行，非 root

---

## 📚 Quick Commands

```bash
# 切换到 openclaw 用户
su - openclaw

# 查看服务状态
pm2 status

# 查看实时日志
pm2 logs openclaw

# 重启服务
pm2 restart openclaw

# 健康检查
openclaw doctor

# 查看可用技能
openclaw skills list
```

---

## 🤝 Contributing

欢迎提交 Issue 和 Pull Request！

---

## 👨‍💻 Author

**KnowHunters (知识猎人)**

- GitHub: [@KnowHunters](https://github.com/KnowHunters)

---

## 📄 License

MIT License - Copyright (c) 2026 KnowHunters

See [LICENSE](LICENSE) for details.
