# Fallout 4 VR test matrix

Use a disposable save made outside an active knockout. Test once with the vanilla
VR player body and once with FRIK if it is part of the target load order.

## Startup

- Fallout 4 VR 1.2.72 starts through F4SEVR 0.6.21.
- The complete F4SEVR `Data\Scripts` set is installed; a binary-only install
  leaves the v1.4 worn-item, looting, and power-armor functions unable to link.
- `KnockoutFramework.log` reports a validated VR hook and successful load.
- The MCM/holotape opens and every v1.4 setting remains available.
- An unsupported executable fails closed without patching memory.

## Player paths

- With Player Knockout disabled, ordinary melee, bash, unarmed, and paired
  finishers never leave movement, hands, menus, or combat locked.
- With Player Knockout enabled, test nonlethal KO, lethal deferred death, save/load
  while unconscious, and changing the option off during a pending hit.
- Exercise respawn modes 0, 1, 2, and 3, including missing/occupied beds, Survival,
  theft enabled/disabled, allies sharing loot, and stolen-item tracking.
- Confirm time scale, fade, death-event suppression, movement, and weapon input are
  restored after success, failure, reload, and a second KO immediately afterward.

## NPC and interaction paths

- Test normal-hit, VATS, fall, bleedout, unarmed, bash, and all available paired
  finisher knockouts on ordinary NPCs, followers, essential actors, power armor,
  robots, synths, and excluded actors.
- Verify wake, stimpak requirement, loot, push, kidnap, release, power-armor
  stripping, and each weighted execution choice.
- Verify KO duration changes, death-if-not-helped, convalescence stages, restart,
  and uninstall do not leave stale aliases, timers, ghost state, or input state.

## Regression soak

- Repeat close combat across cell changes and save/load cycles with Player
  Knockout both on and off.
- Watch the Papyrus log for array bounds, None-object, animation registration,
  timer, or latent-stack errors.
- Confirm no desktop `KnockoutFramework.dll` or `.mem` file wins a mod conflict.
