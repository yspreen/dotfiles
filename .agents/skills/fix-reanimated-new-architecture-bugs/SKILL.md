---
name: fix-reanimated-new-architecture-bugs
description: Diagnose, reproduce, fix, and audit React Native New Architecture/Fabric touch failures involving Reanimated, stale ShadowNode state, incorrect hitboxes, and core React Native touchables. Use when physical Android touches show press feedback but onPress does not fire, zero-duration ADB taps work while realistic touches fail, controls become inert after animated commits or scrolling, or auditing Reanimated screens for this bug class.
---

# Fix Reanimated + New Architecture Bugs

Use for React Native Fabric/New Architecture apps with `react-native-reanimated`, especially physical Android failures where touch feedback appears but action never completes.

Core workflow: **plan -> real RED -> confirmed theory -> smallest fix -> fresh build -> exact GREEN -> accessibility check -> repo-wide audit**.

## Failure signature

High-confidence signature:

- `onPressIn` fires: scale, ripple, opacity, or haptic feedback appears.
- `onPress` does not fire.
- Idealized ADB tap succeeds:

```bash
adb shell input tap X Y
```

- Physical finger fails.
- Physical-like ADB press fails:

```bash
adb shell input touchscreen swipe X Y X Y 180
```

Same start/end coordinate still generates duration and intermediate motion processing unlike `input tap`.

Never use `adb shell input tap` as sole RED or GREEN proof. It can produce false green by sending an effectively zero-duration `ACTION_DOWN`/`ACTION_UP` path without realistic `ACTION_MOVE` events.

## Root-cause model

React Native Fabric and Reanimated commit hooks can interact with stale cloned ShadowNode state. Rendered pixels may remain correct while runtime hit-testing or press responder state uses stale geometry/state. Core React Native `Pressable` can activate `onPressIn`, then lose press eligibility during motion/responder processing and never invoke `onPress`.

Account or persisted-state correlation may be indirect. Account data changes render and commit history; it does not prove sync code disabled controls. Determine whether handler fires before investigating persistence.

Primary references:

- https://github.com/software-mansion/react-native-reanimated/issues/6935
- https://github.com/facebook/react-native/issues/49694
- https://github.com/facebook/react-native/pull/50773
- https://reactnative.dev/docs/pressable
- https://docs.swmansion.com/react-native-gesture-handler/docs/components/pressable
- https://docs.swmansion.com/react-native-gesture-handler/docs/components/buttons

## Evidence levels

Keep classifications separate:

1. **Confirmed bug**: realistic gesture reproduces feedback-without-action.
2. **Covered by confirmed shared primitive**: same failing primitive, fixed once, representative consumers pass.
3. **Static risk only**: core touchable plus animated/scroll/gesture composition, but RED not reproduced.
4. **Safe/passive**: Reanimated use without actionable touch path.

Never call static risk a bug. Never edit static-risk sites speculatively.

## Mandatory environment check

Read project-local docs first. Record:

- Expo SDK manifest version
- installed Expo version
- React Native version
- Reanimated manifest range and installed version
- RNGH version
- New Architecture enabled/disabled
- physical device model, Android version, API level, and serial
- debug/release/store build type
- whether target is inside `ScrollView`, `FlatList`, sheet, pager, transformed ancestor, or gesture detector
- whether touch primitive comes from `react-native`, `react-native-gesture-handler`, or custom wrapper

Search config and installed source for:

```text
newArchEnabled
updateRuntimeShadowNodeReferencesOnCommit
useShadowNodeStateOnClone
preventShadowTreeCommitExhaustion
ANDROID_SYNCHRONOUSLY_UPDATE_UI_PROPS
IOS_SYNCHRONOUSLY_UPDATE_UI_PROPS
```

Do not assume SDK/version upgrades enabled every relevant flag. Do not assume feature flags alone fix app-level touch ownership.

## Plan requirements

Before product edits, write/update investigation plan with:

- exact bug contract;
- stateful reproduction rules;
- device/build/account state;
- hypotheses and falsification tests;
- confirmed input sequence;
- RED evidence paths;
- proposed owner change;
- exact GREEN matrix;
- lint/build/test gates.

