# Caffeinate UI award badge artwork

Twelve distinct transparent PNG medallions in the approved chronological order, ending with Caffeine Overdose at 365 days. Their exact titles, ranks and thresholds are in catalog.json. One day means 24 hours.

Names and times are deliberately separate from raster artwork, so native labels remain legible and accessible. Each PNG is an individual image with transparent padding; use aspect-fit sizing when displaying it.

Generated using the built-in image_gen tool, with First Sip as the style reference. The exact prompt set is retained in prompts.json. The app self-test verifies that all twelve images decode.

The app bundles the twelve PNGs and catalog.json. The native Awards window uses this catalog for labels and thresholds. Earned IDs persist locally; current qualifying CLI session time also counts, including recovered time that may contain sleep. See the [Caffeinate UI README](../../../README.md#timer-and-awards) for counting rules.

## Badge gallery

| Badge | Award | Session threshold |
| --- | --- | --- |
| <img src="first-sip.png" width="96" alt="First Sip" /> | First Sip | 5 minutes |
| <img src="espresso-yourself.png" width="96" alt="Espresso Yourself" /> | Espresso Yourself | 1 hour |
| <img src="just-one-more-cup.png" width="96" alt="Just One More Cup" /> | Just One More Cup | 4 hours |
| <img src="the-daily-grind.png" width="96" alt="The Daily Grind" /> | The Daily Grind | 8 hours |
| <img src="certified-all-nighter.png" width="96" alt="Certified All-Nighter" /> | Certified All-Nighter | 24 hours |
| <img src="decaf-is-a-myth.png" width="96" alt="Decaf Is a Myth" /> | Decaf Is a Myth | 3 days |
| <img src="sleep-is-a-rumor.png" width="96" alt="Sleep Is a Rumor" /> | Sleep Is a Rumor | 7 days |
| <img src="bean-there-done-that.png" width="96" alt="Bean There, Done That" /> | Bean There, Done That | 14 days |
| <img src="your-mac-is-legally-a-cafe.png" width="96" alt="Your Mac Is Legally a Café" /> | Your Mac Is Legally a Café | 30 days |
| <img src="roast-level-critical.png" width="96" alt="Roast Level: Critical" /> | Roast Level: Critical | 60 days |
| <img src="legally-an-espresso-machine.png" width="96" alt="Head Barista" /> | Head Barista | 90 days |
| <img src="caffeine-overdose.png" width="96" alt="Caffeine Overdose" /> | Caffeine Overdose | 365 days |

The 90-day Head Barista award retains its original `legally-an-espresso-machine` ID and filename to preserve earned progress.
