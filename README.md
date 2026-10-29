# ending

A new Flutter project.

## Bundled fonts (offline reading)

The reader uses `google_fonts`, which downloads fonts on first use. To make it
work offline and avoid text reflowing when a font arrives late:

1. Download **static** `.ttf` files (not variable fonts) for Literata,
   Merriweather, Lora, Inter, Atkinson Hyperlegible and Fraunces from
   fonts.google.com. Regular, SemiBold and Bold cover what the app uses
   (w400, w600, w700).
2. Put them in `assets/google_fonts/`. File names must look like
   `Lora-Regular.ttf`, `Lora-Bold.ttf`, `Fraunces-SemiBold.ttf`
   (`Family-Weight.ttf`), which is how `google_fonts` finds them.
3. Set `AppConfig.bundledFonts = true` in `lib/core/config.dart`.
4. Do a full rebuild (not hot reload). A missing weight throws in debug and
   names the file it wanted.
