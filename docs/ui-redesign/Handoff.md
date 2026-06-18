# Parryhook UI Redesign - Handoff Draft

This document is a design handoff draft. Do not implement it until the Figma
mockup has been imported, reviewed, and explicitly approved.

## Figma Import Starter Boards

- `figma-import/01-foundations-components.svg`
- `figma-import/02-components.svg`
- `figma-import/00-benchmark.svg`
- `figma-import/03-desktop-hud.svg`
- `figma-import/03-desktop-progression.svg`
- `figma-import/03-desktop-season-profile.svg`
- `figma-import/03-match-overlays.svg`
- `figma-import/04-mobile-hud.svg`
- `figma-import/04-mobile-progression.svg`
- `figma-import/04-mobile-season.svg`
- `figma-import/04-mobile-profile.svg`
- `figma-import/05-handoff.svg`

Import each SVG into the matching Figma page and convert repeated elements into
components and variants.

For a deterministic local import in Figma Desktop, load
`figma-plugin/manifest.json` as a development plugin and select all SVG files
when prompted. The importer creates the six ordered pages and replaces only its
own previous import when rerun.

## Figma To Roblox Map

| Figma component | Roblox target |
| --- | --- |
| `Panel/Glass` | Extend `UITheme.stylePanel` |
| `Button/Action` | Extend `UITheme.styleButton` |
| `Chip/Ability` | New shared chip constructor in HUD |
| `Card/ShopItem` | Extract from `EconomyController.client.luau` |
| `Card/Reward` | Extract daily and season reward card helpers |
| `Tab/Nav` | Extract Shop, Season, Profile tab helper |
| `Progress/Bar` | Shared health, XP, contract, and cooldown helper |
| `Notification/Toast` | Match contract and medal overlays |
| `Row/Scoreboard` | Extract from `HUD.luau` scoreboard row builder |
| `Touch/Action` | New mobile action button helper |

## Responsive Behavior

| Surface | Desktop | Mobile |
| --- | --- | --- |
| Combat HUD | Health left, abilities below crosshair, ammo right | Health compact left, native joystick, action cluster right |
| Scoreboard | Center modal | Full-height sheet |
| Progression hub | Two-column modal or centered panel | Full-screen sheet with stacked scroll |
| Shop catalog | Multi-column cards | Single-column or two-column compact cards |
| Preview | Right-side or bottom detail panel | Stacked detail card below selected item |
| Tutorial | Bottom-left card | Top or mid-left toast, avoiding joystick |

## Input Router After Approval

Add a client action router with:

```text
bind(actionName, handler)
dispatch(actionName, source)
setState(actionName, state)
```

Actions:

```text
jump
dash
slide
grapple
fire
reload
parry
toggleShop
toggleScoreboard
```

Keep movement joystick and camera behavior native to Roblox. Mobile buttons
dispatch the same client-side actions as keyboard and mouse. Server RemoteEvents
and server authority remain unchanged.

## Verification Checklist

- Contrast and hierarchy reviewed in Figma.
- Touch targets are at least `44x44`.
- EN and ES representative strings fit.
- Crosshair area stays quiet.
- Shop, Season Road, profile, scoreboard, overlays, respawn, and a full match
  are tested after implementation.
- Desktop and mobile parity is verified in Roblox Studio emulation.
