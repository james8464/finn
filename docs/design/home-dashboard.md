# Home dashboard

The dashboard became Plumb's main screen on 15 October 2026. [DashboardView.swift](../../Plumb/Plumb/Home/DashboardView.swift) shows recent activity and routes people to their next set. The [Workout flow](iphone-experience-review.md) keeps its exercise picker and camera setup.

| Destination | Current behavior |
| --- | --- |
| Home | Latest saved session, Sessions link, and account settings |
| Coach | Conversation grounded in saved set summaries |
| Workout | Exercise selection and capture flow |
| Posture, Weights, Awards, Plumb+ | Clearly marked placeholders |

The tab bar uses native Liquid Glass, with opaque surfaces under Reduce Transparency. Reduce Motion removes selection animation; accessibility text sizes use one-column cards. The photo in [HomeBackdrop](../../Plumb/Plumb/Assets.xcassets/HomeBackdrop.imageset/home-backdrop.png) is decorative generated artwork, not workout footage. Debug preview data is visibly labeled and does not enter history.

[Dashboard screenshot](screenshots/2026-10-14-home-dashboard.png) · [Tab-bar screenshot](screenshots/2026-10-14-liquid-glass-tab-bar.png)

[Pull request 25](https://github.com/james8464/hackathon-project/pull/25) combined the dashboard with the existing Coach and Workout flows; its focused iOS 27 simulator run passed 400 tests. Physical-device layout and camera-flow checks remain outstanding.
