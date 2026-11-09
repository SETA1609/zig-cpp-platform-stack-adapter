### issue-9 Native folder picker

- `requestFolderPicker` opens the native folder dialog without blocking, and `FolderPickerRequest.poll` returns the chosen path, a cancel, or `error.FolderPickerFailed`. No SDL type crosses the API.
- Checked: `zig build test` covers selected, canceled, and failed requests and out of memory, with no display. The library builds for Linux and Windows. The dialog itself needs a manual run.
