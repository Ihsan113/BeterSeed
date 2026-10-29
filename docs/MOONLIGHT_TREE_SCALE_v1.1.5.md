# BetterSeed v1.1.5 — Moonlight Tree Scale Fix

## Summary
- Reworked all 6 Moonlight tree stage images so their visible tree size matches the default garden tree more closely.
- Preserved transparency and bottom grounding alignment.
- Updated Android widget Moonlight stage art to match the same scale.

## Technical approach
Each Moonlight stage image was tightly cropped to its visible content, then rescaled to the corresponding visible bbox size of the default stage, and re-centered on a 512x512 transparent canvas with matched bottom alignment.
