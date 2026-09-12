# Custom additions to AP_histology

Everything in this folder is additive — upstream has no `custom_functions/`,
so `git pull` from `petersaj/AP_histology` never conflicts with it.

- `clean_tiffs.m` — OME-TIFF directory-count fixer, called by
  `AP_histology.m` on load. Previously lived outside the repo in
  `NP-Analysis/matlab_functions/`, which made a clean checkout fail at
  `load_images`. **Remove that folder from your MATLAB path** so the old
  copy can't shadow this one.
- `+dlh/` — figure export (below).

---

# Figure export for AP_histology (`+dlh`)

Export aligned histology for figures — a full-resolution image with your
current colour settings, and the CCF boundaries + annotations as **real
vectors** in an SVG. No print-screens.

Everything lives in `custom_functions/+dlh/`. **No upstream file is
modified**, so `git pull` from `petersaj/AP_histology` can never conflict
with this. The menu is injected into the AP_histology figure at runtime.

## Install

`custom_functions` needs to be on the MATLAB path. If you install with
`addpath(genpath('...\AP_histology'))` it already is. Otherwise:

```matlab
addpath('C:\path\to\AP_histology\custom_functions')
```

Check it works (no images or atlas needed):

```matlab
dlh.selftest
```

That writes a test SVG to your temp folder and opens it — the outlines
should sit exactly on the shapes.

## Use

```matlab
dlh.histology          % instead of AP_histology - launches it and attaches the menu
```

or, if AP_histology is already open:

```matlab
dlh.attach
```

Either way you get an **Export (figures)** menu:

- **Export image + vectors…** — the options dialog
- **Quick export: current slice** — defaults, no dialog
- **Open export folder**

Do the alignment as normal, then export. Output goes to
`<image folder>/figure_export/` by default.

## What you get

Per slice, `<prefix>_slice05_…`:

| File | What it is |
|---|---|
| `_channels.tif` | **Raw per-channel stack for Fiji** — full bit depth, rigid transform applied, *no* colour limits baked in |
| `_image.png` | Histology at full resolution, exactly the channel colours and min/max you have set, no overlay |
| `_overlay.png` | Same, with the CCF and annotations burned in (optional) |
| `_vectors.svg` | CCF outlines + annotations only, transparent background |
| `_combined.svg` | The above, with the histology embedded — one self-contained file |

`_image.png` and `_vectors.svg` are the same pixel dimensions with a
matching SVG `viewBox`, so dropping both into Illustrator lines them up
exactly. Use the combined SVG if you'd rather carry one file around.

### The channel stack (`_channels.tif`)

The rasters above are 8-bit RGB with your current min/max already burned in
— fine as a figure panel, useless for adjusting afterwards. `_channels.tif`
is the opposite: one page per channel, native bit depth (usually uint16),
straight out of `gui_data.data` with only the rigid transform applied. No
scaling, no clipping, no compositing.

So the workflow is: align in AP_histology, export the stack, and do all the
brightness/contrast work in Fiji where it's responsive. It carries ImageJ
hyperstack metadata, so Fiji opens it as a composite with the channels
already separated. A `_channels.txt` sidecar lists which page is which,
each channel's colour, and where the gui sliders were sitting.

Because it comes straight from the loaded data, exporting it needs **no
redraw at all** — with only this box ticked, nothing in the gui repaints.
That's the fast path when AP_histology is crawling over a remote session.

The geometry matches `_image.png` and `_vectors.svg` exactly, so an overlay
exported alongside still lines up on the Fiji-adjusted image.

Every CCF structure arrives as its own group **named by acronym** (`PO`,
`SSp-ul`, …), with the full name in a `<title>`, so you can select and
restyle one region in Illustrator without hunting. Annotations are grouped
by their label, and annotation labels are live editable text on their own
layer.

## The options that matter

**CCF detail (depth)** — `0` outlines every region the GUI draws, which on a
coronal slice is hundreds of paths. Set a depth to merge each region into
its ancestor in the Allen structure tree:

- `2–3` — major divisions (Isocortex, TH, HPF…)
- `5–7` — the level you usually want in a figure (PO, VPM, SSp-ul…)
- `0` — everything, as displayed

**Simplify edges** — pixel masks give staircase outlines. This is the
Douglas–Peucker tolerance (`reducepoly`), `0`–`1`. `0.001` is a good
default; `0` keeps every pixel step; `0.005`+ gets visibly loose.

**Fill regions** — `0` gives outlines only. Above `0`, each structure is
filled with its Allen CCF colour at that opacity.

**Outline / annotation colour** — any hex, e.g. `#FFFFFF`, `#000000`.

## Scripting it

The dialog is a thin wrapper. Everything is available directly:

```matlab
gui = dlh.find_gui;

% All slices, figure-level CCF regions, black outlines on white
dlh.export_slices(gui, ...
    'Slices', 1:12, ...
    'CollapseDepth', 6, ...
    'AtlasStroke', '#000000', ...
    'AtlasStrokeWidth', 1.5, ...
    'OutputDir', 'C:\figures\case01');

% Only the regions you care about, filled with CCF colours
dlh.export_slices(gui, ...
    'IncludeRegions', ["PO","VPM","SSp-ul"], ...
    'AtlasFillOpacity', 0.3);
```

Lower-level pieces, if you want to build something else:

| Function | Does |
|---|---|
| `dlh.render_slice` | Full-res composited RGB for the current slice, overlays on/off |
| `dlh.atlas_contours` | Aligned CCF label image → vector outlines per structure |
| `dlh.annotation_shapes` | Annotations for a slice as vector shapes |
| `dlh.write_svg` | Contours + shapes (+ optional embedded raster) → SVG |
| `dlh.export_slices` | Ties it together and writes files |

## Notes / gotchas

- The exported image is the **rigid-transformed** slice (rotate/translate/flip
  applied), because that is the one the atlas is aligned to. It matches what
  the GUI shows, not the raw TIFF on disk.
- Each structure is a **complete closed shape**, so a border shared by two
  regions carries two coincident paths (one per region). That's what makes
  each region individually selectable and fillable. It only shows if you set
  a semi-transparent stroke — solid strokes look identical.
- Outlines trace the boundary *pixels*, the same pixels the GUI paints white,
  so at `SimplifyTolerance = 0` the SVG sits exactly on the GUI overlay.
- CCF boundaries need the aligned atlas loaded (Atlas → Choose slices →
  Align). Without it you'll get a warning and annotations only.
- `reducepoly` (Image Processing Toolbox) does the simplification; if it's
  missing, outlines are written unsimplified rather than failing.
- Big slices produce big files. A full-resolution Neuropixels slide at CCF
  detail `0` can be a few MB of SVG — raise the depth or the simplify
  tolerance if Illustrator struggles.

## How it stays merge-proof

- All code is in `custom_functions/+dlh/`, a folder upstream doesn't have.
- The menu is added at runtime by `dlh.attach`, not by editing `AP_histology.m`.
- `dlh.render_slice` doesn't reimplement the colour compositing — it flips
  the View menu, asks AP_histology to redraw, and reads the image `CData`.
  If upstream changes how images are built, this follows automatically.
- The only assumptions about upstream internals are: the figure is named
  `AP histology`; `gui_data.update` is the redraw handle; the View menu has
  items matching "atlas" and "annotation"; and `gui_data.curr_atlas_slice`
  holds the aligned CCF label image. If a pull breaks the export, those are
  the four things to check.

Suggested git setup so pulling is routine:

```bash
git remote add upstream https://github.com/petersaj/AP_histology.git
git fetch upstream
git merge upstream/master     # custom_functions/ is never touched
```
