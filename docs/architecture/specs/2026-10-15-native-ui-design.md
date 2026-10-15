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
- System background; secondary semantic surfaces. No decorative backdrop, gradient borders or glass content cards. Native bars supply platform materials.
- System text styles. Bold numbers for measurements; regular body copy; secondary semantic text. No fixed small labels. Respect Dynamic Type and RTL.
- Monochrome actions and selection invert with system appearance. Green is reserved for measured activity or success, red for destructive actions and stopping. Labels and symbols carry meaning independently of colour.
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

Reminders demonstrates how system grouping can provide structure without a decorative backdrop. Plumb uses semantic backgrounds, opaque content surfaces and a consistent spacing scale. Monochrome controls identify actions; red identifies Stop and deletion; green remains the native toggle/success colour. Text and symbols also explain every state. System text styles establish hierarchy and adapt to Dynamic Type. The camera count is intentionally larger for viewing from a distance; the instructional illustration has a bounded height so enlarged text can still scroll into view.

### Tone and evidence

Gentler Streak’s published interface shows approachable fitness guidance without crowding the screen with statistics. Plumb keeps its language specific to recorded sets, preserves uncertainty, and avoids readiness claims unsupported by the camera. Coach’s messages remain grounded in saved facts. A short source link opens a fuller explanation, keeping both readability and disclosure. Awards recognise recorded milestones and appear after the measured result.

### Motion and ongoing feedback

Native navigation supplies its own transitions. Custom motion is limited to exercise selection, the placement demonstration, brief button feedback and changing measurements. Reduce Motion disables the custom movement. Haptics acknowledge meaningful events already supported by the app. During a set, the existing Live Activity provides glanceable count and time; this redesign adds no promotional notification or permission request.

### System integration and accessibility

The same hierarchy extends to Watch and widgets: exercise, count, time and the next action. Light/dark appearance follows the system. Larger text stacks evidence, simplifies pinned labels and expands the Health sheet. Onboarding offers a visible exit and a back action. Permissions stay attached to the relevant action; the Health prompt is optional. Native tab and list components provide standard accessibility semantics and platform adaptations.

## Acceptance

Build iPhone, widget and embedded Watch targets. Exercise navigation, set-to-result-to-history, Coach, onboarding and awards. Capture light/dark and accessibility text screens. Verify Reduce Motion handling and semantic colour use in code. Physical camera accuracy, real Watch pairing and third-party-app interaction testing remain outside this visual change.

## Refinement requested after visual review

James found the first native pass too flat and asked to restore the earlier dashboard’s widget concept. Keep this iteration isolated on `ui/apple-native-revamp`; do not merge it into main while teammates explore alternatives.

- Build a composed Summary with an illustrated workout tile, a measured-activity widget, a recent-session card and compact Best set/Awards widgets. Use differentiated layouts tied to each measurement.
- Use hierarchical SF Symbols, exercise drawings and quiet surface separation. Preserve real data, meaningful empty states, light/dark appearance and accessibility layouts.
- Native large titles collapse on scroll and expand at the top. Make the primary scroll view the root content; keep actions and the Coach composer in safe-area insets.
- Preserve tab position and navigation, show press/selection feedback, and keep keyboard submission consistent with the Send button’s enabled state. Respect Reduce Motion and Reduce Transparency.
- Review screen behaviour as well as screenshots: scrolling, title transitions, selection, keyboard, sheets, capture, result actions, deletion and return navigation.

### Visual comparison, 15 October refinement

Inspected rendered screenshots in the browser, not just app descriptions:

