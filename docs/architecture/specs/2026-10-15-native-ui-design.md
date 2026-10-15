# Plumb native UI design

## Outcome

A focused iPhone workout utility with a consistent native interface. Real measurements, clear actions, and accessible reading take priority. Preserve the camera pipeline, analysis, history, Coach, Health, Siri, awards, Watch and widget capabilities.

## Research and evidence

On 15 October 2026, retrieved all 173 pages in the repository’s HIG index successfully. Reviewed the entire topic inventory and recommendations for relevance; examined the guidance for materials, navigation, typography, colour, motion, accessibility, onboarding, notifications, privacy, workouts, widgets and Live Activities in greater depth. This is a coverage review, not a claim to have manually read all 283,487 words. The [coverage register](../../design/hig-ui-coverage.md) records every page. Apple source text is not copied into this repository.

The visual study used published interfaces, not hands-on tests of third-party apps:

| Reference | Observed pattern | Decision for Plumb |
|---|---|---|
| [Apple Fitness](https://support.apple.com/en-mide/guide/iphone/ipha5dddb411/ios) | Dominant measured values, quiet containers, consistent navigation, drill-down summaries | Show actual sets and reps; remove unimplemented scores and ornamental charts |
| [Apple Camera](https://support.apple.com/en-ie/guide/iphone/iph263472f78/27/ios/27) | Preview dominates; a small number of stable, high-contrast controls | Keep the live count and one cue legible; distinguish Start from Stop |
| [Apple Reminders](https://support.apple.com/en-euro/guide/iphone/iph2c6cf708e/26/ios/26) | System grouping and familiar rows; colour identifies purpose | Use semantic backgrounds and native list navigation |
| [Gentler Streak, 2024 Social Impact winner](https://developer.apple.com/news/?id=3m0ht22s) | Approachable workout guidance, restrained statistics, plain explanations | Describe measured progress without judgement or invented readiness scores |
| [Tide Guide, 2026 Visuals and Graphics winner](https://developer.apple.com/design/awards/) and [published screens](https://apps.apple.com/us/app/tide-guide-charts-tables/id1406371071) | Large primary measurement, compact supporting labels, charts with a real subject | Give each screen one primary task; keep visual detail tied to data |
| [2025 award selection](https://developer.apple.com/design/awards/2025/) | Lumy’s focused presentation and glanceable widgets; accessibility is part of the design criteria | Keep extensions concise and respect system appearance and motion settings |

Apple’s [materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials) separates the content surface from the navigation layer. Its [new design overview](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/) reinforces using system components to adopt the platform’s behaviour. These are functional rules, not a requirement to imitate Apple branding.

## Baseline findings

The captured Summary screen has a full-screen decorative gym image, translucent outlined cards, a custom tab bar and unavailable metrics. Those layers compete for attention. The source audit also found forced dark appearance, small fixed text, separate card styles, and incomplete destinations in primary navigation. Camera, results and secondary-page screenshots are captured in the simulator review; final evidence and limitations go in the verification record.

## Design rules

- Native TabView with Summary, Workout, History and Coach. Each tab owns its navigation stack. Settings remains in the toolbar. Preserve existing destinations and data.
- System grouped background; secondary grouped surfaces. No decorative backdrop, gradient borders or glass content cards. Native bars supply platform materials.
- System text styles. Bold numbers for measurements; regular body copy; secondary semantic text. No fixed small labels. Respect Dynamic Type and RTL.
- System blue identifies actions and selection; filled actions use a deeper blue to keep white labels legible. Green is reserved for measured activity or success, red for destructive actions and stopping. Labels and symbols carry meaning independently of colour.
- Minimum 44-point action targets. Layouts stack at accessibility sizes, content scrolls, and bottom controls respect safe areas and the keyboard.
- Short state transitions and numeric updates; Reduce Motion disables custom movement. System feedback for meaningful selections and completion only.
- Summary shows a real latest session and totals from saved sets. The empty state offers the next useful action. Awards remain available, without fake scores or pressure.
- Workout puts the chosen exercise, placement and Start a set first. Camera keeps large count, concise status and stable Start/Stop controls.
- Results use a clear measured-rep headline, grouped evidence, native navigation actions and a persistent next-set action. Retake, interrupted, error and saving-failure states remain explicit.
- Coach uses readable messages, useful suggestions and a native-style composer. Preserve model/source disclosure, move detailed explanations out of the composer’s main reading path.
- Onboarding remains skippable, gains a clear exit/back route and adaptive choices. Permission requests remain contextual. Settings/privacy use readable native sections.
- Awards, Health offer, Watch, widgets and Live Activities use the same typographic hierarchy. Notification design stays task-specific: inline status and existing Live Activity updates, no new notification permission or promotional reminders.

## Applied analysis

### Content hierarchy

Fitness gives measured activity a clear visual centre. Tide Guide uses the same principle for a different subject: the primary reading comes first, with labels and supporting detail close to it. Plumb therefore gives measured reps the strongest emphasis on Results. Summary totals come only from saved sessions; the most-reps row names its exercise. Detailed rep evidence is progressively disclosed. No posture score is inferred from an incomplete camera view.

### Navigation and actions

Camera’s visible task and stable controls informed the capture screen. The preview remains the background, Start and Stop have distinct symbols and colours, and the count stays in a predictable position. Workout is a persistent destination with a start action inside it. The native tab bar retains familiar selection behaviour and system materials. Each destination keeps its own state when a person moves elsewhere or starts a set.

### Surfaces, colour and type

Reminders demonstrates how system grouping can provide structure without a decorative backdrop. Plumb uses grouped semantic backgrounds, opaque content surfaces and a consistent spacing scale. System blue identifies actions; red identifies Stop and deletion; green remains the native toggle/success colour. Text and symbols also explain every state. System text styles establish hierarchy and adapt to Dynamic Type. The camera count is intentionally larger for viewing from a distance; the instructional illustration has a bounded height so enlarged text can still scroll into view.

### Tone and evidence

Gentler Streak’s published interface shows approachable fitness guidance without crowding the screen with statistics. Plumb keeps its language specific to recorded sets, preserves uncertainty, and avoids readiness claims unsupported by the camera. Coach’s messages remain grounded in saved facts. A short source link opens a fuller explanation, keeping both readability and disclosure. Awards recognise recorded milestones and appear after the measured result.

### Motion and ongoing feedback

Native navigation supplies its own transitions. Custom motion is limited to exercise selection, the placement demonstration, brief button feedback and changing measurements. Reduce Motion disables the custom movement. Haptics acknowledge meaningful events already supported by the app. During a set, the existing Live Activity provides glanceable count and time; this redesign adds no promotional notification or permission request.

### System integration and accessibility

The same hierarchy extends to Watch and widgets: exercise, count, time and the next action. Light/dark appearance follows the system. Larger text stacks evidence, simplifies pinned labels and expands the Health sheet. Onboarding offers a visible exit and a back action. Permissions stay attached to the relevant action; the Health prompt is optional. Native tab and list components provide standard accessibility semantics and platform adaptations.

## Acceptance

Build iPhone, widget and embedded Watch targets. Exercise navigation, set-to-result-to-history, Coach, onboarding and awards. Capture light/dark and accessibility text screens. Verify Reduce Motion handling and semantic colour use in code. Physical camera accuracy, real Watch pairing and third-party-app interaction testing remain outside this visual change.
