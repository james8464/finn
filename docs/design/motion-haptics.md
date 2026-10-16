# Motion and haptics

- Animate a state change only when it clarifies what changed. Keep routine changes under 300 ms; avoid looping decoration and full-screen movement during navigation.
- Check `AppMotion.reduces(_:)` before custom transitions. With Reduce Motion on, update content immediately. Keep loading and progress information available without animation.
- Use `FinnHaptics` for custom controls. It honors Options → Haptic feedback (Off, Gentle, Regular). Native controls already provide system feedback; do not add a second cue.
- Use selection feedback for a deliberate choice, and success feedback for a completed milestone. Never fire a cue on a failed or disabled action, or just because a view redraws.
- Keep visual and tactile feedback synchronized. The app must remain usable without haptics.

Apple references: [Motion](https://developer.apple.com/design/human-interface-guidelines/motion) · [Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)
