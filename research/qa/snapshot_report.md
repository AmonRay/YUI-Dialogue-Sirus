# Независимый статический аудит текущего снимка

Начало: 2026-11-11T20:59:59.994140+03:00
Конец: 2026-11-11T21:00:02.459175+03:00

Это непроверенная в игре передача ведущему. Код, ресурсы, сборка и внешние папки не изменялись.
Снимок не атомарный: параллельные правки могли произойти во время чтения; хеши прочитанных файлов сохранены.
Проверены заголовки BLP2/TGA, границы mip-уровней, размеры, объявленная альфа; для BGRA/TGA также диапазон альфы.
BLP1 не считается автоматически несовместимым: требует отдельного анализа. RLE TGA — риск, не доказанный отказ.
Другие форматы помечаются несовместимыми по консервативному контракту BLP/TGA.
Размеры manifest исходные; отличие от размера после масштабирования само по себе не дефект.
Хеш-сравнение выполняется для Art, Code, корневых TOC/Lua/XML; Fonts/Sound и служебные папки не включены.
Ссылки извлекаются эвристически; динамические выражения и сторонние Interface пути не считаются доказанно исправными.
ThemeUtil раскрывается в Brown/Dark с Shared fallback по manifest; нетематические пути не переносятся.

## Доступность
- source: `D:\!sirus_addons\DF\YUI-Dialogue-Sirus` — доступен
- build: `D:\!sirus_addons\DF\YUI-Dialogue-Sirus\_Build\DialogueUI` — доступен
- installed: `D:\World of Warcraft 3.3.5a\interface\addons\DialogueUI` — доступен
- patch: `D:\!sirus_addons\patch-ruRU-i\DF\Interface` — доступен

## Ссылки
```json
{
  "scanned_files": 108,
  "reference_occurrences": 196,
  "unique_paths": 135,
  "broken_unique_paths": 1,
  "broken_occurrences": 1,
  "source_assets": 273,
  "build_assets": 273,
  "build_tga": 251,
  "missing_source_blp_conversions": 22,
  "unmentioned_tga": 124,
  "case_mismatches": 0,
  "unresolved_expressions": 192,
  "numeric_expressions": 0,
  "external_literals": 0
}
```
Нарушения расширений в прямых тематических ссылках: 0

## source
Файлов: 273; несовместимых по статическим правилам: 0; с предупреждениями: 2.
Покрытие тем: {"Theme_Brown": 60, "Theme_Dark": 60, "Theme_Shared": 32}
Форматы: {".blp": 273}
Отсутствующих уникальных статических ссылок: 1.
- `Icons/NPCType-`

## build
Файлов: 273; несовместимых по статическим правилам: 18; с предупреждениями: 14.
Покрытие тем: {"Theme_Brown": 60, "Theme_Dark": 60, "Theme_Shared": 32}
Форматы: {".tga": 251, ".blp": 4, ".jpg": 18}
Отсутствующих уникальных статических ссылок: 1.
- `Icons/NPCType-`
- Несовместим: `PreviewPicture/AutoQuestPopup.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/BookUI.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/CameraChangeFov.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/CopyTextButton.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/GameMenuImage.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/HideOutlineSparkles.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/MarkHighestSellPrice.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/NameplateDialogEnabled.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/QuestAutoComplete.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/QuestDifficultyStyle.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/QuestItemDisplay.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/QuestTypeText.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/QuickSlotQuestReward.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/SimplifyCurrencyReward.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/Theme.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `PreviewPicture/TTSButton.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `Theme_Brown/DropdownMenu-Background.jpg` — not BLP/TGA: not accepted by audit compatibility contract
- Несовместим: `Theme_Dark/DropdownMenu-Background.jpg` — not BLP/TGA: not accepted by audit compatibility contract

## installed
Файлов: 273; несовместимых по статическим правилам: 0; с предупреждениями: 2.
Покрытие тем: {"Theme_Brown": 60, "Theme_Dark": 60, "Theme_Shared": 32}
Форматы: {".blp": 273}
Отсутствующих уникальных статических ссылок: 1.
- `Icons/NPCType-`

## patch
Файлов: 0; несовместимых по статическим правилам: 0; с предупреждениями: 0.
Покрытие тем: {"Theme_Brown": 0, "Theme_Dark": 0, "Theme_Shared": 0}
Форматы: {}

