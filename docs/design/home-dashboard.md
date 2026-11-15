# Finn screens

What each main screen contains. For colour, type and voice, [the brand system](../../Design/README.md) wins.

## Home
- A scrolling Home/account header, then the Finn card, Last workout, Posture, Best set, Sessions and Awards cards.
- The Finn card shows Try Finn and the demo until the person has tried Finn, then Finn speaking as the coach: an F badge, the next workout (day · time · intensity) and one quoted line of encouragement, a different one each time Home appears. The switch is a temporary trigger (`FinnFirstTryTrigger.swift`) until the real first-try flow.
- Keep useful labels and measured facts; omit motivational headings and repeated explanatory subtitles.
- The Posture card always opens Progress on Posture, on the exercise it shows.

## Tab bar
A glass bar with Home, Progress, Coach and Workout (dumbbell), a selection capsule and the default label size. Stable dark fills keep label contrast predictable. Each tab keeps its own navigation stack.

## Progress
Two sections behind a segmented control, for one chosen exercise:
- **Posture:** the illustrated movement, how to move, the wrong-and-right photo moments (an empty state while Finn keeps no camera images) and the measured set review.
- **Strength:** the best set per session as a solid line, with a dashed projection (the least-squares trend of the last 8 sessions carried 4 weeks on), shown after 3 training days.

## Workout
A square next-workout card (the same `FinnCoachMessage` as Home's coach card), then previous workouts, and a floating Launch workout button. Launch workout pushes the setup screen, never the camera directly. The illustrated demo neither records nor saves sample workouts.

## Supporting screens
Dark grouped surfaces and native controls. Options has one grouped Form section per preference category; privacy topics expand in place. Workout setup, results, Coach and Posture share typography and opaque content surfaces. Bottom actions stay above navigation.

## Always
- Unavailable posture scores stay blank. Sample values appear only in explicitly labelled previews.
- Respect Reduce Motion. Keep each tab's navigation stack, saved data, localization, keyboard dismissal and camera and privacy behaviour.