Plan is living evidence, not work log or release history.

## Real RED protocol

### 1. Preserve affected state

Before uninstalling or clearing anything:

- capture current screen;
- record currently selected values;
- record account identity/recovery method when allowed;
- capture exact package/version/build;
- preserve relevant logs and screenshots.

Store-signed Android packages often cannot be replaced by locally signed builds:

```text
INSTALL_FAILED_UPDATE_INCOMPATIBLE
```

Do not discover this after destroying only known RED state. Decide first whether to:

- build with compatible signing;
- use alternate package plus equivalent seeded state;
- preserve/login to same account;
- or uninstall only when user explicitly authorizes data loss.

### 2. Use state-aware actions

Never assume initial selection.

For segmented controls:

1. Capture visible selected option.
2. First target must differ from current option.
3. Confirm first target becomes selected.
4. Second target must differ from new selection.
5. RED means second target does not become selected.

Example only when starting at `mins`:

```text
mins -> hours -> days
```

- RED endpoint: `hours`
- GREEN endpoint: `days`

Next run must derive sequence from current endpoint. Hard-coded taps can create false green when first target is already selected.

### 3. Run realistic gesture

```bash
adb shell input touchscreen swipe X Y X Y 180
```

Capture:

- screenshot before;
- screenshot after first transition;
- screenshot after failed second transition;
- logcat input dispatch if needed;
- handler logs when input ownership remains unclear.

Confirm visual press feedback happened but state/action did not.

### 4. Separate input failure from state failure

Instrument only as needed:

- `onPressIn`
- `onPressMove`
- `onPressOut`
- `onPress`
- responder termination/cancel
- business handler entry
- async persistence start/settle

If business handler never runs, do not start by rewriting sync/reconciliation code.

## Preferred fix order

### 1. Replace affected core touch primitive with RNGH

```tsx
import { Pressable } from "react-native-gesture-handler";
```

Use native gesture recognition for affected custom controls. Fix shared primitive once when multiple consumers use it.

### 2. Keep stable touch owner

Prefer stable RNGH outer hit target with pointer-events-none animated child:

```tsx
<Pressable onPress={onPress}>
  <Animated.View pointerEvents="none" style={animatedStyle}>
    {children}
  </Animated.View>
</Pressable>
```

Animating RNGH `Pressable` itself can work, but verify realistic gestures. If unreliable, move track/transform animation to child.

### 3. Never move action to `onPressIn`

`onPressIn` fires during scroll attempts. Triggering completed action there creates accidental activation.

### 4. Preserve parent gesture behavior

Do not fix by:

- disabling parent scrolling;
- broad responder capture;
- swallowing movement events;
- removing legitimate sheet/list gestures.

### 5. Consider framework flags last

Use Expo config plugin for native feature-flag changes. Never hand-edit generated `android/` or `ios/` folders. Require fresh native build and broader regression coverage.

## Accessibility regression gate

Core RN Pressable may have supplied implicit Android accessibility behavior that RNGH does not reproduce automatically in current composition.

After migration, inspect UIAutomator tree. Required actionable nodes:

- clickable;
- focusable;
- enabled state correct;
- role/class appropriate;
- label/content description present;
- selected/checked/disabled state correct.

For segmented options, set explicitly:

```tsx
<Pressable
  accessible
  accessibilityRole="button"
  accessibilityLabel={label}
  accessibilityState={{ selected: isSelected }}
/>
```

For switches:

```tsx
accessibilityRole="switch"
accessibilityState={{ checked: value, disabled }}
```

Example UIAutomator expectation:

```text
class=android.widget.Button
clickable=true
focusable=true
content-desc=<label>
selected=true|false
```

Accessibility failure gets its own RED -> GREEN pass. Re-run realistic touch sequence after adding semantics.

## Real GREEN protocol

After final code:

1. Produce fresh native build. Metro reload alone is not final proof.
2. Install/launch intended build or clearly document signing/data limitation.
3. Repeat exact RED command and coordinates where layout is unchanged.
4. Require at least two consecutive real transitions.
5. Repeat after scrolling.
6. Test control below changed control.
7. Test persisted state after force-stop/relaunch when relevant.
8. Test physical finger when available.
9. Verify accessibility tree.
10. Run focused lint/tests, full project lint, build, and diff checks.