## source_to_build
Сопоставлено 112; различаются 46; отсутствуют 270; лишние 269.
Различающиеся файлы:
- `API.lua`
- `Art/GameAssets/ui_majorfactions_candle.blp`
- `Art/GameAssets/ui_majorfactions_flame.blp`
- `Art/GameAssets/ui_majorfactions_storm.blp`
- `Art/GameAssets/ui_majorfactions_web.blp`
- `Code/Book/BookUI.lua`
- `Code/Book/BookUI.xml`
- `Code/Book/BookUI_Component.lua`
- `Code/Camera.lua`
- `Code/Compat/Compat_335.lua`
- `Code/Dialogue/AlertFrame.lua`
- `Code/Dialogue/Banner.lua`
- `Code/Dialogue/ChatFrame.lua`
- `Code/Dialogue/Clipboard.lua`
- `Code/Dialogue/DialogueUI.lua`
- `Code/Dialogue/DialogueUI.xml`
- `Code/Dialogue/FriendshipBar.lua`
- `Code/Dialogue/QuestHeaderWidget.lua`
- `Code/Dialogue/StatusBar.lua`
- `Code/Dialogue/Translator.lua`
- `Code/Dialogue/UITemplates.lua`
- `Code/GossipData/GossipData_Icon.lua`
- `Code/GossipData/GossipData_Racing.lua`
- `Code/NameplateGossip.lua`
- `Code/Scroll/Scroll_Bar.lua`
- `Code/Settings/Settings.lua`
- `Code/Settings/Settings.xml`
- `Code/Settings/Settings_DropdownMenu.lua`
- `Code/SharedUITemplates/GenericFrame.lua`
- `Code/SharedUITemplates/SharedUITemplates.lua`
- `Code/SharedUITemplates/SharedUITemplates.xml`
- `Code/Tooltip/Tooltip.xml`
- `Code/Tooltip/Tooltip_Base.lua`
- `Code/Utility/DevTool.lua`
- `Code/Utility/FontUtil.lua`
- `Code/Utility/LocaleFormatter.lua`
- `Code/Utility/TTS.lua`
- `Code/Utility/TextureSlice.lua`
- `Code/Utility/ThemeUtil.lua`
- `Code/Widget/HelpTip.lua`
- `Code/Widget/SplashScreen_Gamepad.lua`
- `Code/Widget/WidgetManager.lua`
- `Code/Widget/Widget_ItemButton.lua`
- `Code/Widget/Widget_QuestItemDisplay.lua`
- `Code/Widget/Widget_QuestPopup.lua`
- `DialogueUI.toc`

## art_names_source_to_build
Относительные имена без расширений: отсутствуют 0; лишние 0.

