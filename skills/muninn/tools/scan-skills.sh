#!/usr/bin/env bash
# Muninn 巡视：盘点本机 Skill 库，输出培养优先级榜（使用频率 × 等级缺口）。
# 只读操作——不修改任何 skill 或会话文件。
#
# 用法: scan-skills.sh [天数=30]
# 扫描范围: ~/.claude/skills/ 与 ./.claude/skills/（如存在）
set -euo pipefail

DAYS="${1:-30}"
PROJECTS="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
MUNINN_HOME="${MUNINN_HOME:-$HOME/.claude/muninn}"

dirs=()
[ -d "$HOME/.claude/skills" ] && dirs+=("$HOME/.claude/skills")
[ -d ".claude/skills" ] && dirs+=(".claude/skills")

if [ "${#dirs[@]}" -eq 0 ]; then
  echo "未找到 skill 目录（~/.claude/skills 或 ./.claude/skills）" >&2
  exit 1
fi

echo "## Muninn 巡视报告（窗口 ${DAYS} 天）"
echo
echo "| Skill | 近${DAYS}天会话提及 | 等级 | 冻结 | 考题(绿/总) | 位置 |"
echo "|---|---:|---|---|---|---|"

rows=""
for base in "${dirs[@]}"; do
  for d in "$base"/*/; do
    [ -f "$d/SKILL.md" ] || continue
    name=$(basename "$d")

    # 使用频率：近 N 天提及该名字的会话数（每会话至多计 1）。
    # 排除 skill_listing 噪音行——每个会话开头都会列出全部已装 skill 名，不算使用。
    usage=0
    if [ -d "$PROJECTS" ]; then
      while IFS= read -r jf; do
        if grep -- "$name" "$jf" 2>/dev/null | grep -v 'skill_listing' | grep -qm1 .; then
          usage=$((usage + 1))
        fi
      done < <(find "$PROJECTS" -name '*.jsonl' -mtime "-$DAYS" -size +0c 2>/dev/null)
    fi

    # 等级与冻结状态：读 saga（没有就是未定级）
    saga="$MUNINN_HOME/$name/saga.md"
    level="未定级"
    frozen="-"
    if [ -f "$saga" ]; then
      level=$(grep -m1 '当前等级' "$saga" | sed 's/.*[:：]//' | tr -d ' ' || true)
      [ -n "$level" ] || level="未定级"
      if grep -m1 '冻结状态' "$saga" | grep -q '⚠️'; then frozen="⚠️"; fi
    fi

    # 考题统计
    evals="$MUNINN_HOME/$name/evals.md"
    eq="0/0"
    if [ -f "$evals" ]; then
      total=$(grep -c '^## 考题' "$evals" 2>/dev/null || true)
      green=$(grep -c '状态：🟢' "$evals" 2>/dev/null || true)
      eq="${green:-0}/${total:-0}"
    fi

    rows="${rows}${usage}|${name}|${level}|${frozen}|${eq}|${d}\n"
  done
done

# 按使用频率倒序输出
printf '%b' "$rows" | sort -t'|' -k1,1 -rn | while IFS='|' read -r usage name level frozen eq loc; do
  [ -n "$name" ] || continue
  echo "| $name | $usage | $level | $frozen | $eq | $loc |"
done

echo
echo "> 培养优先级 = 用得多 × 等级低（或未定级）× 有冻结标记。"
echo "> 提及数是粗信号（按名字 grep，可能含同名误伤），定级请用 mine-sessions.sh 精查。"
