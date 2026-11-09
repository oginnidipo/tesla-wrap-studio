# Implicit State Machines & Unenforced Invariants — Audit (`/Users/dipo/code/WrapStudio`, v2.0)

Generated 2026-11-08 from a full read of the app target. Each item lists: what relies on it, how it's enforced (if at all), and the concrete failure that happens when it isn't.

## A. Implicit state machines

### A1. The save pipeline (`EditorSession`)
States the code moves through: `saved → hasUnsavedChanges(+saveState=.saving) → (350ms debounce) → saved | .failed`, with two bypass flags: `canPersist = false` (record unreadable) and `needsLegacyMigration` (pre-migration design). This is a 4-flag intersection implemented as `@Published` state plus three private booleans — no single owner.

Not enforced:
- **Painting is not blocked when `canPersist == false`.** `scheduleSave()` and `persistNow()` early-return, but the editor UI keeps `drawingGestureRecognizer` enabled. Result: the user paints on an "unavailable" design, sees `Save failed`, and every edit is silently discarded on close. Enforce: set `isDrawingEnabled = canPersist && !needsLegacyMigration` in `TemplatePaintSurface.updateUIView` / `PaintCanvas`.
- `saveState == .saving` can be left dangling if `persistNow()` throws before touching `saveState` on a cancelled-task race; there is no "settle to saved or failed within N ms" watchdog.

### A2. The edit/undo machine (`EditorSession`)
States: no edit open (`editStart == nil`) → gesture in progress (`editStart = snapshot`) → committed (`undoHistory` appended, `redoHistory` cleared).

Not enforced:
- Every mutation must be bracketed by `beginEdit`/`finishEdit`. Enforced only by *convention* — the compiler can't see it. `mirrorStrokes(from:)` mutates without its own bracket and depends on the coordinator's commit task. A new call site that edits and forgets the bracket produces a silently missing undo entry.
- **`restore()` can corrupt history.** It pops from `undoHistory` *before* trying `PKDrawing(data:)`; on decode failure the popped entry is gone and the session keeps the current state. Swap the order: restore-then-pop (make `restore` throwing, pop on success only, leave `editStart` untouched on failure).
- "One history entry per gesture" relies on an 80 ms quiescence timer (`commitAfterDrawingSettles`). Two gestures inside 80 ms merge into one undo step; one gesture split by the timer yields two. Acceptable, but it's a *timer-defined* invariant, not a gesture-defined one.
- Memory: `historyLimit = 60` counts *entries*, not bytes; each entry embeds full `PKDrawing` data. 60 fat strokes can be tens of MB.

### A3. The drawing echo loop (session ⇄ `PKCanvasView`)
States: applied (`appliedDrawingData == canvas.drawing`) / dirty / re-applying (`isApplyingDrawing`). The loop is broken by *byte-equality of serialized drawings* and a `isApplyingDrawing` flag — two fragile comparisons.

Not enforced:
- **`updateDrawing` does not bump `drawingRevision`.** The canvas re-applies session artwork only when `scale` or `appliedRevision != session.drawingRevision` changes. Any future code path that mutates `session.drawing` outside a gesture without bumping `drawingRevision` leaves the canvas showing stale art until the next scale change. `mirrorStrokes` and `clear()` bump it by hand today — again, convention only. Enforce: bump `drawingRevision` inside `updateDrawing` itself (or make `drawing` a private(set) with a mutation API that always bumps).
- **Strokes before first layout are dropped.** `synchronizeDrawing` guards `displayScale > 0`; between `makeUIView` and the first `layoutSubviews` any drawing-change callback is ignored. Window is tiny but real (fast programmatic loads).
- **Rotation/scale change during an active stroke** re-applies `session.drawing` (old state) into the canvas — an in-progress stroke can be discarded mid-gesture on iPad rotation/split-view resize.

### A4. Sticker selection
States: none / selected(id). Deselected on: tool begin, tool switch to fill, export, delete, clear; validated after undo/redo. Not enforced:
- `transformSticker`/`flipSticker` with a stale id no-op silently (fine), but **selection itself is never re-validated on stickers array replacement** outside `restore()` — a future bulk edit could leave `selectedStickerID` pointing at nothing; `selectedSticker` returns nil but the UI still shows selection-dependent hints. Cheap fix: `didSet` on `stickers` (or a computed re-check in the few writers).

