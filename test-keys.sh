#!/bin/bash
# 测试按键码

echo "按任意键测试 (按 q 退出):"
echo ""

while true; do
    read -rsn1 key
    
    # 显示第一个字符的十六进制
    printf "第1个字符: '%s' (hex: " "$key"
    printf '%s' "$key" | xxd -p
    printf ")\n"
    
    # 如果是 ESC，继续读取
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.1 rest
        printf "后续字符: '%s' (hex: " "$rest"
        printf '%s' "$rest" | xxd -p
        printf ")\n"
        printf "完整序列: ESC%s\n" "$rest"
    fi
    
    echo ""
    
    [[ "$key" == "q" ]] && break
done
