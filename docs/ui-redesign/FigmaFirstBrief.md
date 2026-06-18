# Parryhook UI Redesign - Figma First Brief

Consulted: 2026-06-01

## Goal

Create a competitive but friendly Roblox UI for Parryhook before changing Luau.
The visual language stays dark and energetic, with cyan, gold, violet, and pink
accents. Familiar Roblox patterns should reduce learning time without copying
another game's visual identity.

## Benchmark

Roblox Charts describes Top Playing Now as a real-time view based on concurrent
users. The benchmark uses current popular experiences and adjacent genre
references, not a claim that every reference is ranked in the same order at all
times.

| Reference | Public evidence | Pattern to adapt for Parryhook |
| --- | --- | --- |
| RIVALS | Competitive FPS experience with a short-match loop | Compact combat HUD, strong primary action hierarchy, clear pre-match and post-match states |
| Blade Ball | Official game description lists PC, console, and tap controls for block and ability actions | Large touch targets, action parity across devices, immediate timing feedback |
| Blox Fruits | Persistent progression loop with shop and inventory systems | Stable hub navigation, readable persistent progression, clear owned/equipped states |
| Grow a Garden | Shop restocks, inventory loop, offline growth, and simple repeatable actions | Friendly reward presentation, legible shop cards, low-friction claim actions |

### Sources

- Roblox Charts Top Playing Now:
  https://www.roblox.com/charts/top-playing-now
- Roblox announcement for Top Playing Now:
  https://devforum.roblox.com/t/introducing-top-playing-now-on-charts/3529809
- RIVALS:
  https://www.roblox.com/games/17625359962/RIVALS
- Blade Ball:
  https://www.roblox.com/games/13772394625/Blade-Ball
- Blox Fruits:
  https://www.roblox.com/games/2753915549/Blox-Fruits
- Grow a Garden:
  https://www.roblox.com/games/126884695634066/Grow-a-Garden

## Evidence From The Current Project

The current UI already supports:

- Combat HUD: health, damage flash, ammo, mode, score, and scoreboard.
- Match overlays: waiting, intermission, team assignment, kill feed, medals,
  round contracts, announcements, and post-match summary.
- Progression: wallet, rotating shop, catalog, cosmetic preview, daily reward,
  Season Road, and ranked profile.
- Tutorial: movement, grapple, shooting, reload, parry, contracts, and shop.

Main usability gaps:

- Most panels use fixed pixel sizes and extensive `TextScaled`.
- The progression hub is fixed at `680x760`.
- Desktop prompts mention `Tab`, `M`, `H`, `Q`, `F`, `R`, and `G`, with no
  visible touch equivalents.
- The gameplay input layer has no functional mobile action router yet.

## Figma File Structure

Create a Figma Design file named `Parryhook UI Redesign`.

| Page | Content |
| --- | --- |
| `00 Benchmark` | Reference links, observations, and consulted date |
| `01 Foundations` | Colors, typography, spacing, radii, elevation, states, safe areas |
| `02 Components` | Panels, buttons, chips, cards, tabs, progress, notification, scoreboard row, touch button |
| `03 Desktop` | Frames at `1440x900` |
| `04 Mobile` | Frames at `390x844` |
| `05 Handoff` | Figma-to-Roblox mapping, state tables, and implementation order |

## Foundations

### Color tokens

| Token | Hex | Use |
| --- | --- | --- |
| `ink` | `#06080E` | App and overlay background |
| `panel` | `#0B0E18` | Primary glass surface |
| `panelSoft` | `#121726` | Secondary surface |
| `panelLift` | `#1D243A` | Hovered and selected surface |
| `stroke` | `#526996` | Neutral border |
| `cyan` | `#40E6FF` | Mobility, interaction, primary focus |
| `gold` | `#FFD854` | Rewards, coins, featured actions |
| `pink` | `#FF56AE` | Critical action and special cosmetic |
| `violet` | `#9A65FF` | Season, progression, ability accent |
| `green` | `#70FF97` | Ready, success, available |
| `red` | `#FF525C` | Danger, low health, unavailable |
| `text` | `#F5F8FF` | Primary text |
| `muted` | `#9EACC6` | Supporting text |

### Type

- Display: Gotham Black or closest available Figma substitute, uppercase.
- Action: Gotham Bold or closest substitute.
- Body: Gotham Medium or closest substitute.
- Avoid unrestricted text scaling. Use explicit desktop and mobile sizes.

### Layout

- Spacing scale: `4, 8, 12, 16, 24, 32, 48`.
- Radii: `9, 14, 20, 999`.
- Minimum touch target: `44x44`.
- Mobile action buttons: prefer `52x52` to `68x68`.
- Desktop safe edge: `24`.
- Mobile safe edge: `16`, with Roblox top bar and device inset considered.

## Component Inventory

| Component | Variants |
| --- | --- |
| `Panel/Glass` | default, lifted, danger |
| `Button/Action` | primary, secondary, reward, danger; default, pressed, disabled |
| `Chip/Ability` | ready, cooldown, active, disabled |
| `Card/ShopItem` | default, selected, owned, equipped, locked |
| `Card/Reward` | claimable, claimed, locked |
| `Tab/Nav` | default, selected |
| `Progress/Bar` | health, xp, contract, cooldown |
| `Notification/Toast` | info, medal, contract, danger |
| `Row/Scoreboard` | player, localPlayer, teamA, teamB |
| `Touch/Action` | fire, reload, jump, dash, slide, hook, parry |

## Screens

### Desktop `1440x900`

- HUD normal.
- HUD team combat.
- HUD low health and reload.
- Waiting and intermission.
- Team assignment.
- Contract and medal notifications.
- Tutorial.
- Scoreboard.
- Post-match summary.
- Progression hub: shop, preview, daily reward, Season Road, profile.

### Mobile `390x844`

- Playable combat HUD with native joystick placeholder.
- Buttons: `FIRE`, `RLD`, `JUMP`, `DASH`, `SLIDE`, `HOOK`, `PARRY`.
- Shop and scoreboard shortcuts.
- Stacked progression hub with scrollable content.
- Representative Spanish expansion variants:
  `RECARGAR`, `DESLIZAR`, `GANCHO`, `CONTRATO COMPLETADO`.

## Interaction Rules

- Keep crosshair space quiet. Cooldown chips sit below the crosshair, not over it.
- Use gold only for rewards and claim actions.
- Use cyan for movement and primary navigation.
- Use violet for Season Road and progression depth.
- Use pink sparingly for parry emphasis and special cosmetics.
- Every keyboard-only instruction needs an icon or mobile equivalent.
- Keep native Roblox joystick and camera behavior.

## Approval Gate

Do not modify Luau for the redesign until the Figma mockup is reviewed and
approved. The files in `figma-import/` are starter boards for import into Figma,
not implementation changes.

## Import Starter Boards

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

For a deterministic local import, use:

- `figma-plugin/manifest.json`
- `figma-plugin/README.md`
