# AI tools review

Reviewed on 10 October 2026 against the integrated Tinycast source and its pinned upstream revision `71279c8de18fe77c56aa1cfaaeb68bf07748bbdd`.

RayCompanion already has provider routing and a tool-call loop. The missing pieces are useful default tools and a way to execute community Raycast AI tools. Replacing the provider layer would not supply either one.

## Current backend

`AIProviderFactory` selects Apple FoundationModels, custom URLSession HTTP providers, or installed CLI clients. There is no shared third-party AI SDK. `AIToolLoopProvider` manages tool execution for supported API models. Codex and Claude manage their own tool loops and receive MCP server configurations through `AIToolServerSession`.

`AIChatCoordinator.tools(for:)` currently draws tools from configured MCP servers. It has no native default-tool registry. The Apple Intelligence route currently sends no tool definitions; other installed CLI routes do not all support the MCP configuration path. Adding a tool must include capability checks rather than assuming it works with every model.

Vercel's [AI SDK](https://ai-sdk.dev/docs/introduction) provides TypeScript provider and tool abstractions. Moving this Swift app to it would introduce a JavaScript service boundary. That could be justified by a separately required JS backend, but it is not necessary to add tools to the existing Swift loop. The project referred to as “fbjs” remains unidentified; its SDK has not been compared.

## Raycast comparison

Raycast documents built-in tools for browser context, calculations, calendar, clipboard, file search and management, location, notes, reminders, selected text, screen context, shell commands and other Raycast features. These are separate capabilities, not evidence that its private backend uses a particular AI SDK. [Built-in tools and approvals](https://manual.raycast.com/ai/ai-extensions).

The useful first additions here are:

- Calculator and date/unit calculations using deterministic local operations.
- Existing web search/fetch presented as clearly named tools.
- Selected text and current-app context captured on request.
- File search and bounded text reads within user-selected folders.
- `run_command`, with the exact command and working directory shown before execution.

Keep clipboard-history collection and global launcher hooks out of startup. Calendar, reminders and browser integration can follow when there is a concrete need for them.

Shell execution needs its own per-call consent, timeout, output limit and cancellation that terminates the process group. Existing MCP server-level “always” trust is not a suitable blanket grant for arbitrary commands. File changes and external writes also need approval based on the operation and arguments, rather than a server label alone.

## Community extension compatibility

Raycast's public format supplies manifest `tools`, compiled input/output schemas, optional instructions, a default-exported function accepting one object, and an optional `confirmation(input)` function. Its manifest can also describe MCP servers. These documented interfaces are enough to begin compatibility work without accessing the private Raycast AI service. [Manifest](https://developers.raycast.com/information/manifest), [tool contract](https://developers.raycast.com/ai/learn-core-concepts-of-ai-extensions).

The retained Tinycast runtime uses JavaScriptCore, a React renderer and partial Raycast/Node API shims. It is not a complete Node environment. Today:

- `ExtensionManifest` reads regular commands but does not register AI tools or instructions.
- The no-view runner passes launch properties and signals completion; it discards the function's return value.
- The runtime explicitly rejects `AI.ask()`.
- Authenticated tools require their own configured credentials. Existing Raycast credentials should not be copied.

Implement a tool-only adapter rather than starting the full extension launcher. Read schemas from the built manifest, validate arguments, evaluate the module, obtain its confirmation, execute only after consent, and return a bounded JSON result to the existing tool loop. Record failures as tool errors. Allow cancellation and dispose the runtime after the call.

An `AI.ask()` bridge could call RayCompanion's selected provider while preserving streaming and cancellation. It needs a recursion limit so an extension's nested AI request cannot start an unbounded chain. The [Raycast API](https://developers.raycast.com/api-reference/ai) documents the public contract; mapping its model choices to our providers is a separate compatibility decision.

Restore upstream `Scripts/raycast-runtime` build sources and tests before changing the generated runtime. Do not hand-edit `RaycastRuntime.generated.js`. Add compatibility tests for each supported API and report unsupported APIs explicitly. A successful simple tool does not establish compatibility with all store extensions.

## Implementation order

1. Add local tools behind the existing `AITool` interface, with one consent path shared with MCP and extension tools.
2. For Codex/Claude parity, expose those same handlers through a local MCP bridge with app-controlled lifecycle and no public listener. Preserve separate provider capability checks.
3. Implement a tool-only extension adapter and verify one real read-only community tool with its own authentication.
4. Add `AI.ask()` compatibility only after basic tool execution, cancellation and approvals work.

## Proof performed

An isolated fixture in `/tmp/raycompanion-tool-proof` was built with the official `@raycast/api` 2.7.3 CLI. It generated required numeric `a`/`b` inputs, an output schema and confirmation metadata. A wrapper ran the compiled tool in the pinned Tinycast Node VM runtime harness.

Checks passed: confirmation described the inputs; denial skipped invocation; approval returned `{ "sum": 5 }`; both sessions completed without runtime failures. No network, file or shell action was performed by the fixture.

This verifies schema extraction and basic runtime mechanics. It does not verify native JavaScriptCore execution, model-driven invocation, an authenticated community extension or production UI. No default tools, dependencies or extension adapter were installed in RayCompanion during this review.

## Implemented in RayCompanion

Calculator, file search, UTF-8 file reads and selected text now use the existing tool loop. File search reuses Tinycast's Spotlight service and only searches allowed folders. File reads are limited to 64 KiB; file reads and selected text ask before use. The last external app is tracked without keyboard hooks or clipboard collection. Raycast itself is excluded as a selected-text target.

Supported API routes receive these tools directly. Codex/Claude receive the same handlers through a bearer-authenticated localhost MCP endpoint. One endpoint serves every chat; its URL and token change only when the offered tools change, because Codex relaunches whenever its server list differs. This bridge is app-owned, rejects browser origins, bounds requests and connections, and closes when tools or the app stop. The native tools are a separate switch from third-party MCP servers. Apple Intelligence's existing route still does not expose tools.

Settings → AI has file-folder selection and an AI-extension importer. Import copies built bundles, assets and available license files from installed Raycast extension directories into RayCompanion's own storage; it does not copy Raycast preferences or logins. Extensions start disabled. Enabling an extension adds its schemas to the tool list. Every extension call asks before loading code, and exported confirmations are also honored. Argument-free tools receive an empty object schema.

The adapter executes tools with the existing JavaScriptCore runtime and returns bounded JSON results. Extension preferences and LocalStorage use RayCompanion's Keychain scopes. Fetch and a subset of storage/cache APIs are supported. Raycast-managed OAuth, UI APIs and `AI.ask()` remain unsupported in this tool-only host. Node compatibility remains partial; this is not a sandbox and not every installed extension is supported. No launcher startup was enabled.

The desktop fixture provider requested the real native calculator and received `14`. The installed Base64 bundle returned `"aGVsbG8="` through native JavaScriptCore and the actual chat tool loop. The extension-list layout was checked on the desktop after making rows fill the available width. Tests cover folder boundaries, symlink escape, file size/encoding, native confirmations/results, schema import and the localhost MCP transport. Authenticated extensions and physical selected-text capture remain separate checks.

## Tool approval

AI Settings offers Ask every time, Allow reads, and Allow reads & writes. Allow reads is the default for native file search, scoped file reads and selected text. Imported extension tools have no reliable read/write classification, so they ask unless Allow reads & writes is selected. An extension's exported `confirmation()` is its own declaration of a side effect, so it always asks, even under Allow reads & writes. MCP servers retain their own consent settings. Enable all switches the imported extensions together.
