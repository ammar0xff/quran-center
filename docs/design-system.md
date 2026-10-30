# Design system

One visual identity across the three roles, light mode only (dark mode is deferred).

## Principles
- **Restraint.** One signature shape, one accent, no decoration without a job.
- **Words, not colour alone.** Every mark (ممتاز … إعادة) and level shows its word; the colour ramp only supports it.
- **Real data only.** Streaks, levels and counts are computed from stored records; with no records the UI says so.

## Tokens (`lib/core/theme/design_tokens.dart`)
| Role | Value |
| --- | --- |
| Emerald (primary) | `0E5A47`, night `0A3A30`, button face `168A57` |
| Gold (surah names, rosettes only) | `B8893B` |
| Page / surface / border | `F3F6F2` / white / `DDE6DF` (1.5px) |
| Marks | ممتاز `1E9E63`, جيد جدًا `6BA43A`, جيد `D9A21B`, مقبول `E07B2A`, إعادة `CF4B3F` |

Type: **IBM Plex Sans Arabic** for the interface, **Amiri** for surah names and the basmala (both SIL OFL, bundled in `assets/fonts`).

## Components (`lib/design_system/components`)
- `Rosette`: the ayah-end medallion of a mushaf. Carries a number, an initial or an icon (levels, steps, surah numbers, avatars).
- `LatticePainter` / `AppHero`: faint eight-point-star lattice behind the emerald header of each home screen.
- `DayPath` / `PathStep`: the student's tasks as a path; the step to do now is filled and carries the action.
- `GradeChip`, `LevelBadge`, `SectionTitle` (`marks.dart`): mark pill, level rosette, section heading with a gold rule.
- Chunky buttons: the theme wraps every Filled/Elevated/Outlined button in a flat face on a darker edge that sinks when pressed (`app_theme.dart`).

## Not done
- Dark mode.
- Restyling of the secondary director/teacher forms beyond the theme (they inherit the theme, not the hero/rosette treatment).
