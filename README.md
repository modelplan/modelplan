Evidence for modelplan/modelplan#712 only. Never merge.

Headless Linux WebKit renders of the official cockpit page with synthetic data (visual fixture), not device evidence.
The scaled shots render the 636 x 911 page at device scale 2 x scale, the Retina equivalent of WKWebView pageZoom.

- before-1470x956-dock-compact-100: what the M2 Air shows today with the Dock at the bottom (short version).
- after-1470x956-dock-full-92.5: same screen after #712 (full, 843/911).
- after-1440x900-dock-full-87.8: 13-inch M1 Air with the Dock at the bottom (800/911).
- after-80-percent: Settings "Cockpit size" 80 %.
- after-minimum-75: the lowest scale that still shows the full cockpit.
- hull-current-full-100: the full page at 100 % on #697's head: c01 canopy present, no hull plate, no base bells or flames (CKP-SHELL-25, art not released).

D60 (11-08): 85 % is the default. after-default-85: the full page at 85 % (1470x956 and 1440x900 with the Dock
at the bottom both draw at 85 %). after-1470x956-dock-full-92.5 and after-1440x900-dock-full-87.8 now show the
100 % choice on those screens; after-80-percent and after-minimum-75 are unchanged.
