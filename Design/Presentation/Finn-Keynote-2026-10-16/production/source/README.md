# Current presentation sources

The checked-in delivery files and `keynote/five-minute-scenes.json` are the current five-minute presentation. Keep the source footage and `production/source-inputs` when clearing render caches.

## Film

`finn_render_film.py` is the current one-minute cut. It loads the shared image/video helpers in `finn_film_assets.py` and Apple device compositing in `finn_device_compositing.py`. Earlier standalone film cuts have been removed. The renderer uses the official Finn notification asset and a single travelling posture cue.

`finn_smooth_native.py` prepares interpolated pose observations and camera frames; `finn_smooth_export.swift` renders the native overlay. Restore the preserved portrait recording, pose JSON and cue image to the original temporary input paths used by those scripts before rebuilding. `finn_update_notification_copy.py` preserves the current notification-copy patch.

## Slides and delivery

`finn_layout_helpers.py` contains the shared typography and device layout helpers. `finn_revision7.py` records the latest full-slide choreography; the checked-in scene JSON additionally includes the native Progress follow-on and current technical notes. Do not regenerate the scene plan over those later edits without reapplying them.

`finn_scene_layers.cjs` rasterizes outlined text from the scene JSON. `finn_render_keynote_v5.py` renders the scene layers and device movies. Its version suffix identifies the renderer implementation, not an older delivery.

`finn_progress_walkthrough.py` composes the current native Progress capture into scene 7 and updates the portable deck and five-minute backup. It retains the opening film and the first part of the Watch scene. Replace the scene 7 movie in native Keynote after regenerating it.

The helpers require the Apple fonts and original rendering tools recorded in their source. They are production utilities, not a portable one-command build system. Python source is expanded with Black; Swift and browser utilities use the repository format settings.
