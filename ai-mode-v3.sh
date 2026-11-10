#!/bin/bash
# ai-mode - V100 Duo GPU 服务模式切换工具
# 用法: ai-mode {llm|video|vllm|off|status|--json}

AP_TIMERS="auto-power-idle.timer auto-power-hibtest.timer auto-power-off.timer"

svc() {
  local cmd=$1; shift
  for u in "$@"; do
    if ! sudo systemctl "$cmd" "$u" 2>/dev/null; then echo "警告: systemctl $cmd $u 失败" >&2; fi
  done
}

need_sudo() {
  if [ -z "$(sudo -n systemctl is-active ninfer 2>/dev/null)" ]; then
    echo '错误: 免密 sudo 未生效 (检查 /etc/sudoers.d/ai-mode)' >&2
    exit 1
  fi
}

keep_awake()  { svc stop $AP_TIMERS; }
allow_sleep() { svc start $AP_TIMERS; }

wait_gpu_free() {
  for i in $(seq 1 30); do
    local used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | awk '{s+=$1} END{print s}')
    [ "${used:-0}" -lt 2000 ] && return 0
    sleep 2
  done
  echo '警告: 等待 60s 后显存仍未释放完毕' >&2
}

mode_llm()   { keep_awake; svc stop comfyui vllm; svc stop ninfer; sleep 2; svc start ninfer; }
mode_video() { keep_awake; svc stop vllm ninfer; svc stop comfyui; sleep 2; svc start comfyui; }
mode_vllm()  { keep_awake; svc stop comfyui ninfer; svc stop vllm; wait_gpu_free; svc start vllm; }
mode_off()   { svc stop comfyui ninfer vllm; allow_sleep; }

svc_state() { systemctl is-active "$1" 2>/dev/null; }

show_text() {
  for s in ninfer vllm comfyui; do
    local st=$(systemctl is-active $s 2>/dev/null)
    local line="$s|$st"
    if [ "$st" = active ]; then
      local acc=$(systemctl show -p NRestarts $s 2>/dev/null | cut -d= -f2)
      [ "${acc:-0}" != 0 ] && line="$line|重启${acc}次"
    fi
    echo "$line"
  done | column -t -s'|'
  echo '--- auto-power ---'
  for t in $AP_TIMERS; do
    echo "$t|$(systemctl is-active $t 2>/dev/null)"
  done | column -t -s'|'
  echo '--- GPU ---'
  nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader
  echo '--- endpoints ---'
  curl -s --max-time 3 http://127.0.0.1:8080/health 2>/dev/null && echo ' <- NInfer :8080'
  curl -s --max-time 3 http://127.0.0.1:8188/system_stats >/dev/null 2>&1 && echo 'ComfyUI :8188 在线'
  curl -s --max-time 3 http://127.0.0.1:8000/v1/models >/dev/null 2>&1 && echo 'vLLM :8000 在线'
}

emit_json() {
  local n=$(svc_state ninfer) v=$(svc_state vllm) c=$(svc_state comfyui)
  local ti=$(svc_state auto-power-idle.timer) th=$(svc_state auto-power-hibtest.timer) to=$(svc_state auto-power-off.timer)
  local mode="off"
  [ "$n" = active ] && mode="llm"
  [ "$c" = active ] && mode="video"
  [ "$v" = active ] && mode="vllm"
  local up=$(cut -d' ' -f1 /proc/uptime 2>/dev/null)
  echo -n "{\"mode\":\"$mode\",\"uptime\":\"$up\",\"services\":{\"ninfer\":\"$n\",\"vllm\":\"$v\",\"comfyui\":\"$c\"},\"auto_power\":{\"idle\":\"$ti\",\"hibtest\":\"$th\",\"off\":\"$to\"},\"gpus\":["
  local first=1
  while read -r line; do
    local idx=$(echo "$line" | cut -d, -f1 | tr -d ' ')
    local name=$(echo "$line" | cut -d, -f2 | tr -d ' ')
    local used=$(echo "$line" | cut -d, -f3 | tr -d ' MiB')
    local total=$(echo "$line" | cut -d, -f4 | tr -d ' MiB')
    local util=$(echo "$line" | cut -d, -f5 | tr -d ' %')
    [ $first = 1 ] || echo -n ","
    echo -n "{\"index\":$idx,\"name\":\"$name\",\"mem_used\":$used,\"mem_total\":$total,\"util\":$util}"
    first=0
  done < <(nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader 2>/dev/null)
  echo -n "],\"endpoints\":{\"ninfer\":$(curl -s --max-time 3 http://127.0.0.1:8080/health >/dev/null 2>&1 && echo true || echo false),\"comfyui\":$(curl -s --max-time 3 http://127.0.0.1:8188/system_stats >/dev/null 2>&1 && echo true || echo false),\"vllm\":$(curl -s --max-time 3 http://127.0.0.1:8000/v1/models >/dev/null 2>&1 && echo true || echo false)}}"
}

case "$1" in
  llm)    need_sudo; mode_llm;   echo '已切换到 LLM 模式: NInfer :8080 (Qwen3.8-27B), 已保持唤醒' ;;
  video)  need_sudo; mode_video; echo '已切换到视频模式: ComfyUI :8188 (Wan2.2 5B), 已保持唤醒' ;;
  vllm)   need_sudo; mode_vllm;  echo '已切换到 vLLM 模式: Qwen3-30B-A3B :8000, 已保持唤醒' ;;
  off)    need_sudo; mode_off;   echo '所有 GPU 服务已停止, 自动休眠已恢复' ;;
  status) if [ "$2" = "--json" ]; then emit_json; else show_text; fi ;;
  --json) emit_json ;;
  *)      echo "用法: $0 {llm|video|vllm|off|status|--json}"; exit 1 ;;
esac
