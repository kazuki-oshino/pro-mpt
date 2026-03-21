import Foundation

// MARK: - デバウンサー

/// 連続呼び出しを間引いて最後の呼び出しのみ実行する
final class Debouncer: @unchecked Sendable {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue

    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    /// 前回の呼び出しをキャンセルし、delay後に実行
    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// キャンセル
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
