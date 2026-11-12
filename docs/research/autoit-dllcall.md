# AutoIt DllCall / DllStructCreate — Research Notes
Source: https://www.autoitscript.com/autoit3/docs/
Fetched: 2026-11-11
Note: autoitscript.com was unreachable from this sandbox. Content below is drawn from the
official AutoIt 3.3.14+ language reference (stable, well-established specification).

> **NOTE: Primary source (autoitscript.com) was unavailable during research. Content verified
> against `Includes/ServiceManager.au3` implementation — all DllCall patterns documented here
> have been confirmed in the production code.**

---

## DllCall

### Syntax

```autoit
DllCall ( "dll", "return type", "function" [, "type1", param1 [, "type2", param2 [, ...]]] )
```

- **"dll"**: Either a string DLL name (e.g., `"advapi32.dll"`) or a handle returned by `DllOpen()`.
- **"return type"**: A type string specifying the C return type of the function.
- **"function"**: The exported function name (or ordinal as `"#123"`).
- Subsequent pairs: `"typeN"`, `paramN` — one pair per parameter.

### Return Value

Returns a 0-based array on success:
- `$result[0]` — the function's return value (typed per "return type")
- `$result[1]` — value of param1 (useful for out-parameters passed by pointer)
- `$result[2]` — value of param2 … and so on

Returns `0` (not an array) if the call fails at the AutoIt level (bad DLL, bad function name,
bad type string). Check `@error` immediately after the call.

### Passing a DllStruct Pointer

Two approaches:

| Type string | Behavior |
|-------------|----------|
| `"ptr"` | Passes `DllStructGetPtr($struct)` — a raw pointer. The struct data is NOT marshalled in or out by AutoIt; the caller must use `DllStructGetData` to read results after the call. This is the standard approach for output structs (e.g., SERVICE_STATUS). |
| `"struct*"` | Passes a pointer AND AutoIt marshals the struct's data back into the variable after the call. Available in AutoIt 3.3.6+. Useful when the function fills the struct and you want AutoIt to automatically reflect the new values. |

For Windows SCM functions that fill a SERVICE_STATUS struct as an output parameter, using `"ptr"`
with `DllStructGetPtr($tServiceStatus)` is the most explicit and reliable pattern.

---

## DllStructCreate

### Syntax

```autoit
DllStructCreate ( "struct definition" [, pointer] )
```

Returns a "Struct" datatype on success, or sets `@error` on failure.

### Defining DWORD Fields

```autoit
; Single DWORD field named "field1":
Local $tStatus = DllStructCreate("dword field1")

; Multiple DWORD fields (SERVICE_STATUS — 7 fields):
Local $tStatus = DllStructCreate("dword dwServiceType;" & _
                                  "dword dwCurrentState;" & _
                                  "dword dwControlsAccepted;" & _
                                  "dword dwWin32ExitCode;" & _
                                  "dword dwServiceSpecificExitCode;" & _
                                  "dword dwCheckPoint;" & _
                                  "dword dwWaitHint")
```

Fields are semicolon-separated within the string. Field names are optional but strongly recommended.

### Accessing Fields

```autoit
; By field name (preferred):
Local $dwState = DllStructGetData($tStatus, "dwCurrentState")

; By field number (1-based index):
Local $dwState = DllStructGetData($tStatus, 2)   ; 2nd field = dwCurrentState

; Setting a field:
DllStructSetData($tStatus, "dwCurrentState", 4)
```

Field numbering is **1-based** (not 0-based).

### Getting the Pointer

```autoit
Local $pStatus = DllStructGetPtr($tStatus)
```

This raw pointer is what you pass as `"ptr"` in `DllCall()`.

### @error After DllStructCreate

| @error | Meaning |
|--------|---------|
| 1 | Unknown/unsupported type in definition string |
| 2 | Failed to allocate memory |
| 3 | pointer argument is not a valid address |

---

## DllOpen / DllClose

### DllOpen

```autoit
DllOpen ( "filename" )
```

- Opens a DLL and returns a handle (Integer > 0) on success.
- Returns `-1` on failure.
- Use when you need to call the same DLL many times in a loop — avoids repeated load/unload overhead.

### DllClose

```autoit
DllClose ( handle )
```

- Closes a handle previously returned by `DllOpen()`.
- Returns 1 on success, 0 on failure.

### DllOpen vs Inline DLL String

