# SkillSound (v0.1.0)

SkillSound is a World of Warcraft 12.0 addon that plays configurable sounds when:

1. The player successfully casts a spell.
2. The player gains a tracked aura (buff/debuff).

## Architecture

- `SkillSound.toc`: Addon metadata and load order.
- `SkillSound.lua`: Runtime event handling and trigger engine.
- `Options.lua`: In-game options panel and trigger manager.
- `SoundRepository.lua`: Custom sound registration and media access.
- `assets/`: Addon media assets.

## Tactical approach for 12.0 restrictions

The addon tracks spell and aura events by **spellID** instead of names. This avoids locale issues and reduces dependence on hidden/volatile values.

For aura gains, it uses a state-diff strategy:

- Build a snapshot of active `HELPFUL` and `HARMFUL` auras on the player.
- On `UNIT_AURA`, compare previous snapshot to current snapshot.
- Trigger only on newly gained tracked spellIDs.

This avoids relying on unstable aura internals while still detecting gains accurately.

## LibSharedMedia-3.0 integration

`LibSharedMedia-3.0` is loaded from `LibSharedMedia-3.0/lib.xml` via the addon TOC.

SkillSound uses LSM to:

- Enumerate available sound keys for dropdowns.
- Resolve configured sound keys to playable file paths.
- Register addon-local custom sounds from `SoundRepository.lua`.

## Custom sounds

Place your sound files under:

`Interface\AddOns\SkillSound\assets\`

Then register them in `SoundRepository.lua` by adding items to `CUSTOM_SOUNDS`.

## User workflow

- Open options: `/skillsound` or `/skillsound options`.
- Add spell triggers by spellID.
- Add aura gain triggers by spellID and filter (`HELPFUL`/`HARMFUL`).
- Assign per-trigger sounds and output channel.
- Enable/disable or remove entries directly in the options panel.

## Notes

- Saved variables are stored in `SkillSoundDB`.
- Default/fallback behavior plays a Blizzard sound when no custom sound is configured.
