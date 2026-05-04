## 1.0.0 2026-05-04 <code at nfrastack dot com>

   ### Added
      - Initial release
      - Bar pill displays current gamma temperature in Kelvin (live, from `DisplayService.gammaCurrentTemp`); falls back to target temp when night mode is off
      - Scroll on the pill bumps the target night temperature by a configurable step (default 500K, matches DMS's internal rounding); routed through `dms ipc call night setTargetTemp`
      - Right-click on the pill toggles night mode via `DisplayService.toggleNightMode()`
      - Left-click opens the popout panel: status, target/day temperature sliders, automation toggle, time/location mode picker, schedule readout (sunrise / sunset / next transition), quick presets
      - Quick presets row (30000–6000K in 500K steps by default) — clicking a chip persists that temperature as the new target
      - Pill auto-icon: `wb_sunny` when off, `nights_stay` when on (manual), `auto_mode` when on with automation enabled
      - Three pill format options: temp only, label + temp, icon only
      - Optional "hide pill when night mode is off" mode for users who only want the affordance when it's relevant
      - Control Center widget mirrors the built-in DMS night-mode tile: click toggles, expander shows the same detail panel as the popout (`ccWidgetIsToggle: true`)
      - Settings panel exposes scroll step, min/max range, pill format, hide-when-inactive, and verbose log gate
