import Foundation
import JavaScriptCore

/// A tool call's 90-second budget, paused while its confirmation waits on the user.
struct ToolInvocationClock {
    static let budget: TimeInterval = 90
    var remaining = budget
    var armedAt = DispatchTime.now()
    var timeout: DispatchWorkItem?
    var confirmation: Task<Void, Never>?

    mutating func pause() {
        guard let timeout else { return }
        timeout.cancel()
        self.timeout = nil
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - armedAt.uptimeNanoseconds) / 1e9
        remaining = max(remaining - elapsed, 0)
    }
}

extension ExtensionRuntime {
    func invokeTool(
        code: String, file: URL, context: ExtensionLaunchContext, arguments: String,
        confirmation: @escaping @MainActor @Sendable (String) async -> Bool
    ) async throws -> String {
        let payload = context.jsonString()
        let session = UUID().uuidString
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    guard let js = self.context else {
                        continuation.resume(throwing: RuntimeError.bootFailed("no context"))
                        return
                    }
                    self.toolReply = continuation
                    let result: @convention(block) (String, Bool) -> Void = {
                        [weak self] value, failed in
                        guard let self, let reply = self.toolReply else { return }
                        self.toolReply = nil
                        self.toolClock.timeout?.cancel()
                        if failed {
                            reply.resume(
                                throwing: RuntimeError.bootFailed(String(value.prefix(4_000))))
                        } else {
                            reply.resume(returning: String(value.prefix(65_536)))
                        }
                    }
                    let confirm: @convention(block) (String) -> Void = { [weak self] value in
                        guard let self, self.toolReply != nil else { return }
                        self.toolClock.pause()
                        self.toolClock.confirmation = Task { @MainActor [weak self] in
                            let allowed = await confirmation(value)
                            await self?.resolveToolConfirmation(allowed)
                        }
                    }
                    js.setObject(result, forKeyedSubscript: "__raycompanionToolResult" as NSString)
                    js.setObject(
                        confirm, forKeyedSubscript: "__raycompanionToolConfirm" as NSString)
                    let wrapper = """
                        const tool = { exports: {} };
                        (function(exports, require, module, __filename, __dirname) {
                        \(code)
                        })(tool.exports, require, tool, __filename, __dirname);
                        module.exports.default = async function() {
                          try {
                            const input = JSON.parse(\(ExtensionRuntime.jsonString(from: arguments)));
                            if (typeof tool.exports.confirmation === 'function') {
                              const details = await tool.exports.confirmation(input);
                              if (details !== undefined) {
                                const allowed = await new Promise(resolve => {
                                  globalThis.__raycompanionToolConsent = resolve;
                                  __raycompanionToolConfirm(JSON.stringify(details));
                                });
                                if (!allowed) throw new Error('The user declined this tool call.');
                              }
                            }
                            const result = await tool.exports.default(input);
                            __raycompanionToolResult(JSON.stringify(result === undefined ? null : result), false);
                          } catch (error) {
                            __raycompanionToolResult(String(error && error.message || error), true);
                          }
                        };
                        """
                    // Armed first: the extension may ask for confirmation before `start` returns.
                    self.toolClock = ToolInvocationClock()
                    self.armToolTimeout()
                    _ = js.objectForKeyedSubscript("__tinycast")?.invokeMethod(
                        "start",
                        withArguments: [
                            session, wrapper, file.path, file.deletingLastPathComponent().path,
                            "no-view",
                            payload,
                        ])
                }
            }
        } onCancel: {
            self.queue.async { self.cancelToolReply("The tool call was cancelled.") }
        }
    }

    /// On `queue`; restarts the countdown with whatever the confirmation left of the budget.
    private func armToolTimeout() {
        let timeout = DispatchWorkItem { [weak self] in
            self?.cancelToolReply("The extension tool timed out.")
        }
        toolClock.armedAt = .now()
        toolClock.timeout = timeout
        queue.asyncAfter(deadline: .now() + toolClock.remaining, execute: timeout)
    }

    private func resolveToolConfirmation(_ allowed: Bool) async {
        await onQueue { [weak self] js in
            guard let self, self.toolReply != nil else { return }
            self.toolClock.confirmation = nil
            self.armToolTimeout()
            _ = js.objectForKeyedSubscript("__raycompanionToolConsent")?.call(withArguments: [
                allowed
            ])
        }
    }

    /// On `queue`; also dismisses a confirmation still waiting, since nothing will read it.
    private func cancelToolReply(_ message: String) {
        toolClock.timeout?.cancel()
        toolClock.timeout = nil
        toolClock.confirmation?.cancel()
        toolClock.confirmation = nil
        guard let reply = toolReply else { return }
        toolReply = nil
        reply.resume(throwing: RuntimeError.bootFailed(message))
    }
}
