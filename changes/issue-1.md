### issue-1 Input contexts don't work: gameplay actions fire while a menu is open

- `pushContext`, `popContext`, `replaceTopContext`, `activeContext`, and `isContextActive` are implemented as a stack over the caller's enum. An empty stack gives `null`, and `deinit` empties it.
- `isContextActive` is true only for the top context, which the doc comment now says.
