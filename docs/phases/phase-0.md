# Phase 0: Repo + Project Skeleton + Test Harness

## Status: NOT STARTED

## Goal
A clean Godot project that can run:
- A "sandbox" scene
- A "tests runner" scene
- A simple CI-like habit locally (run tests before saying done)

## Deliverables

### 1. Main.tscn - Menu Stub
- Simple menu with buttons: **Host**, **Join**, **Quit**
- Host and Join can be stub/placeholder (just print for now)
- Quit exits the application

### 2. TestRunner.tscn - Test Runner Scene
- Loads and runs a list of test scenes
- Prints results: test name + PASS/FAIL
- Summary at end: total passed, total failed
- Can be run from editor or headless

### 3. Assert.gd - Assertion Utility
Location: `res://scripts/Assert.gd`

Functions to implement:
```gdscript
static func assert_true(condition: bool, message: String = "") -> bool
static func assert_false(condition: bool, message: String = "") -> bool
static func assert_eq(actual, expected, message: String = "") -> bool
static func assert_neq(actual, expected, message: String = "") -> bool
static func assert_gt(actual, expected, message: String = "") -> bool
static func assert_lt(actual, expected, message: String = "") -> bool
static func assert_null(value, message: String = "") -> bool
static func assert_not_null(value, message: String = "") -> bool
```

Each function should:
- Return `true` on pass, `false` on fail
- Print `[PASS]` or `[FAIL]` with the message
- Track pass/fail counts

### 4. Debug.gd - Logging Helper
Location: `res://scripts/Debug.gd`

Features:
- Toggle-based logging (enable/disable categories)
- Placeholder toggles for future features:
  - `draw_hitboxes: bool`
  - `show_ping: bool`
  - `show_velocity: bool`
- `log(category: String, message: String)` function

### 5. Folder Structure
Create the directory skeleton:
```
res://scenes/
res://scripts/
res://scripts/net/
res://scripts/player/
res://scripts/weapons/
res://scripts/projectiles/
res://tests/
```

## Tests (Minimum)

### test_asserts.tscn
- Verify `assert_true(true)` returns true
- Verify `assert_true(false)` returns false
- Verify `assert_eq(1, 1)` returns true
- Verify `assert_eq(1, 2)` returns false
- Verify all assertion functions report correctly

### test_scene_loads.tscn
- Load `Main.tscn` and confirm no errors
- Load `TestRunner.tscn` and confirm no errors
- Verify key nodes exist in loaded scenes

## Phase Complete Checklist
- [ ] All deliverables created
- [ ] `TestRunner.tscn` runs and reports results
- [ ] `test_asserts.tscn` — all PASS
- [ ] `test_scene_loads.tscn` — all PASS
- [ ] Code review: folder layout + naming consistency
- [ ] Refactor if anything is messy
- [ ] Run TestRunner again, confirm all PASS
- [ ] Update Phase Tracker in CLAUDE.md to DONE

## Files to Create
```
project.godot
scenes/Main.tscn
scenes/TestRunner.tscn
scripts/Assert.gd
scripts/Debug.gd
tests/test_asserts.tscn
tests/test_asserts.gd
tests/test_scene_loads.tscn
tests/test_scene_loads.gd
```

## Notes for Agents
- This is the foundation phase. Get the folder structure and test harness right.
- Keep everything minimal — no gameplay code yet.
- The TestRunner pattern established here is used in every subsequent phase.
- Make sure Assert.gd is an autoload or static class so tests can access it easily.
