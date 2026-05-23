# Caja Clara Media Artifacts Cleanup Report

Date: 2026-05-22
Repository: `D:\bit flow hoy actualizado 12.2\caja-clara`
Archive folder: `C:\demo comerciales\caja_clara_archived_demo_captures`

## Summary

Moved the requested demo media artifacts out of the repository and into the external archive folder. No Dart source files were edited, staged, committed, or pushed.

## Files Moved To Archive

- `docs/demo_captures/caja-clara-demo-final-60s.mp4`
- `docs/demo_captures/caja-clara-demo-premium-45s.mp4`
- `docs/demo_captures/caja-clara-demo-premium-60s.mp4`
- `docs/demo_captures/final-01-home.png`
- `docs/demo_captures/final-02-new-sale.png`
- `docs/demo_captures/final-03-caja.png`
- `docs/demo_captures/final-04-export.png`
- `docs/demo_captures/premium-01-home.png`
- `docs/demo_captures/premium-02-new-sale.png`
- `docs/demo_captures/premium-03-expense.png`
- `docs/demo_captures/premium-04-caja.png`
- `docs/demo_captures/premium-05-export.png`
- `docs/demo_captures/video-recording-smoke.mp4`

## Repository Files Left In `docs/demo_captures`

These files were not matched by the requested cleanup patterns except for the moved `.mp4`, so they remain in the repository folder:

- `docs/demo_captures/01-home-demo.png`
- `docs/demo_captures/02-new-sale.png`
- `docs/demo_captures/03-caja.png`
- `docs/demo_captures/04-export-excel.png`

## .gitignore Update

Added ignore rules for future demo capture artifacts:

```gitignore
docs/demo_captures/*.mp4
docs/demo_captures/final-*.png
docs/demo_captures/premium-*.png
```

## Important Note

`docs/demo_captures/video-recording-smoke.mp4` was already tracked by git. Moving it out of the repo now appears as a tracked deletion in `git status`. This is expected from the requested `docs/demo_captures/*.mp4` cleanup pattern, but it should be reviewed before any future commit.

The other moved files were untracked demo media artifacts and are no longer shown as untracked because they are outside the repository.

## Actions Not Performed

- No Dart source files were modified.
- No files were staged.
- No commit was created.
- Nothing was pushed.
