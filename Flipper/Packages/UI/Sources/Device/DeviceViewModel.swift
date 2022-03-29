import Core
import Inject
import Peripheral
import Foundation
import Combine

@MainActor
class DeviceViewModel: ObservableObject {
    private let rpc: RPC = .shared
    private let appState: AppState = .shared
    private var disposeBag: DisposeBag = .init()

    @Published var showPairingIssueAlert = false
    @Published var showUnsupportedVersionAlert = false

    @Published var flipper: Flipper?
    @Published var status: DeviceStatus = .noDevice {
        didSet {
            switch status {
            case .pairingIssue: showPairingIssueAlert = true
            case .unsupportedDevice: showUnsupportedVersionAlert = true
            default: break
            }
        }
    }

    var protobufVersion: String {
        guard status != .unsupportedDevice else { return "—" }
        guard status != .noDevice, status != .disconnected else { return "—" }
        return flipper?.information?.protobufRevision ?? ""
    }

    var firmwareVersion: String {
        guard status != .noDevice, status != .disconnected else { return "—" }
        guard let info = flipper?.information else { return "" }

        let version = info
            .softwareRevision
            .split(separator: " ")
            .dropFirst()
            .prefix(1)
            .joined()

        return .init(version)
    }

    var firmwareBuild: String {
        guard status != .noDevice, status != .disconnected else { return "—" }
        guard let info = flipper?.information else { return "" }

        let build = info
            .softwareRevision
            .split(separator: " ")
            .suffix(1)
            .joined(separator: " ")

        return .init(build)
    }

    var internalSpace: String {
        guard status != .unsupportedDevice else { return "—" }
        guard status != .noDevice, status != .disconnected else { return "—" }
        return flipper?.storage?.internal?.description ?? ""
    }

    var externalSpace: String {
        guard status != .unsupportedDevice else { return "—" }
        guard status != .noDevice, status != .disconnected else { return "—" }
        return flipper?.storage?.external?.description ?? ""
    }

    init() {
        appState.$flipper
            .receive(on: DispatchQueue.main)
            .assign(to: \.flipper, on: self)
            .store(in: &disposeBag)

        appState.$status
            .receive(on: DispatchQueue.main)
            .assign(to: \.status, on: self)
            .store(in: &disposeBag)
    }

    func showWelcomeScreen() {
        appState.forgetDevice()
        appState.isFirstLaunch = true
    }

    func sync() {
        Task { await appState.synchronize() }
    }

    func playAlert() {
        Task {
            try await rpc.playAlert()
        }
    }
}

extension String {
    static var noDevice: String { "No device" }
    static var unknown: String { "Unknown" }
}

extension StorageSpace: CustomStringConvertible {
    public var description: String {
        "\(free.hr) / \(total.hr)"
    }
}

extension Int {
    var hr: String {
        let formatter = ByteCountFormatter()
        return formatter.string(fromByteCount: Int64(self))
    }
}