### A5. The untouched-design lifecycle (`DesignLibrary.untouched`)
States: created → (editor closed with artwork → kept | without → deleted). Not enforced:
- **App killed while a brand-new empty design is open** skips `editorClosed` → gallery keeps an empty design forever. (Low harm, but it's the one state where "delete on close" is load-bearing and lifecycle-dependent.)
- `hasLoaded`/`load()` is idempotent only if `importLegacyAutosaves` succeeded; if import throws, markers may still have been written per-car *before* the error — partial import + `hasLoaded = true` = never retried (mixed with A8).

### A6. Save vs. process death
`close()` on scenePhase change and `onDisappear`; 350 ms debounce otherwise. Invariant "all edits reach disk before iOS kills the process" is **not guaranteed** — a user who draws and swipes the app away within 350 ms loses the last stroke. Enforce: `persistNow()` (or an immediate save of *drawing only*) synchronously when the app resigns active.

### A7. Thumbnail freshness
Invariants: `thumbnail content mtime ≥ record.modifiedAt`. Relies on filesystem mtime precision — content-modification dates on APFS are fine, but this is a *filesystem-trust* invariant with no self-heal if it fails other than regenerating in `loadThumbnail`.

### A8. Legacy import one-shot marker
`importMarkerURL` records "seen", applied **even when the autosave failed to decode** — an unreadable draft is skipped and can never be retried. "Seen once" ≠ "imported". If partial-failure recovery matters, only insert into the marker after a successful import of that car.

### A9. Export layering order
The final composite is an ordered pipeline: white → template → global fill (clipped) → panel fills → strokes (clipped to mask) → stickers (clipped) → overlay. Enforced by call order inside `render`; nothing structural prevents a sticker drawn after the overlay. If someone re-orders to "stickers over trim" the app still visually works but exports stickers on windows — the exact bug class that motivated the mask. A golden-image test per car would pin this.

### A10. Asset completeness (`Car` enum ↔ bundle assets)
`Car.template/maskImage/overlayImage/templateSize` is a hand-maintained map over 5 assets × 12+ cases. Missing artwork throws `missingArtwork` only when a render is requested; a wrong `templateSize` (must exactly equal the PNG's pixel dims or fills/masks mis-align) is checked **nowhere**. Enforce with a unit test: for every `Car.allCases`, assert the four images decode and their sizes equal `templateSize`.

## B. Invariants relied on but not enforced

1. **Template-pixel coordinate space.** Everything (strokes scaled by displayScale, stickers in template px, `PanelFill` points, mask clipping, export) assumes one shared pixel space per car. Nothing validates that a loaded `PanelFill` still lands inside a panel after art updates — `fillPanel` *cleans* such orphans incidentally, but a stale fill from disk renders through `map.image(colors:)` via `resolvedColors` (check `PanelMap.image` handles unknown points; orphans simply don't paint, silently).
2. **Sticker file liveness.** Designs reference `Stickers/<file>.png`. `WrapRenderer.render` skips missing stickers (`continue`) — a deleted/renamed sticker silently vanishes from a saved design at export time. `StickerLibrary.remove` exists but no UI deletes stickers — if it ever ships, it must check references across all designs first (currently unchecked, latent cross-design data loss).
3. **Traversal safety** is enforced (`name == lastPathComponent`) — good — but the NSCache is unbounded and shared; fine, noted for completeness.
4. **PNG spec:** ≤ 1,000,000 bytes; ≥ 512 px per side; ≤ 30-char filename; ASCII-only stems. `encodePNG`'s ladder covers size; if the *source* is already < 512 px (Cybertruck is 768, fine — but a future template could be smaller), `minimumScale > 1` makes the ladder empty → `oversizedExport` thrown even though the image is trivially under 1 MB. Enforce: accept unchanged small images below the scale ladder.
5. **Filename fallback determinism:** names with only emoji → timestamp stem — two exports in the same second from the *same* design can collide `…-HHmmss.png` (Tesla side may reject duplicates; low risk).
6. **`uniqueName` O(n) disk re-reads** (`records()` per candidate) — fine at current scale.
7. **`WrapDesign.version ∈ 1...currentVersion`** is enforced at load; version 1 files are accepted with defaults. No writer for a v1→2 migration of *panel fills* — fine because v1 had none. If v3 ever needs migration, `loadDesign` is the single choke point — document the migration invariant now.
8. **Undo/redo history is not persisted** — leaving the editor clears it. Kids lose undo when reopening. Intentional presumably; worth a README line.
9. **`PanelMap.cache` grows one map per car forever** (4 × 1 MP arrays ≈ tens of MB); all 12 cars opened → ~100–200 MB resident. Invariant "maps are small enough to keep" is unenforced and per-trim masks share nothing.
10. **`editorClosed` ordering:** `close()` (persist → callbacks) runs before `library.editorClosed(record, hasArtwork:)` in `onDisappear`. If SwiftUI ever changes `task(id: scenePhase)` vs `onDisappear` ordering during the same dismissal, a double-`close()` is harmless, but the *untouched-delete* decision could see stale `hasArtwork`. Cheap fix: snapshot `hasArtwork` at persist time.
11. **`stickerSide` bounds (40…1024) and center clamping [0…templateSize]** allow a sticker half off-canvas (center clamped, not bounds). Cosmetic; consistent between screen and export.
12. **`toolBeforeEraser` can go stale across fill→eraser sequences** (fill is skipped as a restore target by design, so pencil double-tap from fill returns `.pen`).

## C. Top fixes ranked (what I'd change first)

1. **Disable drawing when `canPersist == false`** (A1) — silent edit loss is the worst user outcome.
2. **Restore-then-pop in undo/redo** (A2) — one-line corruption fix.
3. **Bump `drawingRevision` inside `updateDrawing`** (A3) — makes the echo loop safe for future call sites.
4. **Flush save on `scenePhase != .active` synchronously** (A6) — kills the 350 ms loss window.
5. **Asset completeness test for every `Car`** (A10) — turns "add a 13th body style" from a manual checklist into a test failure.
6. Golden-image export test per car (A9) — pins the render order forever.

*Audit generated by Egg — reads: EditorSession, DesignStore, DesignLibrary, WrapRenderer, TemplatePaintSurface, TemplateHostView, PaintCanvas, PlacedStickerView, StickerLibrary, TextSticker, PanelMap, CanvasGeometry, WrapDesign.*
