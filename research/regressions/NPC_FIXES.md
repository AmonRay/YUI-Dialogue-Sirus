# NPC fixes — client acceptance still required

Run `python research/regressions/check_npc_fixes.py` for isolated Lua 5.1 regressions.

## Implemented
- Required-item owned/required count is in a separate right column. Name width reserves measured count width; normal count geometry is reset on item-name assignment and pool acquire.
- Already-ended dialog interactions no longer call CloseQuest/CloseGossip again.
- Camera restore retains SetView while standing. If the player is moving at restore time, restore saved zoom only, preserving current yaw/pitch. Original zoom is kept across quick reopen just like saved view 4. Zoom-only return is enabled only with a native GetCameraZoom query; the synthetic legacy fallback retains SetView. Motion beginning after SetView starts is not handled; this remains an in-client risk.
- Widget compatibility builds private method maps and applies them only to owned frames/regions/animations. XML applies preparation before mixin OnLoad; the private CreateFrame factory prepares dynamic objects. Native shared method tables are not written.

## Not established
The stretched item-picture cause is not established: icon anchors are square; its separate background is stretched by design. Do not call this visually fixed without a client comparison.
The CompactArenaFramePet3:Hide taint origin is not established. Removing shared method writes addresses a confirmed contamination risk, not proof of absence of taint. UIParent hiding and global helper fallbacks remain unchanged.

## Sirus checks after fresh reload outside combat
1. Required item 99/2048; long name; both themes and UI scales. Reuse required -> reward -> currency -> skill -> required. Confirm square icon and readable count/name.
2. Same NPC: ESC standing; walking away until automatic closure while continuing movement; stop just before closure; quests and gossip; quick reopen during camera return; vehicle. Confirm distance returns without heading snap and ESC standing unchanged.
3. Fresh reload per variant: DialogueUI only, then full addon set. Arena/group member and third pet updates, both before any dialogue and after ESC/range closure. HideUI on/off; enter combat while UI hidden and close dialogue. Check UI restoration and protected pet frames.
4. If supported, `/console taintLog 2`, reload outside combat, reproduce once, retain entries preceding the first block, then `/console taintLog 0`. Do not suppress ADDON_ACTION_BLOCKED.

No release archive or external publication is performed by these checks.
