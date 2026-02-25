# SkillSound (v0.1.0)

A World of Warcraft 12.0 addon that plays configurable sounds when:

- The player successfully casts configured spells (`UNIT_SPELLCAST_SUCCEEDED`)
- The player gains configured buffs/debuffs (`UNIT_AURA` with added aura handling)

## Included

- `SkillSound.toc` with addon metadata (`author: skeletor-gh`, `version: 0.1.0`, icon)
- `SkillSound.lua` core event processing and saved-variable defaults
- `Sounds.lua` custom sound registry framework backed by LibSharedMedia-3.0
- `Options.lua` settings panel under **AddOns → SkillSound**

## Custom sounds

1. Put sound files in `assets/`
2. Add entries to `ns.customSounds` inside `Sounds.lua`
3. Reload UI (`/reload`)

Each custom sound is registered into LibSharedMedia and can be selected in the options UI.