## source_to_installed
Сопоставлено 382; различаются 108; отсутствуют 0; лишние 0.
Различающиеся файлы:
- `API.lua`
- `API.xml`
- `Code/Book/BookUI.lua`
- `Code/Book/BookUI.xml`
- `Code/Book/BookUI_Atlas.lua`
- `Code/Book/BookUI_Component.lua`
- `Code/CallbackRegistry.lua`
- `Code/Camera.lua`
- `Code/Compat/Compat_335.lua`
- `Code/Core.lua`
- `Code/Dialogue/ActionButton.lua`
- `Code/Dialogue/AlertFrame.lua`
- `Code/Dialogue/Banner.lua`
- `Code/Dialogue/ChatFrame.lua`
- `Code/Dialogue/Clipboard.lua`
- `Code/Dialogue/DialogueUI.lua`
- `Code/Dialogue/DialogueUI.xml`
- `Code/Dialogue/FriendshipBar.lua`
- `Code/Dialogue/KeyboardControl.lua`
- `Code/Dialogue/QuestFlyout.lua`
- `Code/Dialogue/QuestHeaderWidget.lua`
- `Code/Dialogue/QuestRewards.lua`
- `Code/Dialogue/RewardTooltipCode.lua`
- `Code/Dialogue/StatusBar.lua`
- `Code/Dialogue/Translator.lua`
- `Code/Dialogue/Tutorial.lua`
- `Code/Dialogue/UITemplates.lua`
- `Code/GossipData/GossipDataProvider.lua`
- `Code/GossipData/GossipDataProvider.xml`
- `Code/GossipData/GossipData_AutoQuest.lua`
- `Code/GossipData/GossipData_AutoSelect.lua`
- `Code/GossipData/GossipData_Hint.lua`
- `Code/GossipData/GossipData_Icon.lua`
- `Code/GossipData/GossipData_LFRQueue.lua`
- `Code/GossipData/GossipData_MiscTooltip.lua`
- `Code/GossipData/GossipData_OverrideOrder.lua`
- `Code/GossipData/GossipData_QuickSlot.lua`
- `Code/GossipData/GossipData_Racing.lua`
- `Code/GossipData/GossipData_ShowUI.lua`
- `Code/GossipData/GossipData_Teleport.lua`
- `Code/GossipData/ItemData_Container.lua`
- `Code/InWorldUI.lua`
- `Code/NameplateGossip.lua`
- `Code/QuestAreaTrigger.lua`
- `Code/QuestDifficulty.lua`
- `Code/Scroll/Scroll.xml`
- `Code/Scroll/Scroll_Bar.lua`
- `Code/Scroll/Scroll_EasySmooth.lua`
- `Code/Scroll/Scroll_Swipe.lua`
- `Code/Scroll/Scroll_View.lua`
- `Code/Settings/Settings.lua`
- `Code/Settings/Settings.xml`
- `Code/Settings/Settings_Definitions.lua`
- `Code/Settings/Settings_DropdownMenu.lua`
- `Code/Settings/Settings_Font.lua`
- `Code/Settings/Settings_Keybinding.lua`
- `Code/SharedUITemplates/GenericFrame.lua`
- `Code/SharedUITemplates/SharedUITemplates.lua`
- `Code/SharedUITemplates/SharedUITemplates.xml`
- `Code/Skimmer/Skimmer.xml`
- `Code/Skimmer/Skimmer_Base.lua`
- `Code/Skimmer/Skimmer_Template.lua`
- `Code/Skimmer/Skimmer_UI.lua`
- `Code/Sound.lua`
- `Code/SupportedAddOns/BtWQuests.lua`
- `Code/SupportedAddOns/ChattyLittleNpc.lua`
- `Code/SupportedAddOns/CzechQuests.lua`
- `Code/SupportedAddOns/InteractiveWormholes.lua`
- `Code/SupportedAddOns/MultiLanguage.lua`
- `Code/SupportedAddOns/Pawn.lua`
- `Code/SupportedAddOns/Platine1AddOns.lua`
- `Code/SupportedAddOns/Rematch.lua`
- `Code/SupportedAddOns/Roleplay.lua`
- `Code/SupportedAddOns/SupportedAddOns.lua`
- `Code/SupportedAddOns/SupportedAddOns.xml`
- `Code/SupportedAddOns/TranslatorPublic.lua`
- `Code/SupportedAddOns/VoiceoverPublic.lua`
- `Code/SupportedAddOns/Wholly.lua`
- `Code/SupportedAddOns/WorldFrameAddOns.lua`
- `Code/SupportedAddOns/WowUkrainizer.lua`
- `Code/Tooltip/Tooltip.xml`
- `Code/Tooltip/Tooltip_Base.lua`
- `Code/Tooltip/Tooltip_Capture.lua`
- `Code/Tooltip/Tooltip_Private.lua`
- `Code/Tooltip/Tooltip_Public.lua`
- `Code/Utility/ActionThrottler.lua`
- `Code/Utility/DevTool.lua`
- `Code/Utility/DeviceUtil.lua`
- `Code/Utility/FontUtil.lua`
- `Code/Utility/InteractionManager.lua`
- `Code/Utility/Keybindings.lua`
- `Code/Utility/LocaleFormatter.lua`
- `Code/Utility/QuestMuter.lua`
- `Code/Utility/TTS.lua`
- `Code/Utility/TextureSlice.lua`
- `Code/Utility/ThemeUtil.lua`
- `Code/Utility/Utility.xml`
- `Code/Widget/HelpTip.lua`
- `Code/Widget/SplashScreen_Gamepad.lua`
- `Code/Widget/WidgetManager.lua`
- `Code/Widget/WidgetManager.xml`
- `Code/Widget/Widget_ItemButton.lua`
- `Code/Widget/Widget_QuestItemDisplay.lua`
- `Code/Widget/Widget_QuestPopup.lua`
- `Code/Widget/Widget_QuickSlot.lua`
- `DialogueUI.toc`
- `Fonts.xml`
- `Initialization.lua`

## art_names_source_to_installed
Относительные имена без расширений: отсутствуют 0; лишние 0.

