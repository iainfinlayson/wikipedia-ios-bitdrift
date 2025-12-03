import UIKit

#if canImport(Capture)
import Capture
#endif

// Logger shim so this compiles even if Capture isn't linked in some targets.
#if canImport(Capture)
enum BDLogger {
    static func logWarning(_ message: String, fields: [String: String]) {
        Capture.Logger.logWarning(message, fields: fields)
    }
}
#else
enum BDLogger {
    static func logWarning(_ message: String, fields: [String: String]) { /* no-op */ }
}
#endif

final class DebugMenuViewController: UITableViewController {
    private enum Row: Int, CaseIterable {
        case startSlowLeak, forceOOMNow
        var title: String {
            switch self {
            case .startSlowLeak: return "Start Slow Leak (+1 MB/s)"
            case .forceOOMNow:   return "Force OOM Now"
            }
        }
        var subtitle: String {
            switch self {
            case .startSlowLeak: return "Gradual, realistic heap growth retained forever"
            case .forceOOMNow:
                #if targetEnvironment(simulator)
                return "Aggressive allocations; Simulator may self-crash later"
                #else
                return "Aggressive allocations to crash soon"
                #endif
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Debug Menu"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped)
        )
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        guard let row = Row(rawValue: indexPath.row) else { return cell }
        var conf = UIListContentConfiguration.subtitleCell()
        conf.text = row.title
        conf.secondaryText = row.subtitle
        cell.contentConfiguration = conf
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = Row(rawValue: indexPath.row) else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Dismiss first so UI gets out of the way, then run action & log.
        dismiss(animated: true) {
            switch row {
            case .startSlowLeak:
                LeakSimulator.startSlowLeak()
                BDLogger.logWarning(
                    "Memory Leak Simulation Started",
                    fields: [
                        "type": "slowLeak",
                        "rate": "1MB/sec",
                        "trigger": "safeCornerLongPress",
                        "screen": String(describing: type(of: self))
                    ]
                )
            case .forceOOMNow:
                DispatchQueue.main.async {
                    LeakSimulator.forceOOMNow()
                    BDLogger.logWarning(
                        "Force OOM Simulation Started",
                        fields: [
                            "type": "forceOOM",
                            "chunk": "5MB*5",
                            "trigger": "safeCornerLongPress",
                            "screen": String(describing: type(of: self))
                        ]
                    )
                }
            }
        }
    }
}
