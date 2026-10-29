# BetterSeed v0.1 — product & behavior specification

## Problem
Typical to-do lists hide the emotional progress of small actions. BetterSeed makes progress visible as a fantasy tree that slowly grows when the user checks meaningful daily habits. Saving money, learning, health goals, and other categories come later.

## Core UX loop
Open home screen → see tree and current habits → check completed habits → earn XP → see tree progress and transformation → return tomorrow.

## Current prototype domain

- **Habit**: id, short title, completed bool (for current local day).
- **XP**: integer lifetime net points; 10 per completed habit today, undo checkbox subtracts 10.
- **Stage thresholds**: 0, 20, 50, 100, 180, 300 lifetime XP. Final stage stays unlocked after 300.
- **Reset**: on cold start or app resume, if saved local date differs from current day, checkboxes reset to false while lifetime XP remains.
- **Storage**: shared_preferences JSON for demonstration; SQLite + activity ledger scheduled for later batches.
- **Progress**: no XP is generated merely by creating or deleting a habit.
- **Offline**: all current features run without network.

## Navigation v0.1
Single screen dashboard. Modal sheet creates a habit, confirmation dialog removes a habit. Additional tabs are intentionally postponed until their behavior is implemented.

## Upcoming goals
- Independent savings goals with *manual* monetary entries, locale formatting, and correct decimal arithmetic.
- Goal-level XP separate from money amount, to avoid equating wealth with self-improvement.
- Good UX for people who miss days; never punish streak breaks by killing a tree.

## Safety & trust
- No bank account access or financial advice.
- No personal data sent to a server in this build.
- Users may lose local data when uninstalling without backup (backup/export to be added).
- No exaggerated claims such as proven improvement in health, finances, or psychological wellness.
