### issue-2 App data/cache directories are unimplemented

- `applicationDataDirectory` uses `SDL_GetPrefPath`. `applicationCacheDirectory` uses the operating system's cache location, which SDL has no call for. Both return an existing, caller-owned, absolute path ending with the separator.
- Both refuse an application name that is empty or holds a path separator (`error.ApplicationNameInvalid`).
- `openWithSystemDefault` opens a URL with `SDL_OpenURL` and returns `error.OpenWithSystemDefaultFailed` on failure.
