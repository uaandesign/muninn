#!/usr/bin/env bash
# Muninn 放飞：在本地会话记录（transcript）里初筛某个 skill 的实战痕迹。
# 只读操作——本脚本绝不修改、移动、删除任何会话文件。
#
# 用法: mine-sessions.sh <skill-name> [天数=30] [片段截断字符数=200] [别名/触发词,逗号分隔]
# 例:   mine-sessions.sh feilian-ux-zh 60 130 "飞连,Q0,开工确认,page-samples"
# 输出: 按会话分组的初筛报告（候选文件、命中数、命中词、采样片段），供后续精读定位。
#
# ⚠️ 为什么要传别名：真实使用里 skill 常被叫别名（feilian-ux-zh 被叫"飞连"），
#    只搜精确名会系统性"空手而归"。先从 skill 的触发词/常见叫法里挑几个当别名一起搜。
# 注意: 输出片段可能包含隐私，仅供本地定级使用；写入公开产物前必须脱敏。
# 不用 set -e：head 提前关管道会让上游大 grep 收到 SIGPIPE(141)，
# 对超大 transcript（十几 MB、上千命中）尤其常见——报告脚本不该因断管道而死。
set -uo pipefail

# 截断中文需要 UTF-8 locale：C locale 下 bash 子串按字节截断，会把多字节字符截成乱码
LC_ALL="$(locale -a 2>/dev/null | grep -im1 -E '^(en_US|C)\.UTF-?8$' || echo C)"
export LC_ALL

SKILL="${1:?用法: mine-sessions.sh <skill-name> [天数] [截断字符数] [别名,逗号分隔]}"
DAYS="${2:-30}"
SNIP="${3:-200}"
ALIASES="${4:-}"
ROOT="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
MAX_SESSIONS=10
MAX_LINES_PER_KIND=5

if [ ! -d "$ROOT" ]; then
  echo "未找到会话目录: $ROOT（可用环境变量 CLAUDE_PROJECTS_DIR 指定）" >&2
  exit 1
fi

# 搜索词 = 精确名 + 别名（grep -E 的正则交替）。别名按逗号分隔、去首尾空格。
PATTERN="$SKILL"
if [ -n "$ALIASES" ]; then
  CLEAN="$(printf '%s' "$ALIASES" | sed 's/^ *//; s/ *$//; s/ *, */|/g')"
  [ -n "$CLEAN" ] && PATTERN="$SKILL|$CLEAN"
fi

echo "## Muninn 放飞报告"
echo "- skill: $SKILL"
[ -n "$ALIASES" ] && echo "- 别名/触发词: $ALIASES"
echo "- 搜索式: $PATTERN"
echo "- 窗口: 最近 ${DAYS} 天"
echo "- 巢址: $ROOT"
echo

# 噪音过滤：每个会话开头的 skill_listing 附件会列出全部已装 skill 名，
# 那不是使用痕迹，统计与采样时一律排除。
NOISE='skill_listing'

found=0
skipped=0
alias_only=0
while IFS= read -r f; do
  hits=$(grep -E -- "$PATTERN" "$f" 2>/dev/null | grep -cv "$NOISE" || true)
  [ "${hits:-0}" -gt 0 ] || continue
  found=$((found + 1))
  if [ "$found" -gt "$MAX_SESSIONS" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  mtime=$(date -r "$f" "+%Y-%m-%d %H:%M" 2>/dev/null || stat -c '%y' "$f" 2>/dev/null | cut -d. -f1)
  proj=$(basename "$(dirname "$f")")

  # 这个会话实际命中了哪些词（去噪后），帮判断是精确名命中还是别名命中
  terms=$(grep -v "$NOISE" "$f" 2>/dev/null | grep -oE -- "$PATTERN" | sort -u | paste -sd' ' - || true)
  # 是否只靠别名命中（精确名一次没出现）——这类最容易被旧版漏掉
  name_hits=$(grep -- "$SKILL" "$f" 2>/dev/null | grep -cv "$NOISE" || true)
  flag=""
  if [ "${name_hits:-0}" -eq 0 ]; then flag=" ⚠️仅别名命中"; alias_only=$((alias_only + 1)); fi

  echo "### 会话 ${found}${flag}"
  echo "- 文件: $f"
  echo "- 项目: $proj | 最后活动: $mtime | 命中行: $hits"
  echo "- 命中词: ${terms:-（无）}"

  invoke=$(grep -c -E "\"skill\"[[:space:]]*:[[:space:]]*\"$SKILL\"|<command-name>/?$SKILL" "$f" 2>/dev/null || true)
  echo "- 工具/命令调用痕迹: ${invoke:-0} 处"

  echo "- 采样片段（已滤除 skill_listing 噪音；每行截断至 ${SNIP} 字符，最多 ${MAX_LINES_PER_KIND} 行）:"
  # 按字符截断（bash 参数展开在 UTF-8 locale 下按字符计数），避免 cut -c 截断多字节中文产生乱码
  grep -nE -- "$PATTERN" "$f" | grep -v "$NOISE" | head -"$MAX_LINES_PER_KIND" | while IFS= read -r line; do
    printf '    %s\n' "${line:0:$SNIP}"
  done
  echo
done < <(find "$ROOT" -name '*.jsonl' -mtime "-$DAYS" -size +0c 2>/dev/null | sort -r)

if [ "$found" -eq 0 ]; then
  echo "（最近 ${DAYS} 天没找到「$SKILL」的痕迹。空手而归也是证据，但先排除两种漏网："
  echo "  ① 别名：真实使用常用别名（如\"飞连\"），用第 4 个参数补搜——"
  echo "     mine-sessions.sh $SKILL $DAYS $SNIP \"别名1,别名2\""
  echo "  ② 窗口：扩大天数重飞——mine-sessions.sh $SKILL 90）"
elif [ "$alias_only" -gt 0 ]; then
  echo "（其中 ${alias_only} 个会话\"仅别名命中\"——精确名一次没出现。"
  echo "  这正是只搜精确名会漏掉的真实使用，定级时按命中词判断是不是真用过。）"
fi
if [ "$skipped" -gt 0 ]; then
  echo "（按时间倒序仅展示前 ${MAX_SESSIONS} 个会话，另有 ${skipped} 个命中会话未展开——定级时写明采样规则）"
fi

echo
echo "> 下一步：用 Read 工具按上面的行号附近精读可疑会话，按 evidence-guide.md 辨认五类证据。"
echo "> 隐私提醒：以上片段仅供本地定级；进任何公开产物前必须脱敏。"