| Reference | Observed screen detail | Application to Plumb |
| --- | --- | --- |
| [Apple Fitness Summary](https://support.apple.com/en-ie/guide/iphone/iph4c34a8a95/ios) | A wide activity card, paired compact metrics and a photographic workout card. Different content has different composition. | An exercise-led workout card, weekly activity, compact Best set/Awards and a recent session. |
| [Apple Health Highlights](https://support.apple.com/en-us/104997#progress) | Category symbol and colour, a short observation, then its supporting chart or measurements. | Clear category headings; measured reps and dates remain more prominent than decoration. |
| [Apple Journal](https://apps.apple.com/us/app/journal/id6447391597) | Photos and maps make entries recognizable; compact insight cards sit above ordinary lists. | Use the selected exercise drawing as recognizable content. Settings and History retain native lists. |
| [Gentler Streak, 2024 winner](https://developer.apple.com/news/?id=3m0ht22s) | Workout symbols, a distinctive illustration and a readable activity chart. Illustration supports the app's friendly purpose. | Plumb's own camera-pose illustration supplies identity. No borrowed mascot or unsupported readiness judgement. |
| [Lumy, 2025 finalist](https://apps.apple.com/us/app/lumy/id908905093) | A large sun-path visual, small event rows and widgets whose visual forms reflect their data. | Give exercise imagery room; make activity charts functional and keep secondary information compact. Lumy is a finalist, not an ADA winner. |

These are visual observations of published screens, not claims that we tested those apps' live interactions. Earlier research also covers Camera, Reminders and Tide Guide. Apple's [2025 award page](https://developer.apple.com/design/awards/2025/) confirms Lumy's finalist status.

### Avoiding generic generated-interface defaults

[Anthropic's frontend-design guidance](https://github.com/anthropics/skills/tree/main/skills/frontend-design) identifies repeated generated-design habits: interchangeable rounded cards, decorative gradients, uppercase eyebrow labels, and unnecessary entrance animations. This is practitioner guidance, not a validated way to detect AI authorship. Its web-specific typography advice does not justify replacing San Francisco in a native iOS app.

For this pass:

- Remove marketing headlines and repeated explanatory paragraphs.
- Give each widget a reason to exist, a truthful state and one clear destination.
- Use the exercise illustration, actual daily rep counts and earned awards as visual content.
- Keep colour tied to actions or categories. Preserve semantic light/dark surfaces.
- Use native navigation, selection feedback and press feedback; respect Reduce Motion.
- Leave empty charts empty. No invented activity, progress rings, streaks or scores.
- Verify native large-title collapse and expansion, tab-state retention, large text, French labels and keyboard-safe actions.

Development stays on `ui/apple-native-revamp`; PR 26 is a draft. Main and teammates' UI branches remain independent.

### Attention and copy pass

James rejected “A week at a glance” as unnecessary. The revised hierarchy puts the workout action first, then measured activity. Removed the hero subtitle, the extra Coach heading and the empty Recent workout widget. Empty Summary has one short “No saved sets” message; Best set identifies its exercise and Awards offers “View milestones”. Privacy details remain at the camera decision and in Settings. Retain dates, units and source disclosures because they change how people interpret the data.

[NN/G's comparative evaluation](https://www.nngroup.com/articles/ai-prototyping/) found weak grouping, competing styles and unnecessary emphasis on secondary content in generated prototypes. This supports checking attention and task relevance, beyond banning a particular colour or card shape. The evaluation concerns specific tools and scenarios, not all generated interfaces.

### Final visual choice: monochrome

After reviewing the coloured widgets, James preferred the earlier black-and-white Plumb screen. This supersedes the blue-accent exploration. Keep the larger white exercise drawing on black, strong system typography, grey secondary widgets and inverse capsule actions. Fitness informs the compact information layout; Plumb's camera-pose drawing provides its own visual identity. No stock photos, decorative shadows or multicolour dashboard tiles.

Summary contains a static exercise illustration, seven-day rep chart, paired Best set/Awards widgets and a Recent workout card only when history exists. Workout retains the animated placement demonstration, disabled with Reduce Motion. Chart bars are centred on local calendar days; VoiceOver receives all seven values. Accessibility sizes stack widgets and chart content.

Use native automatic title display on Summary. Forcing large-title mode caused the title to expand on tab return and shifted the content. Regression checks cover title collapse, expansion and scroll position after switching tabs at normal and accessibility text sizes. Workout actions and the Coach composer use safe-area insets. Coach rejects empty or concurrent submissions before clearing the draft.

## Superseding refinement: Théophile + monochrome

James and teammates requested the monochrome design combined with Théophile’s green theme and custom background. James explicitly chose to restore Home, Posture, Coach and Workout (+). This supersedes the earlier four-tab labels and the monochrome-only accent rule above.

Recovered `origin/design/visuals-tabs` at `c0ffdff`; original dashboard commit `536d3ba`. Reuse its artwork in greyscale with an appearance-dependent wash, and its tab order, symbols, floating capsule and lime selection. Keep native TabView stacks behind the custom bar so tab switches preserve state. Posture displays saved measured reviews; History remains available through Home activity, Settings and Workout’s menu.

Keep current exercise drawings and compact widgets. Lime marks selection and small action details; activity bars use a darker accessible green in light appearance. Respect reduced transparency/motion, stack larger-text content and hide the tab bar while typing. Verify navigation, title/scroll state, saved-session flow, French, dark appearance and keyboard layouts.

## Original design restoration (supersedes hybrid)

James requested Théophile’s original design from `design/visuals-tabs` (`c0ffdff`): full-colour background, lime invitation/demo, glass dashboard cards, scrolling header and original tab styling. Retain newer functionality and navigation state. Fix tab text scaling with the same default 11-point appearance; verify full setup audits, navigation, demo isolation, larger text and signed phone deployment before publishing.
