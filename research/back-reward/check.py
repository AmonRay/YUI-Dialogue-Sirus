"""Read-only Python model of ThemeUtil lookup; does NOT execute Lua or WoW.
Run: python research/back-reward/check.py
The GameAssets Manifest is prose, not an atlas/UV manifest. Files are enumerated
alongside it; TextureSizes_335 is the authoritative local name/size registry.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
ART = "Interface/AddOns/DialogueUI/Art/"
DIRECTORIES = ("Theme_Shared", "Icons", "Keys", "GameAssets", "Book",
               "BasicShapes", "ParchmentDecor", "PreviewPicture", "Shared")


def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


SIZES = {key: (int(w), int(h)) for key, w, h in re.findall(
    r'S\["([^"]+)"\]\s*=\s*\{(\d+),\s*(\d+)\}',
    read("Code/Compat/TextureSizes_335.lua"))}


def normalize(value):
    if not isinstance(value, str) or not value:
        return None
    value = re.sub(r"[/\\]+", "/", value)
    value = re.sub(r"\.(blp|tga|png|jpe?g|dds)$", "", value, flags=re.I)
    if value.lower().startswith(ART.lower()):
        value = value[len(ART):]
    elif value.lower().startswith("interface/"):
        return value, True
    elif value.lower().startswith("art/"):
        value = value[4:]
    return (value, False) if value else None


def find(value, theme):
    normalized = normalize(value)
    if not normalized:
        return None, None, "invalid"
    name, external = normalized
    if external:
        return name, None, "external"
    active = "Theme_Dark" if theme == 2 else "Theme_Brown"
    other = "Theme_Brown" if theme == 2 else "Theme_Dark"
    if "/" in name:
        candidates = [name]
        if name.lower().startswith("shared/"):
            candidates.append("Theme_Shared/" + name[7:])
    else:
        candidates = [directory + "/" + name for directory in
                      (active, *DIRECTORIES, other)]
    for candidate in candidates:
        size = SIZES.get(candidate.lower())
        if size:
            return ART + candidate, size, "local"
    return None, None, "missing"


def get(value, theme):
    file, size, kind = find(value, theme)
    if kind == "missing":
        return ART + "Theme_Shared/ClipboardBackground", SIZES.get(
            "theme_shared/clipboardbackground"), "fallback"
    return file, size, kind


def setters():
    """All texture/atlas/mask setters in popup and dialog item mixin.
    Mapping is explicitly bounded, not a general Lua expression evaluator.
    """
    paths = ["Code/Widget/Widget_QuestItemDisplay.lua", "Code/Dialogue/UITemplates.lua"]
    for path in paths:
        function = ""
        for number, line in enumerate(read(path).splitlines(), 1):
            if path.endswith("UITemplates.lua") and not 1373 <= number <= 1913:
                continue
            if "function " in line:
                function = line.strip()
            match = re.search(r'([\w.]+):(SetTexture|SetAtlas|SetMaskTexture|SetMask)\((.*)\);?', line)
            if not match:
                continue
            target, method, expression = match.groups()
            names = []
            route = "direct dynamic/native; ThemeUtil bypassed"
            if "QuestItemDisplay-UI" in expression or expression == "file" and "Widget_" in path:
                names = ["QuestItemDisplay-UI"]
            elif "ButtonIcon" in target:
                names = ["QuestItem-NotOnQuest"]
            elif "QUESTIONMARK" in expression:
                names = ["Interface/Icons/INV_Misc_QuestionMark"]
            elif "NOTE" in expression:
                names = ["Interface/Icons/INV_Misc_Note_02"]
            elif "borderFile" in expression:
                names = ["ItemBorder", "RewardChoice-ItemBorder"]
            elif "bgFile" in expression:
                names = ["ItemButtonBackground", "RewardChoice-Pending"]
            elif "GetTextureFile" in expression:
                names = re.findall(r'"([^"]+)"', expression)
            elif "majorFactionIcon" in expression:
                names = ["ui_majorfactions_" + suffix for suffix in ("candle", "flame", "storm", "web")]
                route = "ThemeUtil for four redirects; API.GetHonorIcon otherwise"
            if names and route.startswith("direct") and not names[0].startswith("Interface/"):
                route = "ThemeUtil.GetTextureFile; caller retains/sets UV"
            yield path, number, target, method, expression, names, route, function


def main():
    manifest = read("Art/GameAssets/Manifest.txt")
    print("MODEL ONLY: Lua/client not executed")
    print("Manifest.txt: prose; no file list, dimensions or atlas UV records")
    print("Manifest text:", " ".join(manifest.split()))
    print("TextureSizes entries:", len(SIZES))
    gameassets = sorted(p.stem for p in (ROOT / "Art/GameAssets").glob("*.blp"))
    print("GameAssets files:", ", ".join(gameassets))
    missing_assets = []
    assets = sorted({p.relative_to(ROOT / "Art").with_suffix("").as_posix().lower()
                     for p in (ROOT / "Art").rglob("*")
                     if p.suffix.lower() in (".blp", ".tga")})
    for key in assets:
        if key not in SIZES:
            missing_assets.append(key)
    print("Art asset keys:", len(assets))
    print("Art files without size:", missing_assets)
    routes = list(setters())
    unresolved_dynamic = []
    local_names = set()
    missing = set()
    no_size = set()
    for path, line, target, method, expression, names, route, function in routes:
        print(f"\n{path}:{line} {target}:{method}({expression})")
        print(" route:", route)
        if not names:
            unresolved_dynamic.append(f"{path}:{line}")
            print(" result: RUNTIME VALUE UNKNOWN; no local size expected for native icons")
        for name in names:
            for theme in (1, 2):
                file, size, kind = get(name, theme)
                print(f" theme={theme} {name} -> {file} size={size} kind={kind}")
                if kind == "local":
                    local_names.add(name)
                if kind == "fallback":
                    missing.add(name)
                if file and not size:
                    no_size.add(name)
    print("\nSUMMARY")
    print("Texture setter sites:", len(routes))
    print("Known local names:", len(local_names))
    print("Known local names missing size:", sorted(missing))
    print("Resolved names without local size:", sorted(no_size))
    print("Runtime-only sites:", len(unresolved_dynamic), ", ".join(unresolved_dynamic))
    print("SetAtlas/SetMaskTexture sites in covered item code:", sum(
        row[3] in ("SetAtlas", "SetMaskTexture") for row in routes))
    print("NOTE: GetTextureFile returns FILE ONLY. Size above is from FindTextureFile.")
    print("NOTE: UV data is caller/native-atlas data, NOT TextureSizes data.")
    print("NOTE: exact Energy Crystal icon path is unknown without GetQuestItemInfo runtime value.")


if __name__ == "__main__":
    main()
