"""Read-only structural checks for the quest text path; not a Sirus client test."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def source(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")

api = source("API.lua")
ui = source("Code/Dialogue/DialogueUI.lua")
compat = source("Code/Compat/Compat_335.lua")
fonts = source("Fonts.xml")

def block(text, start, end):
    return text[text.index(start):text.index(end, text.index(start))]

layout = block(ui, "local function LayoutParagraphText(", "function DUIDialogBaseMixin:InsertText(")
normal = block(ui, "function DUIDialogBaseMixin:FormatParagraph(", "function DUIDialogBaseMixin:FormatDualParagraph(")
dual = block(ui, "function DUIDialogBaseMixin:FormatDualParagraph(", "local function ConcatenateNPCName(")
flow = block(ui, "function DUIDialogBaseMixin:FormatQuestText(", "function DUIDialogBaseMixin:HandleQuestComplete(")
release = block(ui, "local function RemoveFontString(", "self.fontStringPool =")
detail = block(ui, "function DUIDialogBaseMixin:HandleQuestDetail(", "function DUIDialogBaseMixin:HandleQuestAccepted(")
complete = block(ui, "function DUIDialogBaseMixin:HandleQuestComplete(", "function DUIDialogBaseMixin:HandleQuestGreeting(")
progress = block(ui, "function DUIDialogBaseMixin:HandleQuestProgress(", "function DUIDialogBaseMixin:IsRewardChosen(")
checks = {
    "API maps Detail/Progress/Complete and returns unshortened nonempty text":
        all(s in api for s in ("Detail = GetDetailText", "Progress = GetProgressText", "Complete = GetRewardText", "return text")),
    "SplitParagraph separates control chars without ellipsis insertion":
        'gmatch(text, "[%C]+")' in api and "..." not in block(api, "local function SplitParagraph(", "API.SplitParagraph ="),
    "ordinary and bilingual paragraphs share measured layout":
        "LayoutParagraphText(self, fs, offsetY, paragraphText)" in normal and "LayoutParagraphText(self, fs, offsetY, para[i])" in dual,
    "layout sets width, clears height, measures after text, allocates measured height":
        all(s in layout for s in ("fs:SetWidth(", "fs:SetHeight(0)", "fs:SetText(text)", "fs:GetStringHeight()", "fs:SetHeight(height)", "return Round(offsetY + height)")) and layout.index("fs:SetText(text)") < layout.index("fs:GetStringHeight()") < layout.index("fs:SetHeight(height)"),
    "pool resets text/anchors and prior dimensions":
        all(s in release for s in ("fontString:SetText(nil)", "fontString:ClearAllPoints()", "fontString:SetWidth(0)", "fontString:SetHeight(0)")),
    "both presentation branches feed paragraph formatter":
        "self:FormatParagraph(offsetY, text" in flow and "self:FormatDualParagraph(offsetY, text, text1)" in flow,
    "Detail and Complete feed formatted offset into rewards and scroll":
        all("self:FormatQuestText(offsetY" in part and "self:FormatRewards(offsetY, rewardList)" in part and "self:SetScrollRange(offsetY)" in part for part in (detail, complete)),
    "Progress feeds formatted offset into required items and scroll":
        "self:FormatQuestText(offsetY" in progress and "self:FormatRewards(offsetY, itemList)" in progress and "self:SetScrollRange(offsetY)" in progress,
    "paragraph fonts have no maxLines limit":
        all("maxLines" not in block(fonts, f'<Font name="{name}"', "</Font>") for name in ("DUIFont_Quest_Paragraph", "DUIFont_Quest_MultiLanguage")),
    "compat does NOT implement GetStringHeight (client must supply it)":
        "GetStringHeight" not in compat,
}
for title, ok in checks.items():
    print(f"{'PASS' if ok else 'FAIL'}: {title}")
print("UNVERIFIED: Sirus FontString:GetStringHeight exists, measures wrapped lines after SetHeight(0), and paints final glyphs")
raise SystemExit(0 if all(checks.values()) else 1)
