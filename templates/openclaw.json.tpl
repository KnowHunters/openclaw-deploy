{
  "agents": {
    "defaults": {
      "workspace": "~/.openclaw/workspace",
      "contextTokens": {{CONTEXT_TOKENS}},
      "maxConcurrent": 4,
      "model": {
        "primary": "{{PRIMARY_MODEL}}",
        "fallbacks": [{{FALLBACK_MODELS}}]
      }{{#HEARTBEAT}},
      "heartbeat": {
        "every": "{{HEARTBEAT_INTERVAL}}",
        "target": "last"
      }{{/HEARTBEAT}}
    }
  },
  "models": {
    "providers": {
      {{#ANTHROPIC}}
      "anthropic": {
        "apiKey": "${ANTHROPIC_API_KEY}"
      }{{#HAS_MORE}},{{/HAS_MORE}}
      {{/ANTHROPIC}}
      {{#OPENAI}}
      "openai": {
        "apiKey": "${OPENAI_API_KEY}"
      }{{#HAS_MORE}},{{/HAS_MORE}}
      {{/OPENAI}}
      {{#DEEPSEEK}}
      "deepseek": {
        "apiKey": "${DEEPSEEK_API_KEY}",
        "baseURL": "https://api.deepseek.com/v1"
      }{{#HAS_MORE}},{{/HAS_MORE}}
      {{/DEEPSEEK}}
      {{#GOOGLE}}
      "google": {
        "apiKey": "${GOOGLE_API_KEY}"
      }{{#HAS_MORE}},{{/HAS_MORE}}
      {{/GOOGLE}}
      {{#OLLAMA}}
      "ollama": {
        "baseUrl": "{{OLLAMA_URL}}"
      }
      {{/OLLAMA}}
    }
  },
  "channels": {
    {{#TELEGRAM}}
    "telegram": {
      "token": "${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "open"{{#TELEGRAM_GROUPS}},
      "groups": {
        "*": {
          "requireMention": {{TELEGRAM_MENTION}}
        }
      }{{/TELEGRAM_GROUPS}}
    }{{#HAS_MORE_CHANNELS}},{{/HAS_MORE_CHANNELS}}
    {{/TELEGRAM}}
    {{#WHATSAPP}}
    "whatsapp": {
      "dmPolicy": "pairing"{{#WHATSAPP_ALLOWFROM}},
      "allowFrom": ["{{WHATSAPP_ALLOWFROM}}"]{{/WHATSAPP_ALLOWFROM}}
    }{{#HAS_MORE_CHANNELS}},{{/HAS_MORE_CHANNELS}}
    {{/WHATSAPP}}
    {{#DISCORD}}
    "discord": {
      "token": "${DISCORD_BOT_TOKEN}",
      "activation": "mention"
    }
    {{/DISCORD}}
  },
  "gateway": {
    "port": {{GATEWAY_PORT}},
    "bind": "{{GATEWAY_BIND}}",
    "auth": {
      "mode": "token",
      "token": "${OPENCLAW_GATEWAY_TOKEN}"
    }
  }
}
