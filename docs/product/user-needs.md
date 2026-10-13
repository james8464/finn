# What people need from Plumb · research of 13 October 2026

Three research passes fed this page: a web review of home and bodyweight training (studies, forums, app reviews), a web review of camera-based form-feedback apps (Kemtai, Zenia, Onyx, Tempo, Peloton Guide and others), and a walkthrough of the current app as five people. The five were a beginner in a small living room, a regular gym-goer, a 65-year-old without headphones, a busy parent with 10 minutes, and an Apple Watch and AirPods owner. Commercial surveys are marked as such. Forum posts and reviews show what people say, not how many people say it. [Market research](market-research.md) covers the alternatives and the customer validation plan.

## Ranked needs

| # | Need | Evidence | Plumb on 13 October |
| --- | --- | --- | --- |
| 1 | **See progress across days**, not only inside one session: last time, and a trend across weeks | Progress-monitoring meta-analysis, 138 studies: d = 0.40 ([Harkin et al. 2016](https://eprints.whiterose.ac.uk/91437/)). Self-monitoring explained the most variation between interventions ([Michie et al. 2009](https://pubmed.ncbi.nlm.nih.gov/19916637/)). Users request this directly ([Freeletics forum](https://forum.freeletics.com/t/statistics-progress/1653)) | Comparisons pair sets from the same session only. A History row shows a date and a set count |
| 2 | **Keep going through the first weeks**: remembering, routine | Lack of time was the most common reason for dropout, 40% ([Collins et al. 2022](https://pmc.ncbi.nlm.nih.gov/articles/PMC9165469/)). Habit forming took about four sessions a week for six weeks ([Kaushal & Rhodes 2015](https://www.uvic.ca/research/labs/bmed/assets/docs/Kaushal,%20Rhodes,%202015.pdf)). Guilt and streaks push lapsed users away ([UW, lapsed Fitbit users](https://news.cs.washington.edu/2016/09/08/uw-researchers-target-fitbit-guilt); [ECIS 2019](https://aisel.aisnet.org/ecis2019_rp/90)) | No plan, no weekly count, no reminder |
| 3 | **Stay hands-free between sets**: hear the result and start the next set without walking to the phone | Requests for audio-only guidance ([Freeletics forum](https://forum.freeletics.com/t/is-there-any-audio-for-the-exercises/6036), [non-visual advancing](https://forum.freeletics.com/t/nonvisual-workout-advancing/24095)). Visual-only cues are easy to miss ([Tempo Move review](https://reviewed.com/health/content/tempo-move-review)). Audio-guided home training kept people with low vision above 95% adherence ([pilot, 19 adults](https://pmc.ncbi.nlm.nih.gov/articles/PMC13476666/)) | Speech says only "N reps measured" or "The reason is on screen". Every set needs a tap |
| 4 | **A rep count people can trust**: no extra reps while getting into position | Peloton Guide overcounting ([Pelobuddy](https://www.pelobuddy.com/guide-rep-tracking-up-july/)). A maker says false counts on getting into position were the hardest problem ([RepStandard](https://www.producthunt.com/p/repstandard/repstandard-3)). About 61% detection in a 12-set-up camera study ([Oliosi et al. 2026](https://pmc.ncbi.nlm.nih.gov/articles/PMC12978916/)) | The set window ignores walking in and out, and the CI checks that the live count never exceeds the result. Accuracy on real people is unmeasured |
| 5 | **Several exercises in one short session** | Walkthrough: switching exercise takes three taps, and the picker resets to Squat on each launch | One exercise per set flow |
| 6 | **Know whether the movement is right** without a coach | 60% did not know how to do muscle-strengthening work ([study of 81 women](https://asu.elsevierpure.com/en/publications/barriers-and-facilitators-to-muscle-strengthening-activity-among-)). Les Mills 2026 report (commercial): about half are unsure about their technique | Plumb's core: evidence-linked observations |
| 7 | **Phone placement that is confirmed to work** | Kemtai reviews: hard to adjust the camera, needs space ([Laptop Mag](https://www.laptopmag.com/reviews/kemtai-adaptive-home-exercise-platform)). Detection depends strongly on distance and angle ([Oliosi et al. 2026](https://pmc.ncbi.nlm.nih.gov/articles/PMC12978916/)) | Live joint-visibility status. No measured distance yet |
| 8 | **Visible privacy**: not recorded, nothing uploaded | Unclear camera data at Peloton ([Inverse](https://www.inverse.com/input/tech/peloton-guide-workout-cameras-homes-privacy-concerns)). Gyms restrict filming others ([Business Insider](https://www.businessinsider.nl/gyms-crack-down-on-people-filming-themselves-exercising-amid-concerns-about-privacy-and-overcrowding)) | Video stays on the iPhone. Bystanders are ignored |
| 9 | **"Not relevant" should be respected** | Walkthrough: `MistakeProfile.make` never read the person's answer | A dismissed observation could still become the focus |
| 10 | **Feedback that builds confidence**, and control over how much the app talks | Negative feedback lowers felt competence ([ECIS 2019](https://aisel.aisnet.org/ecis2019_rp/90)). Kemtai lets users lower feedback intensity ([Tom's Guide](https://www.tomsguide.com/reviews/kemtai-app)) | Every focus title names a problem. One switch for speech |
| 11 | **Readable and audible from a distance**, for older adults | Older adults need clearer guidance and simpler interfaces ([Senior Fit](https://pmc.ncbi.nlm.nih.gov/articles/PMC11691508/)) | Live count is large. Other live text is small, and the speech rate is fixed |
| 12 | **Workouts in Apple Health and the rings** | Users miss strength sessions in their rings ([Freeletics forum](https://forum.freeletics.com/t/freeletics-no-longer-synching-with-apple-fitness/22870), [Cult of Mac](https://www.cultofmac.com/547577/cult-of-mac-magazine-strength-is-the-missing-activity-ring-on-apple-watch-and-more/)) | Optional saving to Health, written and built in CI, not yet seen on a device |

Weaker or out-of-scope needs: correcting a miscounted set, easier variations (knee or wall push-ups, chair squats), gym load and rest, variety, training partners, and phone heat on long sessions.

## What came of it

Built as prototypes, reviewed, and being finished:

- **Progress across days** (needs 1 and 9). The first screen shows the last session of the chosen exercise. Each exercise gets a Progress page with weekly totals, and History lists exercises. An observation marked Not relevant no longer feeds the focus.
- **Hands-free between sets** (needs 3, 5 and 10). After a set that ended hands-free, the result is spoken and a rest counts down. The camera then reopens for the hold-still start, and the next exercise can be chosen from the result. After Stop at the phone, the short line is spoken and there is no automatic reopening.
- **Weekly plan with optional local reminders** (need 2). The person picks the days they plan to train. The first screen shows training days this week. Reminders are off by default. Permission is asked only when the person turns them on, and reminders stop after two weeks without opening Plumb. There are no streaks and no guilt wording.

Rejected, with the reason:

- **Streaks and badges.** Loss framing is linked to dropout.
- **Editing a miscounted rep.** Health, comparisons and the focus must carry measured reps only.
- **Concrete phone distances.** They need measurements on an iPhone.
- **Variations, demonstration videos, calories and load.** They need new rubrics and trainer review, or data Plumb cannot measure.

Next candidates:

- A speech rate setting and speech only through headphones (needs 10 and 11).
- Showing what counts as a rep before the first set (need 6).
- Saving to Health a session left open when the app closes (need 12).
- A physical-iPhone run that measures phone placement (need 7).
