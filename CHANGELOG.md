# Changelog

## 1.0

- Restores the native compatibility value expected by the original 1.4
  maintenance script. The public VR release remains version 1.0, while
  `F4SE.GetPluginVersion("KnockoutFramework")` now correctly reports `10400`
  so a loaded DLL is not mistaken for a missing or outdated F4SE installation.
- First public Fallout 4 VR release, based on Knockout Framework 1.4.0 and
  retaining its complete gameplay feature set.
- Prevents the ragdoll-exit effect from calling timer or animation-registration
  natives after its ActiveMagicEffect has become unbound. Actor-side completion
  signaling and owned Ghost cleanup still run, while the manager's existing
  bounded fallback remains responsible for ending the spell.
- Incorporates the clean release-candidate headset-test result: Fallout 4 VR
  1.2.72 accepted the plugin, all paired-scene and difficulty addresses validated, the damage
  hook installed, and the Papyrus animation bridge registered without a native
  warning or fail-closed event.

## 1.4.0-vr1.5

- Stops the incoming monitoring effects from attempting to schedule animation
  registration retries after they have become unbound.
- Removes the ineffective unbound retry loop from ragdoll-exit dispelling; the
  manager and the effect duration already provide bounded cleanup.

## 1.4.0-vr1.4

- Adds the VR port revision to the startup log, F4SE plugin version, and Windows
  DLL version resource so tester reports can identify the exact build.

## 1.4.0-vr1.3

- Skips a synchronized paired finisher at its first animation tick whenever the
  VR player is either victim or aggressor. The bridge uses a byte-validated
  native synchronized-scene teardown, preventing the otherwise frozen headset
  and hands while retaining the configured knockout, death-alternative, or
  normal-death result.
- Preserves all 25 conversion paths: the 21 standard variants retain their
  standard paired-kill outcome mapping, and the four bash variants retain their
  bash mapping. NPC-vs-NPC paired finishers still play visibly from start to end.
- Made the early path fail closed. If the native bridge cannot confirm and remove
  a player-containing synchronized scene, it returns without claiming the event;
  the existing late annotation remains available to resolve the gameplay result.
- Documented the exact Bethesda VR precedents. Vault-console activation uses the
  typoed `FurntiureNoPlayerAnim` keyword, while Pip-Boy pickup follows a direct
  scripted progression/equip path. Neither is a generic Papyrus event for
  suppressing paired animations.

## 1.4.0-vr1.2

- Fixed a deterministic native crash when an eligible unarmed, melee, or bash
  hit reached the difficulty-damage calculation. The vendored F4SEVR helper
  aliases the INI-preferences singleton to the game-settings collection and
  traverses the wrong object layout.
- Replaced both fragile settings lookups with Fallout 4 VR's own live difficulty
  and health-multiplier functions. Survival continues to use the same `PCSV`
  game settings as the desktop framework, including values changed by other
  mods.
- Added byte validation for both VR difficulty functions before the damage hook
  is installed. A mismatched executable now fails closed instead of entering an
  unsafe hit path.
- Confirmed that `Fallout4_VR.esm` intentionally changes `UnarmedRadRoach`
  reach from `0.68` to `0.17`. That override is preserved and is unrelated to
  the crash.

## 1.4.0-vr1.1

- Fixed startup with the official F4SEVR 0.6.21 build, which reports its
  historical desktop-compatible runtime token instead of the nominal VR token.
- Runtime safety remains fail-closed: the Fallout 4 VR 1.2.72 hook callsite and
  target prologue are validated byte-for-byte before any code is patched.
- Documented the complete F4SEVR script dependency after an isolated null-HMD
  launch exposed a binary-only F4SEVR installation.
- Passed private-desktop startup validation for the native hook, ESM/BA2, MO2
  virtual filesystem, SteamVR null driver, and Knockout Framework Papyrus links.

## 1.4.0-vr1

- Ported the v1.4 native damage hook to Fallout 4 VR 1.2.72 and F4SEVR 0.6.21.
- Preserved all four player death-alternative respawn modes and every NPC/player
  knockout eligibility setting.
- Preserved all 25 paired-finisher conversions with retryable event registration
  and a normal-death fallback when knockout is disabled or rejected.
- Added generation-safe KO timers, transactional collection bookkeeping, bounded
  ragdoll recovery, and interrupted-save cleanup.
- Preserved theft, stolen-item tracking, survival penalties, convalescence,
  kidnapping/release, power-armor stripping, looting, waking, execution, restart,
  uninstall, VATS, fall damage, and the public Papyrus API.
- Replaced flat-screen camera, player animation, and temporary input-layer scenes
  with bounded VR-safe fade/teleport equivalents.
- Corrected the native unarmed eligibility path to honor its existing MCM option.

This build has passed native compilation, Papyrus compilation, PEX analysis,
archive round-trip, and package integrity checks. It still requires real in-game
Fallout 4 VR testing before public release.