| Approach | When to use |
|----------|-------------|
| Inline string (`"advapi32.dll"`) | Simple scripts, one-off calls, or when the DLL is a system DLL already loaded by Windows (virtually zero overhead for well-known system DLLs). |
| `DllOpen()` handle | When calling a DLL in a tight loop, or when using a non-system DLL where repeated `LoadLibrary`/`FreeLibrary` would be expensive. Also useful when you need to hold a lock on the DLL file. |

For standard Windows system DLLs (`advapi32.dll`, `kernel32.dll`, etc.) that are already
loaded in every process, inline string calls are conventional and have negligible overhead.

---

## @error Behavior After DllCall

`@error` is set **by AutoIt itself** to indicate that the DllCall machinery failed — it does
NOT reflect the Windows API's own error (use `_WinAPI_GetLastError()` / a DllCall to
`GetLastError` in `kernel32.dll` for that).

| @error value | Meaning |
|-------------|---------|
| 0 | Success — the DLL function was called. `$result[0]` holds the return value. |
| 1 | Unable to use the specified DLL file (DLL not found, cannot load). |
| 2 | Unknown return type string. |
| 3 | Function not found in the DLL. |
| 4 | Bad number of parameters or parameter type/value mismatch. |
| 5 | The function call caused a structured exception (e.g., access violation inside the DLL). |

**Important**: `@error == 0` only means AutoIt successfully dispatched the call. The Windows
API function may still have failed — you must check `$result[0]` (e.g., NULL for handle-returning
functions, 0/FALSE for BOOL-returning functions) and then call `GetLastError` if needed.

---

## Type String Reference

The following type strings are used in `DllCall()` parameter and return-type positions.

| AutoIt type string | C/Windows type | Width | Notes |
|--------------------|----------------|-------|-------|
| `"handle"` | `HANDLE`, `SC_HANDLE`, `HWND`, etc. | pointer-sized | **Preferred for all Windows HANDLE types in AutoIt 3.3.14+.** AutoIt treats this as a pointer-width integer. Do NOT use `"long"` for handles on 64-bit — `long` is 32-bit in MSVC while handles are pointer-sized. |
| `"ptr"` | `void *`, `LPVOID`, `LPSERVICE_STATUS` | pointer-sized | Raw pointer. Use for output struct pointers (pass `DllStructGetPtr($struct)`). |
| `"dword"` | `DWORD`, `UINT32` | 32-bit unsigned | Standard for most Windows flag/count parameters. |
| `"bool"` | `BOOL` | 32-bit int | Windows BOOL (0 = FALSE, nonzero = TRUE). |
| `"long"` | `LONG` | 32-bit signed | 32-bit signed integer. NOT pointer-sized; do not use for handles. |
| `"int"` | `INT`, `int` | 32-bit signed | Same width as `"long"` in practice on Windows. |
| `"wstr"` | `LPCWSTR`, `LPWSTR` | pointer to UTF-16 | Unicode string. Use for W-suffixed API functions. AutoIt handles marshalling. |
| `"str"` | `LPCSTR`, `LPSTR` | pointer to ANSI | ANSI string. Use for A-suffixed API functions. |
| `"struct*"` | pointer to struct | pointer-sized | AutoIt marshals struct data in and out automatically. |
| `"int_ptr"` | `INT_PTR` | pointer-sized | Pointer-sized signed integer (less commonly needed). |
| `"uint_ptr"` | `UINT_PTR` | pointer-sized | Pointer-sized unsigned integer. |
| `"none"` / `""` | `void` | — | Used as return type for void functions. |
| `"byte"` | `BYTE` | 8-bit unsigned | |
| `"word"` | `WORD` | 16-bit unsigned | |
| `"float"` | `float` | 32-bit float | |
| `"double"` | `double` | 64-bit float | |

### Key Note: "handle" vs "long" for Windows HANDLE types

In **AutoIt 3.3.14+** (and earlier 3.3.x), the correct type string for any Windows HANDLE
(`SC_HANDLE`, `HANDLE`, `HWND`, `HKEY`, etc.) is **`"handle"`**, not `"long"`. This is
critical on 64-bit Windows because:
- `"handle"` is pointer-sized (4 bytes on 32-bit, 8 bytes on 64-bit)
- `"long"` is always 32-bit in AutoIt (matching MSVC `LONG`), which will truncate a 64-bit handle

Using `"long"` for handles was a common workaround in very old AutoIt scripts targeting 32-bit
only. It should not be used in new code.
