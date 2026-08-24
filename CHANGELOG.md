# Changelog

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
