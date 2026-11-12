# BUG-02 — `Local $iPendLen` Redeclaration Inside Phase 1 Loop

**Ticket ref:** CR2-34
**File:** `Includes/ServiceManager.au3`
**Function:** `_SM_StopServicesBatch`
**Severity:** AU3Check warning (style/compiler); NOT a runtime data bug
**Status:** Fixed

---

## 1. Location and Loop Structure

The Phase 1 loop spans lines 194–309:

```autoit
For $i = 0 To $iCount - 1          ; line 194
    Local $sName = $aServiceNames[$i]
    Local $iPendLen                  ; line 199  ← declaration inside loop body
    ...
    If _SM_StateNeedsPolling($iInitState) Then
        $iPendLen = UBound($aPendingIdx)   ; line 256 — first assignment
        ...
    EndIf
    ...
    ; Stop control accepted branch
    $iPendLen = UBound($aPendingIdx)       ; line 303 — second assignment
    ...
Next                                 ; line 309
```

`Local $iPendLen` appears at **line 199**, which is inside the `For` loop body.
Both read sites (lines 256 and 303) are plain assignments — no `Local` keyword — so the
variable is correctly assigned before every read.

---

## 2. AU3Check Flag Analysis (`-w 3` and `-w 4`)

From `CODING_STANDARDS.md` §AU3Check Compliance:

> All `.au3` files must satisfy `AU3Check -q -d -w 1 -w 2 -w 3 -w 4`

`-w 3` enables warnings for variables that are **used before declaration** or
**redeclared** within the same scope. AutoIt's scoping model is function-level, not
block-level: a `Local` declaration inside a `For` loop body re-runs the declaration
statement on every iteration. AU3Check treats this as a redeclaration-in-loop and emits
a `-w 3` warning of the form:

> `warning: variable '$iPendLen' already used at this scope level`

`-w 4` enables shadowing warnings (Local vs Global name collisions); `$iPendLen` has no
Global counterpart, so `-w 4` does not fire here.

---

## 3. Is This a Genuine Runtime Bug?

**No.** The variable is never read before being assigned within the same iteration.
Both branches that read `$iPendLen` first execute `$iPendLen = UBound($aPendingIdx)`,
so the value is always fresh at point of use. There is no iteration where a stale value
from a prior loop cycle could affect correctness.

This is a **compiler-warning-only issue**: AU3Check `-w 3` flags the redeclaration, but
the generated code behaves correctly at runtime.

---

## 4. Fix

Move the `Local $iPendLen` declaration to **before** the Phase 1 loop (after the pending
tracking array declarations), so the identifier is declared once at function scope.
Remove the `Local` keyword from line 199 inside the loop — the two assignment sites
(lines 256 and 303) already use plain `$iPendLen = ...` with no `Local`, so no further
changes are needed there.

**Before:**
```autoit
; --- Pending-services tracking arrays ---
Local $aPendingIdx[0]
Local $aPendingHnd[0]

For $i = 0 To $iCount - 1
    Local $sName = $aServiceNames[$i]
    ; $iPendLen declared once per loop iteration; ...
    Local $iPendLen
    ...
```

**After:**
```autoit
; --- Pending-services tracking arrays ---
Local $aPendingIdx[0]
Local $aPendingHnd[0]
Local $iPendLen   ; declared at function scope — assigned in loop before each use

For $i = 0 To $iCount - 1
    Local $sName = $aServiceNames[$i]
    ...
```

---

## 5. Hypothesis Outcome (Phase 3 / Phase 5 per diagnosing-bugs skill)

Winning hypothesis: `Local` inside the loop body is a syntactically redundant redeclaration
that AU3Check `-w 3` flags. Moving the declaration one scope level up (before the loop)
eliminates the warning with zero behavioral change. No regression test seam is available
(AutoIt has no unit-test runner for AU3Check output), but the fix is mechanical and
verifiable by re-running `AU3Check -q -d -w 1 -w 2 -w 3 -w 4` against the patched file.
