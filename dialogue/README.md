# Dialogue ([un]becoming.exe)

Dialogic 2 timelines (`.dtl`) and characters (`.dch`) for Acts 1–2, played by the Dialogic 2.0-alpha-20 plugin in `addons/dialogic`.

To try any timeline, run `res://game_scenes/dialogue_test/dialogue_test.tscn` (F6) and click it in the list. The right side logs every signal it sends.

New timelines are picked up by name when you press Play in the editor (Dialogic rebuilds its list then).

## Layout

```
dialogue/
  characters/            one .dch per speaker
  timelines/
    act_1/dream/         ??? machine comment, the corrupted "WAKE UP" sequence
    act_1/apartment/     ghost arrives + bed, closet, TV, calendar, computer, notebook, picture frame, fridge
    act_1/monologues/    Blaire: wake up, living room, dining room, before the bus, bus glimpse
    act_1/bus/           bus still: driver (skip to school), old man, office worker, student, mother + child
    act_2/monologues/    Blaire: school gate, after the invite
    act_2/school/        classroom invite scene, friend 1-3 thoughts, glue, locked room pop-up
    shared/              bed_sleep (ending the day, once sleeping is unlocked)
    stations_placeholder/  stand-in lines for the prototype Computer/Calendar/TV station hotspots; replace with story content
```

Start a timeline by file name, e.g. `Dialogic.start("a1_fridge")`. File names are unique on purpose (`a1_`, `a2_` prefixes).

## Writing conventions

- **Ghost** comments on interactables: short, present tense, a little unsettled. Small hints of déjà vu.
- **Thoughts** (the ghost hearing someone's mind) are in italics: `OldMan: [i]...[/i]`. Spoken lines are plain.
- **SYSTEM** is for pop-ups, unlock messages and tutorials.
- **Blaire** before Act 3 calls The Order "my group" / "they". Don't name it until Act 3.
- `[pause=0.3]` for beats, `[speed=…]` and `[shake]` only for the corrupted dream voice.

## Signals (for the file system, terminal, calendar and scene code)

Every unlock is a Dialogic signal, so the timelines don't depend on anyone's code. Listen with:

```gdscript
Dialogic.signal_event.connect(func(arg): print(arg))
```

| Signal | Sent by | Meaning |
|---|---|---|
| `obtain:about:machine` | a1_dream_machine | About file: ??? Machine |
| `fx:glitch_start` / `fx:glitch_end` | a1_dream_awakening | Start/stop the glitch effect |
| `travel:apartment_bedroom` | a1_dream_awakening | Wake up in the bedroom |
| `unlock:feature:true_quest` | a1_television | TV gives quests to the ghost |
| `unlock:feature:timeline` | a1_calendar | Timeline view |
| `unlock:feature:commands_tab` | a1_computer | Commands tab in the file system |
| `unlock:command:interpret` | a1_computer | `interpret` command |
| `obtain:item:notebook` | a1_notebook | Notebook item |
| `unlock:feature:journal_files` | a1_notebook | Journal/entry files |
| `obtain:item:picture_frame` | a1_picture_frame | Picture frame item |
| `unlock:feature:picture_files` | a1_picture_frame | Picture files |
| `obtain:picture_piece:graduation_1` | a1_picture_frame | Graduation photo piece 1 of 5 |
| `unlock:feature:about_files` | a1_fridge | About files |
| `obtain:about:unknown` | a1_fridge | About file "???" (becomes The Order in Act 3) |
| `travel:school` | a1_bus_driver (choice) | Fast-forward to school, Act 2 |
| `story:haunted_house_planned` | a2_classroom_invite | The invite happened |
| `obtain:about:friend_1/2/3` | a2_friend_1/2/3 | About file for that friend |
| `obtain:item:glue` | a2_glue | Glue item |
| `unlock:command:rearrange` | a2_glue | `rearrange` command |
| `time:sleep` | shared/bed_sleep (choice) | End the day |

## Open questions for the team

- **Friend names.** `Friend1/2/3` are placeholders. To rename, change `display_name` in the `.dch` and keep the file name (the timelines use the file name).
- **Command tutorial wording** in `a1_computer` and `a2_glue` is a draft. Mike/RJ: check it against how commands actually work.
- **Story calls made while writing**, which the story lead should confirm:
  - The child on the bus calls the ghost "the see-through lady", hinting the ghost is a woman (maybe future Blaire).
  - The fridge note has "a little symbol" on it. That could become The Order's logo.
  - Blaire's online group found the haunted house for her (`a1_blaire_bus_glimpse`).
  - The friends turned down an invite before ("All three of them. Same night.").
  - Blaire has had the dream "again", hinting the loop.
  - The haunted house is "on Friday" and has "lights on the second floor". The childhood house is also two storeys, if that's meant to connect.
