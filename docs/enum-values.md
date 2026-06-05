# Enum numeric values — `platform`

> Stable name → integer-value maps for the public enums, for **serialization**:
> writing rebindable bindings to TOML/JSON config (v0.7.0), save files, or a
> network/IPC protocol. Inside Zig code always use the named field
> (`.escape`, `.menu_pause`) — reach for these numbers only when crossing a
> text/binary boundary.
>
> Generated from `src/common.zig` (`@intFromEnum`). Values are assigned in
> declaration order from `0`; **append new fields at the end** to keep existing
> numbers stable. `ActionId` and `InputContextId` are non-exhaustive (`_`),
> so consumers may define their own values **above** the built-ins listed here.

## Backing widths

| Enum | Tag type | Why |
| --- | --- | --- |
| `Renderer`, `MouseButton`, `GamepadButton`, `GamepadAxis` | auto (smallest fit) | closed sets — Zig picks `u2`/`u3`/`u4` |
| `KeyCode` | `u16` | physical-key space exceeds 256 (HID/scancodes) |
| `ActionId`, `InputContextId` | `u16` | extensible IDs with comfortable headroom |

## Values

```json
{
  "Renderer": {
    "none": 0,
    "vulkan": 1,
    "opengl": 2,
    "cpu": 3,
    "metal": 4,
    "directx": 5
  },
  "MouseButton": {
    "left": 0,
    "right": 1,
    "middle": 2,
    "x1": 3,
    "x2": 4
  },
  "GamepadButton": {
    "a": 0,
    "b": 1,
    "x": 2,
    "y": 3,
    "left_bumper": 4,
    "right_bumper": 5,
    "back": 6,
    "start": 7,
    "guide": 8,
    "left_stick": 9,
    "right_stick": 10,
    "dpad_up": 11,
    "dpad_down": 12,
    "dpad_left": 13,
    "dpad_right": 14
  },
  "GamepadAxis": {
    "left_x": 0,
    "left_y": 1,
    "right_x": 2,
    "right_y": 3,
    "left_trigger": 4,
    "right_trigger": 5
  },
  "ActionId": {
    "move_forward": 0,
    "move_back": 1,
    "move_left": 2,
    "move_right": 3,
    "jump": 4,
    "interact": 5,
    "menu_pause": 6
  },
  "InputContextId": {
    "gameplay": 0,
    "ui_menu": 1,
    "dialog": 2,
    "inventory": 3,
    "cinematic": 4
  },
  "KeyCode": {
    "unknown": 0,
    "a": 1, "b": 2, "c": 3, "d": 4, "e": 5, "f": 6, "g": 7, "h": 8, "i": 9,
    "j": 10, "k": 11, "l": 12, "m": 13, "n": 14, "o": 15, "p": 16, "q": 17,
    "r": 18, "s": 19, "t": 20, "u": 21, "v": 22, "w": 23, "x": 24, "y": 25,
    "z": 26,
    "0": 27, "1": 28, "2": 29, "3": 30, "4": 31, "5": 32, "6": 33, "7": 34,
    "8": 35, "9": 36,
    "space": 37,
    "enter": 38,
    "tab": 39,
    "backspace": 40,
    "delete": 41,
    "insert": 42,
    "escape": 43,
    "left": 44,
    "right": 45,
    "up": 46,
    "down": 47,
    "home": 48,
    "end": 49,
    "page_up": 50,
    "page_down": 51,
    "left_shift": 52,
    "right_shift": 53,
    "left_control": 54,
    "right_control": 55,
    "left_alt": 56,
    "right_alt": 57,
    "left_gui": 58,
    "right_gui": 59,
    "caps_lock": 60,
    "minus": 61,
    "equals": 62,
    "left_bracket": 63,
    "right_bracket": 64,
    "backslash": 65,
    "semicolon": 66,
    "apostrophe": 67,
    "grave": 68,
    "comma": 69,
    "period": 70,
    "slash": 71,
    "f1": 72, "f2": 73, "f3": 74, "f4": 75, "f5": 76, "f6": 77,
    "f7": 78, "f8": 79, "f9": 80, "f10": 81, "f11": 82, "f12": 83
  }
}
```

## Regenerating

These maps are derived, not hand-maintained. To regenerate after editing the
enums, dump `@intFromEnum` over `@typeInfo(T).@"enum".fields` for each enum in
`src/common.zig` and paste the result above.
