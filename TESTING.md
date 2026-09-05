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

- On a new Survival/Hardcore game, let a vanilla radroach repeatedly bite the
  player. `UnarmedRadRoach` must retain its VR reach override, every hit must
  return through the native damage hook without a CTD, and a lethal eligible hit
  must proceed into the selected death-alternative scenario.
- With Player Knockout disabled, ordinary melee, bash, unarmed, and paired
  finishers never leave movement, hands, menus, or combat locked.
- With Player Knockout enabled, test nonlethal KO, lethal deferred death, save/load
  while unconscious, and changing the option off during a pending hit.
- Exercise respawn modes 0, 1, 2, and 3, including missing/occupied beds, Survival,
  theft enabled/disabled, allies sharing loot, and stolen-item tracking.
- Confirm time scale, fade, death-event suppression, movement, and weapon input are
  restored after success, failure, reload, and a second KO immediately afterward.

## Player-involved paired finishers (headset required)

- Exercise the player as victim for each of the 21 standard paired-finisher
  variants. With Player Knockout enabled, confirm the paired scene disappears at
  its first animation tick without freezing headset tracking or the hands, and
  that the standard knockout/death-alternative result still completes. Repeat
  with Player Knockout disabled and confirm the configured normal-death fallback.
- Exercise the player as victim for each of the four bash variants and repeat the
  same checks, including preservation of the distinct bash outcome mapping.
- Exercise the player as aggressor against monitored NPC victims for all 21
  standard and four bash variants. The player-containing synchronized scene must
  be skipped immediately, while each NPC still reaches the same knockout or
  normal-death result selected by the non-VR framework rules.
- In a diagnostic build, force `SkipPlayerPairedAnimation` to return `False`
  without modifying executable bytes. Confirm the early handler leaves its
  pending state clear, the original late animation annotation remains usable,
  and the configured gameplay result resolves only once.
- After every successful early teardown, wait beyond both watchdog windows and
  confirm a queued late marker cannot produce a duplicate knockout, death,
  inventory transfer, or respawn.
- Repeat representative victim and aggressor cases with the vanilla VR body and
  FRIK, in and out of power armor, and after save/load and cell transitions.

## NPC and interaction paths

- Run NPC-vs-NPC coverage across the same 21 standard and four bash paired
  variants. Every animation must remain visible from start to end, with no early
  native teardown, and its existing knockout/death result must remain unchanged.
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
