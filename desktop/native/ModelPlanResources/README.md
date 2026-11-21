# Resource plugin, native side (D324, D327)

Foundation and Darwin only: no AppKit, WebKit, child process, file write or network. The cockpit page side is
`desktop/cockpit/src/resource-plugin.ts`.

- `SystemResourceReader` reads one sample with system calls: `host_processor_info` (CPU ticks per core, deltas since
  the previous read), `host_statistics64(HOST_VM_INFO64)`, `sysctlbyname` (`kern.memorystatus_vm_pressure_level`,
  `vm.swapusage`), `getloadavg` and `statfs` on the data volume. The memory split follows Stats (Modules/RAM/readers.swift):
  used = app + wired + compressed, cached = purgeable + external. One sample takes well under 2 ms (tested).
- `ResourceCadence` / `ResourceSchedule`: column shown = its setting (2 / 5 / 10 s, other saved values snap), widget
  shown = 10 s, neither = 60 s, plugin off = no sampling. The sampler asks `ResourceSchedule.admit` before every read.
- `ResourceSampler`: one coalesced one-shot GCD timer on the main queue (leeway 10 % of the interval, at least 0.2 s),
  the ten-minute `ResourceHistory` (memory only; dropped when the plugin is turned off), the widget `ResourceReadout`,
  and `ResourceRedrawGate` (redraw only on a ≥ 1 percentage-point change or a readout change). `ResourceFace.animates`
  is false under Reduce Motion.
- `ResourceReadout`: "内存 47%" normally (the widget draws the number alone, "47%", and VoiceOver reads "内存 47%"; owner 11-21); "CPU 96%" once CPU has stayed ≥ 70 % for 20 s; red from 90 %; back to memory
  after 30 s below 60 %. Memory's tone follows macOS memory pressure. The ring never changes colour.
- `ResourceCard`: hover-card rows CPU · 内存 · 磁盘; the row matching the readout at full ink, the others at
  secondary ink (variant A); a tint only on problem rows (pressure high, CPU ≥ 70 %, disk ≥ 90 %).
- `ResourcePagePayload` / `ResourcePageFeed`: the page's `pluginData` body; the whole window when the column starts
  running, then only newer samples.

The widget ring maps onto the subscription ring's two arcs (ModelPlanDock `DockInstrumentReading` outer = memory with
a faint cached segment, inner = CPU) and the card onto `DockCardRow`; that wiring and the cockpit bridge's
`pluginsRunning` / `pluginData` messages live in the app integration.

```sh
swift test --package-path desktop/native/ModelPlanResources
```
