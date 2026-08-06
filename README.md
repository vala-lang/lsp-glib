# lsp-glib

LSP library built on GLib. Designed for both editors and servers.

Design ideas:
- Hide JSON-RPC protocol as much as possible from the user
  - protocol functions are fully typed
  - protocol functions throw errors instead of explicitly sending error
    messages to client
- Fully asynchronous API
- Use GVariant serialization for data types with
  `to_variant()` / `from_variant()` functions
- Make C API ergonomic and limit memory requirements:
  - Avoid GObject as much as possible
  - Flatten LSP data structures where it makes sense to avoid excess
    pointer chasing
  - No use of `libgee`. Prefer built-in GLib data structures

### Meson

Installed packages can be used directly with
`dependency('lsp-glib-3.0')`. For a subproject fallback, map the package to
the dependency matching the consumer language. C projects use:

```ini
[provide]
lsp-glib-3.0 = lsp_glib_dep
```

Vala projects use:

```ini
[provide]
lsp-glib-3.0 = lsp_glib_vala_dep
```

The Vala dependency also carries generated VAPIs required by transitive
subprojects.

### Protocol Support

#### Base Protocol

- [x] `$/cancelRequest` (server)

#### Lifecycle Messages

- [x] `initialize`
- [x] `initialized`
- [ ] `client/registerCapability`
- [ ] `client/unregisterCapability`
- [x] `$/setTrace`
- [x] `$/logTrace`
- [x] `shutdown`
- [x] `exit`

#### Document Synchronization

- [x] `textDocument/didOpen`
- [x] `textDocument/didChange`
- [ ] `textDocument/willSave` (client capability only)
- [ ] `textDocument/willSaveWaitUntil`
- [x] `textDocument/didSave`
- [x] `textDocument/didClose`
- [ ] `textDocument/didRename`

#### Language Features

- [x] `textDocument/completion`
- [ ] `completionItem/resolve`
- [x] `textDocument/hover`
- [x] `textDocument/signatureHelp`
- [x] `textDocument/codeAction`
- [ ] `codeAction/resolve`
- [x] `textDocument/publishDiagnostics`
- [ ] `textDocument/pullDiagnostics`
- [x] `textDocument/declaration`
- [x] `textDocument/definition`
- [ ] `textDocument/typeDefinition` (capability field only)
- [x] `textDocument/implementation`
- [x] `textDocument/references`
- [x] `textDocument/documentHighlight`
- [x] `textDocument/documentSymbol`
- [x] `textDocument/codeLens`
- [ ] `codeLens/resolve`
- [ ] `textDocument/foldingRange`
- [ ] `textDocument/selectionRange`
- [ ] `textDocument/documentLink` (types only)
- [ ] `documentLink/resolve`
- [ ] `textDocument/documentColor`
- [ ] `textDocument/colorPresentation`
- [x] `textDocument/formatting`
- [x] `textDocument/rangeFormatting`
- [ ] `textDocument/onTypeFormatting` (types only)
- [x] `textDocument/rename`
- [x] `textDocument/prepareRename`
- [ ] `textDocument/semanticTokens`
- [ ] `textDocument/moniker`
- [ ] `textDocument/inlineValue`
- [x] `textDocument/inlayHint`
- [x] `inlayHint/resolve`
- [x] `textDocument/prepareCallHierarchy`
- [x] `callHierarchy/incomingCalls`
- [x] `callHierarchy/outgoingCalls`
- [x] `textDocument/prepareTypeHierarchy`
- [x] `typeHierarchy/supertypes`
- [x] `typeHierarchy/subtypes`
- [ ] `textDocument/linkedEditingRange`

#### Workspace Features

- [x] `workspace/symbol`
- [ ] `workspace/executeCommand`
- [x] `workspace/applyEdit`
- [ ] `workspace/didChangeConfiguration`
- [ ] `workspace/didChangeWatchedFiles`
- [ ] `workspace/didChangeWorkspaceFolders`
- [ ] `workspace/willCreateFiles`
- [ ] `workspace/didCreateFiles`
- [ ] `workspace/willRenameFiles`
- [ ] `workspace/didRenameFiles`
- [ ] `workspace/willDeleteFiles`
- [ ] `workspace/didDeleteFiles`
- [ ] `workspace/didChangeConfiguration`
- [ ] `workspace/textDocumentContent`

#### Window Features

- [x] `window/showMessage`
- [x] `window/showMessageRequest`
- [x] `window/logMessage`
- [x] `window/showDocument`

#### Telemetry

- [ ] `telemetry/event`

### Workflow

Install Uncrustify and enable the tracked Git hooks for this checkout:

```sh
git config core.hooksPath .githooks
```

The pre-commit hook checks staged Vala files against `.uncrustify.cfg`. It
reports files that need formatting without modifying the working tree or the
index. GitHub Actions runs the same check for Vala files changed by each pull
request.

### Docs

The latest API documentation is published at
[vala-lang.github.io/lsp-glib](https://vala-lang.github.io/lsp-glib/), with
separate references for
[GObject Introspection](https://vala-lang.github.io/lsp-glib/gi/) and
[Vala](https://vala-lang.github.io/lsp-glib/vala/).

Build the same combined site locally with:

```sh
meson setup build
meson compile -C build pages
```

The generated site is located in `build/doc/pages`.

### Tests

Run all available tests with `meson test -C build`. Tests can also be run by
language:

```sh
meson test -C build --suite vala
meson test -C build --suite c
meson test -C build --suite python
meson test -C build --suite js
```