## build_to_installed
Сопоставлено 112; различаются 112; отсутствуют 269; лишние 270.
Различающиеся файлы:
- `API.lua`
- `API.xml`
- `Art/GameAssets/ui_majorfactions_candle.blp`
- `Art/GameAssets/ui_majorfactions_flame.blp`
- `Art/GameAssets/ui_majorfactions_storm.blp`
- `Art/GameAssets/ui_majorfactions_web.blp`
- `Code/Book/BookUI.lua`
- `Code/Book/BookUI.xml`
- `Code/Book/BookUI_Atlas.lua`
- `Code/Book/BookUI_Component.lua`
- `Code/CallbackRegistry.lua`
- `Code/Camera.lua`
- `Code/Compat/Compat_335.lua`
- `Code/Core.lua`
- `Code/Dialogue/ActionButton.lua`
- `Code/Dialogue/AlertFrame.lua`
- `Code/Dialogue/Banner.lua`
- `Code/Dialogue/ChatFrame.lua`
- `Code/Dialogue/Clipboard.lua`
- `Code/Dialogue/DialogueUI.lua`
- `Code/Dialogue/DialogueUI.xml`
- `Code/Dialogue/FriendshipBar.lua`
- `Code/Dialogue/KeyboardControl.lua`
- `Code/Dialogue/QuestFlyout.lua`
- `Code/Dialogue/QuestHeaderWidget.lua`
- `Code/Dialogue/QuestRewards.lua`
- `Code/Dialogue/RewardTooltipCode.lua`
- `Code/Dialogue/StatusBar.lua`
- `Code/Dialogue/Translator.lua`
- `Code/Dialogue/Tutorial.lua`
- `Code/Dialogue/UITemplates.lua`
- `Code/GossipData/GossipDataProvider.lua`
- `Code/GossipData/GossipDataProvider.xml`
- `Code/GossipData/GossipData_AutoQuest.lua`
- `Code/GossipData/GossipData_AutoSelect.lua`
- `Code/GossipData/GossipData_Hint.lua`
- `Code/GossipData/GossipData_Icon.lua`
- `Code/GossipData/GossipData_LFRQueue.lua`
- `Code/GossipData/GossipData_MiscTooltip.lua`
- `Code/GossipData/GossipData_OverrideOrder.lua`
- `Code/GossipData/GossipData_QuickSlot.lua`
- `Code/GossipData/GossipData_Racing.lua`
- `Code/GossipData/GossipData_ShowUI.lua`
- `Code/GossipData/GossipData_Teleport.lua`
- `Code/GossipData/ItemData_Container.lua`
- `Code/InWorldUI.lua`
- `Code/NameplateGossip.lua`
- `Code/QuestAreaTrigger.lua`
- `Code/QuestDifficulty.lua`
- `Code/Scroll/Scroll.xml`
- `Code/Scroll/Scroll_Bar.lua`
- `Code/Scroll/Scroll_EasySmooth.lua`
- `Code/Scroll/Scroll_Swipe.lua`
- `Code/Scroll/Scroll_View.lua`
- `Code/Settings/Settings.lua`
- `Code/Settings/Settings.xml`
- `Code/Settings/Settings_Definitions.lua`
- `Code/Settings/Settings_DropdownMenu.lua`
- `Code/Settings/Settings_Font.lua`
- `Code/Settings/Settings_Keybinding.lua`
- `Code/SharedUITemplates/GenericFrame.lua`
- `Code/SharedUITemplates/SharedUITemplates.lua`
- `Code/SharedUITemplates/SharedUITemplates.xml`
- `Code/Skimmer/Skimmer.xml`
- `Code/Skimmer/Skimmer_Base.lua`
- `Code/Skimmer/Skimmer_Template.lua`
- `Code/Skimmer/Skimmer_UI.lua`
- `Code/Sound.lua`
- `Code/SupportedAddOns/BtWQuests.lua`
- `Code/SupportedAddOns/ChattyLittleNpc.lua`
- `Code/SupportedAddOns/CzechQuests.lua`
- `Code/SupportedAddOns/InteractiveWormholes.lua`
- `Code/SupportedAddOns/MultiLanguage.lua`
- `Code/SupportedAddOns/Pawn.lua`
- `Code/SupportedAddOns/Platine1AddOns.lua`
- `Code/SupportedAddOns/Rematch.lua`
- `Code/SupportedAddOns/Roleplay.lua`
- `Code/SupportedAddOns/SupportedAddOns.lua`
- `Code/SupportedAddOns/SupportedAddOns.xml`
- `Code/SupportedAddOns/TranslatorPublic.lua`
- `Code/SupportedAddOns/VoiceoverPublic.lua`
- `Code/SupportedAddOns/Wholly.lua`
- `Code/SupportedAddOns/WorldFrameAddOns.lua`
- `Code/SupportedAddOns/WowUkrainizer.lua`
- `Code/Tooltip/Tooltip.xml`
- `Code/Tooltip/Tooltip_Base.lua`
- `Code/Tooltip/Tooltip_Capture.lua`
- `Code/Tooltip/Tooltip_Private.lua`
- `Code/Tooltip/Tooltip_Public.lua`
- `Code/Utility/ActionThrottler.lua`
- `Code/Utility/DevTool.lua`
- `Code/Utility/DeviceUtil.lua`
- `Code/Utility/FontUtil.lua`
- `Code/Utility/InteractionManager.lua`
- `Code/Utility/Keybindings.lua`
- `Code/Utility/LocaleFormatter.lua`
- `Code/Utility/QuestMuter.lua`
- `Code/Utility/TTS.lua`
- `Code/Utility/TextureSlice.lua`
- `Code/Utility/ThemeUtil.lua`
- `Code/Utility/Utility.xml`
- `Code/Widget/HelpTip.lua`
- `Code/Widget/SplashScreen_Gamepad.lua`
- `Code/Widget/WidgetManager.lua`
- `Code/Widget/WidgetManager.xml`
- `Code/Widget/Widget_ItemButton.lua`
- `Code/Widget/Widget_QuestItemDisplay.lua`
- `Code/Widget/Widget_QuestPopup.lua`
- `Code/Widget/Widget_QuickSlot.lua`
- `DialogueUI.toc`
- `Fonts.xml`
- `Initialization.lua`

