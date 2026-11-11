# Статический аудит текстур (не игровая проверка)

Сканируются Code/** и корневые .lua/.xml; комментарии исключаются.
Ссылки = извлечённые статические упоминания; ThemeUtil раскрывается в две темы.
Недостающий путь = нет файла любого поддерживаемого расширения без учёта регистра.
Отсутствующие в сборке исходники перечислены независимо от ссылок.
Неупомянутые TGA не равнозначны неиспользуемым: динамические выражения не исполняются.
Числовые fileID/SetTexture могут быть цветовыми аргументами; требуется ручная оценка.
Кандидаты похожих имён — эвристика, не доказанные замены.

- scanned_files: **109**
- reference_occurrences: **193**
- unique_paths: **133**
- broken_unique_paths: **0**
- broken_occurrences: **0**
- source_assets: **273**
- build_assets: **273**
- sources_missing_in_build: **0**
- unmentioned_build_assets: **142**
- case_mismatches: **0**
- unresolved_expressions: **195**
- numeric_expressions: **0**
- external_literals: **0**
- dynamic_prefixes: **2**

## Битые пути по темам
Нет.

## Динамические префиксы (конкатенация, не файлы)

### Icons (1)
- `Icons/NPCType-`

### ui_majorfactions_ (1)
- `ui_majorfactions_`

## Исходники без файла в сборке
Нет.

## Ассеты сборки без статических упоминаний

### BasicShapes (1)
- `BasicShapes/Mask-AllBlack.blp`

### Book (1)
- `Book/ScreenDarken.blp`

### Icons (31)
- `Icons/AskDirection.blp`
- `Icons/AvailableCampaignQuest.blp`
- `Icons/AvailableImportantQuest.blp`
- `Icons/AvailableLegendaryQuest.blp`
- `Icons/AvailableMetaQuest.blp`
- `Icons/AvailableQuest.blp`
- `Icons/Coin-Copper.blp`
- `Icons/Coin-Silver.blp`
- `Icons/CompleteCampaignQuest.blp`
- `Icons/CompleteDailyQuest.blp`
- `Icons/CompleteImportantQuest.blp`
- `Icons/CompleteLegendaryQuest.blp`
- `Icons/CompleteQuest.blp`
- `Icons/DailyQuest.blp`
- `Icons/Gossip-Blue.blp`
- `Icons/Incomplete-Brown.blp`
- `Icons/IncompleteCampaignQuest.blp`
- `Icons/IncompleteImportantQuest.blp`
- `Icons/IncompleteLegendaryQuest.blp`
- `Icons/IncompleteMetaQuest.blp`
- `Icons/Logo.blp`
- `Icons/QuestTag-Dungeon.blp`
- `Icons/QuestTag-Raid.blp`
- `Icons/RepeatableQuest.blp`
- `Icons/RepeatableScheduler.blp`
- `Icons/UpgradeArrow.blp`
- `Icons/WeeklyQuest.blp`
- `Icons/XP-Green.blp`
- `Icons/conquest.blp`
- `Icons/honor.blp`
- `Icons/trophy_of_strife.blp`

### Keys (24)
- `Keys/CONSOLE-MENU.blp`
- `Keys/DISABLED.blp`
- `Keys/ERROR.blp`
- `Keys/PC-F1.blp`
- `Keys/PC-INVALID.blp`
- `Keys/PC-R.blp`
- `Keys/PC-SPACE.blp`
- `Keys/PC-TAB.blp`
- `Keys/PS-LT.blp`
- `Keys/PS-PAD1.blp`
- `Keys/PS-PAD2.blp`
- `Keys/PS-PAD3.blp`
- `Keys/PS-PAD4.blp`
- `Keys/SPACE.blp`
- `Keys/SWITCH-LT.blp`
- `Keys/SWITCH-PAD1.blp`
- `Keys/SWITCH-PAD2.blp`
- `Keys/SWITCH-PAD3.blp`
- `Keys/SWITCH-PAD4.blp`
- `Keys/XBOX-LT.blp`
- `Keys/XBOX-PAD1.blp`
- `Keys/XBOX-PAD2.blp`
- `Keys/XBOX-PAD3.blp`
- `Keys/XBOX-PAD4.blp`

### ParchmentDecor (14)
- `ParchmentDecor/Alliance.blp`
- `ParchmentDecor/Dragonflight-Bronze.blp`
- `ParchmentDecor/Dragonflight-Green.blp`
- `ParchmentDecor/Dragonflight-Red.blp`
- `ParchmentDecor/Dragonflight.blp`
- `ParchmentDecor/Horde.blp`
- `ParchmentDecor/MID-DarkHeart.blp`
- `ParchmentDecor/TWW-Azeroth.blp`
- `ParchmentDecor/TWW-Candle.blp`
- `ParchmentDecor/TWW-Fist.blp`
- `ParchmentDecor/TWW-Flame.blp`
- `ParchmentDecor/TWW-Rocket.blp`
- `ParchmentDecor/TWW-Storm.blp`
- `ParchmentDecor/TWW-Web.blp`

### PreviewPicture (15)
- `PreviewPicture/AutoQuestPopup.blp`
- `PreviewPicture/BookUI.blp`
- `PreviewPicture/CameraChangeFov.blp`
- `PreviewPicture/CopyTextButton.blp`
- `PreviewPicture/HideOutlineSparkles.blp`
- `PreviewPicture/MarkHighestSellPrice.blp`
- `PreviewPicture/NameplateDialogEnabled.blp`
- `PreviewPicture/QuestAutoComplete.blp`
- `PreviewPicture/QuestDifficultyStyle.blp`
- `PreviewPicture/QuestItemDisplay.blp`
- `PreviewPicture/QuestTypeText.blp`
- `PreviewPicture/QuickSlotQuestReward.blp`
- `PreviewPicture/SimplifyCurrencyReward.blp`
- `PreviewPicture/TTSButton.blp`
- `PreviewPicture/Theme.blp`

### Theme_Brown (25)
- `Theme_Brown/HotkeyBackground-LB.blp`
- `Theme_Brown/HotkeyBackground-RB.blp`
- `Theme_Brown/ItemBorder.blp`
- `Theme_Brown/OptionBackground-Blue.blp`
- `Theme_Brown/OptionBackground-Common.blp`
- `Theme_Brown/OptionBackground-Grey.blp`
- `Theme_Brown/OptionBackground-Hollow.blp`
- `Theme_Brown/PS-PAD1.blp`
- `Theme_Brown/PS-PAD2.blp`
- `Theme_Brown/PS-PAD3.blp`
- `Theme_Brown/PS-PAD4.blp`
- `Theme_Brown/RewardChoice-ItemBorder.blp`
- `Theme_Brown/RewardChoice-Pending.blp`
- `Theme_Brown/SWITCH-PAD1.blp`
- `Theme_Brown/SWITCH-PAD2.blp`
- `Theme_Brown/SWITCH-PAD3.blp`
- `Theme_Brown/SWITCH-PAD4.blp`
- `Theme_Brown/Settings-BackgroundShadow.blp`
- `Theme_Brown/Settings-Move.blp`
- `Theme_Brown/Settings-Reset.blp`
- `Theme_Brown/TooltipBackground.blp`
- `Theme_Brown/XBOX-PAD1.blp`
- `Theme_Brown/XBOX-PAD2.blp`
- `Theme_Brown/XBOX-PAD3.blp`
- `Theme_Brown/XBOX-PAD4.blp`

### Theme_Dark (25)
- `Theme_Dark/HotkeyBackground-LB.blp`
- `Theme_Dark/HotkeyBackground-RB.blp`
- `Theme_Dark/ItemBorder.blp`
- `Theme_Dark/OptionBackground-Blue.blp`
- `Theme_Dark/OptionBackground-Common.blp`
- `Theme_Dark/OptionBackground-Grey.blp`
- `Theme_Dark/OptionBackground-Hollow.blp`
- `Theme_Dark/PS-PAD1.blp`
- `Theme_Dark/PS-PAD2.blp`
- `Theme_Dark/PS-PAD3.blp`
- `Theme_Dark/PS-PAD4.blp`
- `Theme_Dark/RewardChoice-ItemBorder.blp`
- `Theme_Dark/RewardChoice-Pending.blp`
- `Theme_Dark/SWITCH-PAD1.blp`
- `Theme_Dark/SWITCH-PAD2.blp`
- `Theme_Dark/SWITCH-PAD3.blp`
- `Theme_Dark/SWITCH-PAD4.blp`
- `Theme_Dark/Settings-BackgroundShadow.blp`
- `Theme_Dark/Settings-Move.blp`
- `Theme_Dark/Settings-Reset.blp`
- `Theme_Dark/TooltipBackground.blp`
- `Theme_Dark/XBOX-PAD1.blp`
- `Theme_Dark/XBOX-PAD2.blp`
- `Theme_Dark/XBOX-PAD3.blp`
- `Theme_Dark/XBOX-PAD4.blp`

### Theme_Shared (6)
- `Theme_Shared/BrushFrame-Mask-BottomRight.blp`
- `Theme_Shared/BrushFrame-Mask-TopLeft.blp`
- `Theme_Shared/Mask-HeartFill.blp`
- `Theme_Shared/Mask-SettingsDecor.blp`
- `Theme_Shared/StatusBar-FillShort-Green.blp`
- `Theme_Shared/StatusBar-ValueBlock-Green.blp`

## Регистр
```json
[]
```

## Похожие имена / суффиксы
```json
{}
```

Полные ссылки, места вызовов, динамические выражения и хеши входных файлов: texture_report.json.
