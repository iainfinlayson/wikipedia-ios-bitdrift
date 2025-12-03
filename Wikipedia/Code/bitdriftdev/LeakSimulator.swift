import UIKit
import Foundation

enum LeakSimulator {
    private static var bag = [Data]()
    private static var timer: Timer?

    /// Slow, realistic leak: retains ~1 MB/sec forever (tweak as needed).
    static func startSlowLeak(bytesPerTick: Int = 1_000_000, interval: TimeInterval = 1.0) {
        guard timer == nil else { return } // ignore repeats
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            var d = Data(count: bytesPerTick)
            // Touch pages so memory actually commits (important on Simulator)
            d.withUnsafeMutableBytes { buf in
                let stride = 4096
                var i = 0
                while i < buf.count { buf[i] = 1; i += stride }
            }
            bag.append(d)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Aggressive allocations to crash "soon", not instantly (UI can log/dismiss first).
    static func forceOOMNow(
        chunkBytes: Int = 5_000_000,   // 5 MB
        batchesPerLoop: Int = 5,       // ~25 MB per loop
        sleepMillis: UInt32 = 10       // tiny yield
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var local = [Data]()
            while true {
                autoreleasepool {
                    for _ in 0..<batchesPerLoop {
                        var d = Data(count: chunkBytes)
                        d.withUnsafeMutableBytes { buf in
                            let stride = 4096
                            var i = 0
                            while i < buf.count { buf[i] = 1; i += stride }
                        }
                        local.append(d)
                    }
                }
                usleep(sleepMillis * 1_000)
            }
        }
    }
}
