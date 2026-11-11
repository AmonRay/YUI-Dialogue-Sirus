# Статический аудит текстур (не игровая проверка)

Непроверенный в игре черновик для ведущего. Код приложения и ассеты не менялись.
Сканируются Code/**, корневые .lua/.xml и токены клавиш Locales/*.lua; комментарии исключаются.
## Программные результаты
Единица счёта: файл, позиция и разрешённый путь; две темы дают два упоминания.
Табличные декор, клавиши, NPC-типы и встроенные |T-строки раскрываются отдельно.
Ссылки = извлечённые статические упоминания; ThemeUtil раскрывается в две темы.
Недостающий путь = нет файла любого поддерживаемого расширения без учёта регистра.
Отсутствующие в сборке исходники перечислены независимо от ссылок.
Неупомянутые TGA не равнозначны неиспользуемым: динамические выражения не исполняются.
Числовые fileID/SetTexture могут быть цветовыми аргументами; требуется ручная оценка.
Кандидаты похожих имён — эвристика, не доказанные замены.

- scanned_files: **121**
- reference_occurrences: **498**
- unique_paths: **230**
- broken_unique_paths: **0**
- broken_occurrences: **0**
- source_assets: **273**
- build_assets: **273**
- sources_missing_in_build: **0**
- unmentioned_build_assets: **43**
- case_mismatches: **0**
- unresolved_expressions: **197**
- numeric_expressions: **0**
- external_literals: **0**
- dynamic_prefixes: **0**

## Битые пути по темам
Нет.

## Динамические префиксы (конкатенация, не файлы)
Нет.

## Исходники без файла в сборке
Нет.

## Ассеты сборки без статических упоминаний

### BasicShapes (1)
- `BasicShapes/Mask-AllBlack.blp`

### Book (1)
- `Book/ScreenDarken.blp`

### Icons (9)
- `Icons/Coin-Copper.blp`
- `Icons/Coin-Silver.blp`
- `Icons/CompleteDailyQuest.blp`
- `Icons/Gossip-Blue.blp`
- `Icons/Incomplete-Brown.blp`
- `Icons/QuestTag-Dungeon.blp`
- `Icons/QuestTag-Raid.blp`
- `Icons/UpgradeArrow.blp`
- `Icons/XP-Green.blp`

### Keys (3)
- `Keys/PS-PAD4.blp`
- `Keys/SWITCH-PAD4.blp`
- `Keys/XBOX-PAD4.blp`

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

### Theme_Brown (4)
- `Theme_Brown/Settings-BackgroundShadow.blp`
- `Theme_Brown/Settings-Move.blp`
- `Theme_Brown/Settings-Reset.blp`
- `Theme_Brown/TooltipBackground.blp`

### Theme_Dark (4)
- `Theme_Dark/Settings-BackgroundShadow.blp`
- `Theme_Dark/Settings-Move.blp`
- `Theme_Dark/Settings-Reset.blp`
- `Theme_Dark/TooltipBackground.blp`

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

## Покрытие извлечения (программные числа)
- book-texturekit: **2**
- constant-concat: **26**
- decor-table: **18**
- hotkey-table: **39**
- inline-texture: **3**
- literal-art: **17**
- locale-key: **205**
- npc-type-table: **1**
- redirect-texturekit: **4**
- shared-helper: **3**
- theme-concat: **28**
- theme-helper: **87**
- theme-index-table: **11**
- theme-table: **24**
- theme-variable: **12**
- variable-concat: **18**

## Ручные выводы и ограничения (не дополнительные числа)
- API.lua:547–567 собирает `Icons/NPCType-AskDirection`; `Icons/AskDirection` — другое имя. Это подтверждённая причина битого пути, а не рекомендация автоматически переименовать ассет.
- В текущем коде идентификатор bgName отсутствует; варианты prefix..variable и прямые переменные helper извлекаются по конечным строковым присваиваниям без исполнения Lua.
- unresolved — список выражений API, а не список отсутствующих файлов: в нём остаются и вложенные helper-вызовы, уже учтённые отдельно.
- Полный список отсутствующих файлов относится только к извлечённым конечным путям. Произвольные данные игры и внешние строки статически не ограничены.
- Ведущему: повторить скан после параллельных правок; проверить в Sirus декор, клавиши, две темы и сообщения DUI-TEX. Сборка и игра здесь не запускались.
