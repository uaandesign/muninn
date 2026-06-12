# Muninn demo 录制脚本 —— 在仓库根目录执行: vhs assets/demo.tape
# 演示数据为 assets/demo-data/ 下的合成会话（脱敏），工具为真实运行。
# 注意：Type 的内容保持纯 ASCII（vhs 键入 emoji/中文会导致字符错位）。

Output assets/demo.gif

Set Shell bash
Set FontSize 15
Set Width 1000
Set Height 720
Set Padding 14
Set TypingSpeed 30ms
Set Theme "Dracula"

Hide
Type "export CLAUDE_PROJECTS_DIR=assets/demo-data PS1='$ ' && clear"
Enter
Show

Type "bash skills/muninn/tools/mine-sessions.sh ai-radar 30 110"
Sleep 500ms
Enter
Sleep 5500ms

Hide
Type "clear"
Enter
Show

Type "cat assets/demo-runestone.txt"
Sleep 500ms
Enter
Sleep 5s