## Порядок загрузки: source
Прочитано в порядке загрузки: 117; отсутствует 0; циклов 0; DUI inherits до определения 0.
```json
{
  "files": 117,
  "missing": [],
  "cycles": [],
  "dui_inherits_before_definition": [],
  "required_positions": {
    "Code/Compat/Compat_335.lua": 1,
    "Code/Compat/TextureSizes_335.lua": 2,
    "Initialization.lua": 3,
    "Code/Utility/ThemeUtil.lua": 26,
    "Code/Utility/TextureSlice.lua": 28,
    "Code/SharedUITemplates/SharedUITemplates.xml": 37,
    "Code/Dialogue/DialogueUI.xml": 71,
    "Code/Book/BookUI.xml": 88
  }
}
```

## Порядок загрузки: build
Прочитано в порядке загрузки: 116; отсутствует 0; циклов 0; DUI inherits до определения 0.
```json
{
  "files": 116,
  "missing": [],
  "cycles": [],
  "dui_inherits_before_definition": [],
  "required_positions": {
    "Code/Compat/Compat_335.lua": 1,
    "Code/Compat/TextureSizes_335.lua": null,
    "Initialization.lua": 2,
    "Code/Utility/ThemeUtil.lua": 25,
    "Code/Utility/TextureSlice.lua": 27,
    "Code/SharedUITemplates/SharedUITemplates.xml": 36,
    "Code/Dialogue/DialogueUI.xml": 70,
    "Code/Book/BookUI.xml": 87
  }
}
```

## Порядок загрузки: installed
Прочитано в порядке загрузки: 117; отсутствует 0; циклов 0; DUI inherits до определения 0.
```json
{
  "files": 117,
  "missing": [],
  "cycles": [],
  "dui_inherits_before_definition": [],
  "required_positions": {
    "Code/Compat/Compat_335.lua": 1,
    "Code/Compat/TextureSizes_335.lua": 2,
    "Initialization.lua": 3,
    "Code/Utility/ThemeUtil.lua": 26,
    "Code/Utility/TextureSlice.lua": 28,
    "Code/SharedUITemplates/SharedUITemplates.xml": 37,
    "Code/Dialogue/DialogueUI.xml": 71,
    "Code/Book/BookUI.xml": 88
  }
}
```

## Ограничения и следующий шаг
Полные заголовки, диапазоны альфы, размеры, последовательности загрузки и различия: snapshot_report.json.
Все исходные ссылки, динамические выражения и битые пути по темам: texture_report.md / texture_report.json.
Слои, нарезка, выбор расширения клиентом, ранняя инициализация и отображение в Sirus не доказаны статикой.
Нужны интеграция ведущим, повтор этой проверки после пересборки и проверка обеих тем, книги и общих окон в игре.
Коммит, push, пересборка и обновление релиза в этом задании не выполнялись.