Never claim green from successful compilation, unit tests, visual animation, or `input tap` alone.

## Build/install procedure

Typical Expo flow:

```bash
bunx expo run:android --no-bundler
```

If install fails only due signature mismatch, distinguish build success from install failure. Extract decisive error instead of calling build failed.

For final compile without reinstall:

```bash
./android/gradlew -p android assembleDebug
```

Follow project package-manager rules (`bun`/`bunx` when required).

If debug build needs Metro:

```bash
bunx expo start --dev-client --port 8081
adb reverse tcp:8081 tcp:8081
```

Stop background Metro when verification ends unless user wants it left running.

## Repository-wide Reanimated audit

Search direct imports, requires, and side-effect initialization:

```bash
rg -l "react-native-reanimated" --glob '*.{ts,tsx,js,jsx}'
```

Do not rely only on `from` regex; it misses side-effect imports such as:

```ts
import "react-native-reanimated";
```

For each file, inspect surrounding tree and shared primitive ownership. Static-risk patterns:

1. Core `Pressable`/`Touchable*` inside animated scroll/list/sheet tree.
2. `Animated.createAnimatedComponent(Pressable)` where Pressable is core RN.
3. Core touch owner with independently transformed animated child.
4. Touch target inside ancestor transformed by same press.
5. Animated/transformed scroll container with core touch targets.
6. Core touch target competing with RNGH pan/swipe/drag gesture.
7. Synchronous UI-prop flags plus transformed touch targets.
8. Shared touch primitive imported across many animated consumers.

Do not flag passive `Animated.View` alone.

### Audit validation strategy

Prioritize shared and high-impact primitives, then representative consumers:

- segmented control;
- switch;
- shared animated pressable;
- shared button;
- number spinner;
- FAB;
- reminder row/check action;
- bottom-sheet close/backdrop;
- paywall close/action;
- voice record control.

For each suspected site:

1. Capture site-specific RED using realistic gesture.
2. If RED does not reproduce, leave code unchanged.
3. Record it as static risk, not confirmed bug.
4. If RED reproduces, edit and run exact GREEN.

Representative successful realistic gestures reduce concern but do not prove every consumer safe. Report scope honestly.

## Multi-file and parallel-work rules

Every file edited for this bug needs independent evidence:

- shared primitive: direct harness plus representative real-screen consumer;
- consumer-specific edit: exact screen sequence;
- config/plugin edit: fresh native build;
- accessibility edit: UIAutomator RED/GREEN plus touch recheck.

When other agents work in parallel:

- track files changed by this task;
- do not revert or rewrite unrelated concurrent changes;
- scope diff checks and reporting to owned files;
- mention unrelated modified files without claiming ownership.

## Validation reporting

Report exact outcomes:

- build success/failure;
- install success/failure;
- device/account state changed or lost;
- RED command and endpoint;
- GREEN command and endpoint;
- accessibility result;
- lint result;
- focused/full test result;
- unrelated baseline failures with shortest decisive reason;
- files edited by this task only.

Do not call baseline test failures caused by unrelated code fixed or ignored. Do not claim “all tests pass” when they do not.

## Finding format

```text
path:line
Classification: confirmed / covered shared primitive / static risk / safe
Touch primitive: core RN / RNGH / custom
Scrollable, transformed, or gesture ancestors:
Reanimated mechanism:
Current state before action:
RED command and endpoint:
Handler reached: yes/no/unknown
Root-cause evidence:
Fix:
Accessibility RED/GREEN:
GREEN command and endpoint:
Build/install result:
Lint/tests:
```

## Completion gate

Task complete only when:

- plan contains confirmed hypothesis and evidence;
- real RED exists;
- smallest justified fix implemented;
- fresh build completed;
- exact realistic GREEN passes twice;
- post-scroll and lower-control checks pass;
- accessibility preserved;
- skill/audit run covers all Reanimated source files;
- suspected sites without RED remain unedited;
- final report distinguishes owned changes from parallel work.
