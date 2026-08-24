# Knockout Framework VR

Unofficial, full-gameplay-feature Fallout 4 VR port of Knockout Framework 1.4.0.

The port targets Fallout 4 VR 1.2.72 and F4SEVR 0.6.21. It keeps the v1.4
native damage manager, all paired-finisher knockout assets, all player and NPC
knockout paths, the four player respawn choices, deferred death, theft and item
recovery, convalescence, fall-damage knockouts, MCM configuration, and the public
Papyrus API.

## VR-specific implementation

- Ports the native `Actor::DoHitMe(HitData&)` interception to the verified VR
  1.2.72 callsite and full 0xE0 VR `HitData` layout.
- Rejects every unsupported runtime and validates the live callsite and original
  function bytes before installing the hook.
- Keeps all 25 paired-finisher victim animations and makes their custom KO/death
  event routing bounded and recoverable.
- Makes KO collection admission and removal transactional and adds
  generation-checked timers plus framework-owned state recovery for interrupted
  or stale knockouts.
- Enforces the Player Knockout setting at the final KO entry point, including
  deferred-death and paired-finisher paths.
- Replaces desktop-only forced-camera and player sleep-animation waits with a VR
  fade/teleport sequence while preserving every configured respawn destination
  and scenario outcome.
- Adds watchdog cleanup for player recovery, get-up animation loss, temporary
  time-scale changes, and save/load interruption.
- Preserves the convalescence system without leaving a VR locomotion condition at
  zero.
- Keeps the knocked-out-actor interaction menu, looting, waking, kidnapping,
  releasing, power-armor stripping, execution choices, restart, and uninstall.
  Their flat-camera control scenes use bounded VR-safe transitions.
- Corrects v1.4's native unarmed-attack path so it honors the existing MCM option.

The goal is gameplay feature parity. Desktop-only presentation operations such as
forcing third-person camera cannot exist meaningfully in VR, so their VR equivalent
uses blackout/fade transitions without removing the underlying feature.

## Requirements

- Fallout 4 VR 1.2.72
- F4SEVR 0.6.21, installed from the complete official archive including its
  `Data\Scripts` PEX files (a binary-only install is insufficient)
- Mod Configuration Menu is optional, as in the original mod

## Installation

Install the release archive as one mod in Mod Organizer 2, enable `Knockout
Framework.esm`, and ensure this port wins every conflict against another Knockout
Framework installation. Do not allow the desktop `KnockoutFramework.dll` or its
`.mem` cache to overwrite the VR plugin.

For the first test, use a save made outside an active knockout/death-alternative
sequence. A control layer leaked by an already-suspended legacy script stack cannot
be recovered reliably after that old script has been replaced.

## Native build

Clone recursively, then run the following from a Visual Studio 2022 developer
shell:

```powershell
msbuild build-native.proj /m /t:Build /p:Configuration=Release /p:Platform=x64
```

The F4SEVR source dependency is a submodule; the installed runtime must still be
official F4SEVR 0.6.21 or newer.

The plugin is intentionally fixed to runtime 1.2.72. Supporting another executable
requires independently verifying its callsite, target, ABI, and `HitData` layout.

## Verification status

The release process compiles the native DLL and modified Papyrus sources, analyzes
and round-trips every replacement PEX, rebuilds and re-extracts the BA2, verifies
that all paired-finisher assets remain present and unchanged, and inspects the DLL
exports and dependencies. A private-desktop SteamVR null-HMD launch has also
verified F4SEVR loading, the exact VR hook, MO2 virtual-file injection, the ESM/BA2,
and clean Papyrus linking for Knockout Framework. The null driver exposes no
tracked controllers, so actual knockout, interaction, respawn, and save/load
gameplay still requires a headset/controller test before public release.

## Licensing and original assets

The published native source is covered by the repository's MIT license. The ESM,
BA2 content, interface files, translations, and MCM files come from the original
Knockout Framework 1.4.0 archive and may have separate distribution terms. Obtain
the author's permission before redistributing a package containing those assets.
