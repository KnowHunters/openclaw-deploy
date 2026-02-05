# OpenClaw Deploy 2.0

> 🦞 智能一键部署系统 - 让 OpenClaw 安装变得简单

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ✨ 特性

- 🧠 **智能检测** - 自动识别系统环境，智能选择安装模式
- 🎨 **美观界面** - 统一的 TUI 界面，友好的交互体验
- 🌍 **双版本支持** - 国际版 (openclaw) / 中文版 (openclaw-cn)
- 🔧 **交互式配置** - 引导式配置向导，小白也能轻松上手
- 📦 **技能管理** - 搜索、安装、管理 OpenClaw Skills
- 🏥 **健康检查** - 系统状态监控、诊断和自动修复
- 🔄 **自动更新** - 脚本自更新功能

## 🚀 快速开始

```bash
curl -fsSL https://your-repo/deploy.sh | bash
```

## 📁 项目结构

```
openclaw-deploy/
├── deploy.sh              # 主入口脚本
├── lib/                   # 模块库
│   ├── ui.sh              # UI 框架
│   ├── utils.sh           # 工具函数
│   ├── detector.sh        # 环境检测
│   ├── installer.sh       # 安装管理
│   ├── wizard.sh          # 配置向导
│   ├── skills.sh          # 技能管理
│   ├── software.sh        # 软件管理
│   ├── health.sh          # 状态检查
│   └── updater.sh         # 自更新
├── templates/             # 配置模板
├── data/                  # 数据文件
├── docs/                  # 开发文档
├── README.md
├── LICENSE
└── .gitignore
```

## 📖 文档

- [重构开发计划](docs/重构开发计划.md)
- [补充细节](docs/重构开发计划_补充细节.md)
- [官方文档核心要点](docs/官方文档核心要点.md)

## 🔧 开发

### 环境要求

- Bash 4.0+
- curl
- jq (可选)

### 本地测试

```bash
# 克隆仓库
git clone https://github.com/KnowHunters/openclaw-deploy.git
cd openclaw-deploy

# 运行脚本
bash deploy.sh
```

## 📝 更新日志

### v2.0.0 (开发中)
- 🆕 全新重构，统一 UI 框架
- 🆕 智能环境检测
- 🆕 交互式配置向导
- 🆕 技能管理功能
- 🆕 小白友好设计

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE)

## 🙏 致谢

- [OpenClaw](https://github.com/openclaw/openclaw) - 官方项目
- [OpenClaw 中文版](https://clawd.org.cn/) - 中文本地化
