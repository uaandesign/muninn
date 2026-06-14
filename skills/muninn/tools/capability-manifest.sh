#!/usr/bin/env bash
# Muninn 能力盘点：扫描一个 skill 目录，盘出"它现在能干什么"的清单初稿。
# 治"删功能"：动手前冻结这份清单，改完后逐项确认仍在——某项消失即回刀，
# 哪怕没有任何考题覆盖它（考题只从失败长出，好好工作的功能没有考题保护）。
#
# 只读操作——不修改目标 skill。
# 用法: capability-manifest.sh <skill目录> [输出文件]
#   不给输出文件时打印到 stdout；给了就写文件（供冻结进 saga 后人工补全）。
set -euo pipefail
export LC_ALL="$(locale -a 2>/dev/null | grep -im1 -E '^(en_US|C)\.UTF-?8$' || echo C)"

DIR="${1:?用法: capability-manifest.sh <skill目录> [输出文件]}"
OUT="${2:-}"
SKILL_MD="$DIR/SKILL.md"
[ -f "$SKILL_MD" ] || { echo "未找到 $SKILL_MD" >&2; exit 1; }

emit() { if [ -n "$OUT" ]; then echo "$@" >> "$OUT"; else echo "$@"; fi; }
[ -n "$OUT" ] && : > "$OUT"

name=$(grep -m1 '^name:' "$SKILL_MD" | sed 's/name:[[:space:]]*//' | tr -d '\r')

emit "# 能力清单（Capability Manifest）· ${name:-$(basename "$DIR")}"
emit ""
emit "> 盘点时间：$(date '+%Y-%m-%d %H:%M')｜来源：$DIR"
emit "> 这是**自动初稿**，必须人工补全：删掉误报、补上脚本未暴露的隐性能力，"
emit "> 给每项写明【怎么确认它还活着】（代码位置 + 一条能在产物里看到它的检查）。"
emit "> 冻结进 saga 后，每轮试炼收尾逐项核对；某项消失 = 回刀，与考题无关。"
emit ""

emit "## A. 声明的能力（来自 SKILL.md 章节标题）"
emit ""
grep -nE '^#{2,3} ' "$SKILL_MD" | sed -E 's/^([0-9]+):#{2,3} /- [ ] /; s/$//' | while IFS= read -r l; do emit "$l"; done
emit ""

emit "## B. 产物字段 / 渲染点（grep 命中，可能是用户可见的能力）"
emit ""
# 抓常见的"产物字段"信号：img_key / cover / card / payload / render / 输出字段名
fields=$(grep -rhoE '[a-zA-Z_]*(img_key|cover|banner|payload|card|render|attachment|export|webhook|archive)[a-zA-Z_]*' "$DIR" \
  --include='*.md' --include='*.py' --include='*.js' --include='*.ts' --include='*.sh' 2>/dev/null \
  | sort -u | head -40 || true)
if [ -n "$fields" ]; then
  while IFS= read -r f; do emit "- [ ] \`$f\`"; done <<< "$fields"
else
  emit "（无明显产物字段信号）"
fi
emit ""

emit "## C. 脚本与外部依赖（每个都是一类能力，删了就掉功能）"
emit ""
find "$DIR" -type f \( -name '*.py' -o -name '*.sh' -o -name '*.js' -o -name '*.ts' \) -not -path '*/.git/*' 2>/dev/null \
  | sort | while IFS= read -r s; do
    rel="${s#$DIR/}"
    # 第一行注释或 docstring 当一句话说明
    desc=$(grep -m1 -E '^[[:space:]]*#[^!]|^[[:space:]]*"""|^//' "$s" 2>/dev/null | sed -E 's/^[[:space:]]*(#|"""|\/\/)[[:space:]]*//' | cut -c1-80)
    emit "- [ ] \`$rel\` — ${desc:-（补一句它干什么）}"
  done
emit ""

emit "## D. 外部命令 / API 调用（消失=对外能力消失）"
emit ""
calls=$(grep -rhoE '(lark-cli|curl|gh |/open-apis/[a-z/_.]+|requests\.(get|post)|fetch\()' "$DIR" \
  --include='*.md' --include='*.py' --include='*.js' --include='*.ts' --include='*.sh' 2>/dev/null \
  | sort -u | head -30 || true)
if [ -n "$calls" ]; then
  while IFS= read -r c; do emit "- [ ] \`$c\`"; done <<< "$calls"
else
  emit "（未检出外部调用）"
fi
emit ""

emit "## E. 人工补充：自动扫不到的隐性能力"
emit ""
emit "- [ ] （例：宁缺毋滥的配图——\"有合格图才配\"是能力，\"全空\"是退化不是正常）"
emit "- [ ] （例：某条规则带来的输出质量保证）"
emit ""
emit "---"
emit "## 核对记录（每轮试炼收尾追加）"
emit ""
emit "| 日期 | 试炼 | 全项仍在? | 消失项 | 处置 |"
emit "|---|---|---|---|---|"

[ -n "$OUT" ] && echo "已写入 $OUT（记得人工补全 E 段并为每项写'怎么确认还活着'）"
