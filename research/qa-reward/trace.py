# -*- coding: utf-8 -*-
"""Статическая трассировка цепочки данных требования (QUEST_PROGRESS -> предметная кнопка).

Обход по grep: для каждого звена цепочки ищем конкретные вызовы в исходниках аддона
и печатаем упорядоченный список "файл:строка -> вызов". Код не изменяется.

Запуск:  python research/qa-reward/trace.py
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# (метка звена, файл, регулярное выражение)
STEPS = [
    ("1. Событие/колбэк показа окна",
     r"Code/Dialogue/DialogueUI.lua",
     r'QUEST_PROGRESS|PlayerInteraction\.ShowUI|HandleQuestProgress'),

    ("2. GossipData: автозавершение/источники данных",
     r"Code/GossipData/GossipDataProvider.lua",
     r"OnInteractWithNPC|AddDataSource|ShouldAutoCompleteQuest"),

    ("3. InteractionManager (помечен как Unused в исходнике)",
     r"Code/Utility/InteractionManager.lua",
     r"DUI_GetInteractionType|IsInteractingWithNpcOfType"),

    ("4. DialogueUI: подготовка перед Show (HandleQuestProgress)",
     r"Code/Dialogue/DialogueUI.lua",
     r"GetNumQuestItems|IsQuestItemHidden|SetRequiredItem|AcquireAndSetSubHeader"
     r"|L\[\"Requirements\"\]|FormatRewards"),

    ("5. DialogueUI: пул кнопок и раскладка сетки",
     r"Code/Dialogue/DialogueUI.lua",
     r"itemButtonPool:Acquire|SetBaseGridSize|SetWidthByGridTaken|SetButtonWidth"
     r"|SetPoint.*grid|GetActualGridTaken"),

    ("6. Виджет: SetItem / данные игры",
     r"Code/Dialogue/UITemplates.lua",
     r"function DUIDialogItemButtonMixin:SetItem\b|GetQuestItemInfo\(|GetQuestItemLink\("
     r"|Icon:SetTexture|SetItemName|SetItemCount"),

    ("7. Виджет: счётчик 99/2048",
     r"Code/Dialogue/UITemplates.lua",
     r"FORMAT_COUNT_OWNED_REQUIRED|GetItemCount\(|Count:SetText|Count:SetPoint|Count:SetJustifyH"),

    ("8. Виджет: геометрия иконки (UpdatePixel / шаблон)",
     r"Code/Dialogue/UITemplates.lua|Code/Dialogue/DialogueUI.xml",
     r"UpdatePixel|AreaDefinitionItemBorder|Icon:SetPoint|Icon:ClearAllPoints"
     r"|GetPixelForScale|AddPixelPerfectObject"),

    ("9. Виджет: фон/рамка кнопки (ThemeUtil-резолв)",
     r"Code/Dialogue/UITemplates.lua",
     r"SetBackgroundTexture|ItemButtonBackground|ItemBorder|Background:SetTexture"
     r"|ItemBorder:SetTexture|ThemeUtil:GetTextureFile"),

    ("10. Резолвер тем/размеры",
     r"Code/Utility/ThemeUtil.lua",
     r"function ThemeUtil:FindTextureFile|function ThemeUtil:GetTextureFile|MissingTexture"),

    ("11. Compat 3.3.5a: данные квеста и иконки",
     r"Code/Compat/Compat_335.lua",
     r"GetQuestItemInfo|GetNumQuestItems|IsQuestItemHidden|DUI_ICON|SetTexture\(number\)"),

    ("12. Тултип награды (RewardTooltipCode)",
     r"Code/Dialogue/RewardTooltipCode.lua",
     r"CustomTooltip_OnEnter|SetQuestItem|IsQuestRequiredItem|GetItemCount\(|self\.Icon"),
]


def grep(rel_path, pattern):
    path = os.path.join(ROOT, rel_path)  # Windows принимает прямые слэши; не трогаем экранирование "\."
    hits = []
    rx = re.compile(pattern)
    try:
        with io.open(path, "r", encoding="utf-8", errors="replace") as f:
            for n, line in enumerate(f, 1):
                if rx.search(line):
                    hits.append((n, line.rstrip()))
    except OSError as e:
        hits.append((0, "!! файл не прочитан: %s" % e))
    return hits


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    out = []
    for label, files, pattern in STEPS:
        out.append("")
        out.append("== " + label + "  (шаблон: %s)" % pattern)
        for rel in files.split("|"):
            hits = grep(rel, pattern)
            if not hits:
                out.append("   (нет совпадений в %s)" % rel)
            for n, line in hits:
                line = line.strip()
                if len(line) > 150:
                    line = line[:147] + "..."
                out.append("   %s:%d -> %s" % (rel, n, line))
    text = "\n".join(out)
    print(text)
    # копия результата рядом со скриптом
    dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), "trace_output.txt")
    with io.open(dst, "w", encoding="utf-8") as f:
        f.write(text + "\n")
    print("\n[сохранено] " + os.path.relpath(dst, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
