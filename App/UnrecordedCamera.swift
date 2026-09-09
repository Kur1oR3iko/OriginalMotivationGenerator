import SwiftUI
import AVFoundation
import UIKit

private final class PreviewSessionDriver {
    enum Failure: Error { case noCamera, configuration }
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.kurio.unrecorded-camera")
    private var configured = false

    func start(completion: @escaping (Result<Void, Failure>) -> Void) {
        queue.async {
            if !self.configured {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                        ?? AVCaptureDevice.default(for: .video) else {
                    completion(.failure(.noCamera))
                    return
                }
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    self.session.beginConfiguration()
                    if self.session.canSetSessionPreset(.high) { self.session.sessionPreset = .high }
                    guard self.session.canAddInput(input) else {
                        self.session.commitConfiguration()
                        completion(.failure(.configuration))
                        return
                    }
                    self.session.addInput(input)
                    // Preview only: no photo output, recording output, or image file is created.
                    self.session.commitConfiguration()
                    self.configured = true
                } catch {
                    completion(.failure(.configuration))
                    return
                }
            }
            if !self.session.isRunning { self.session.startRunning() }
            completion(self.session.isRunning ? .success(()) : .failure(.configuration))
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }
}

@MainActor
final class UnrecordedCamera: ObservableObject {
    enum Status { case idle, preparing, ready, denied, unavailable, failed }
    @Published private(set) var status: Status = .idle
    @Published private(set) var countdown: Int?
    @Published private(set) var flash = false
    @Published private(set) var isShuttering = false
    private let driver = PreviewSessionDriver()
    private var generation = 0
    private var shutterTask: Task<Void, Never>?
    var session: AVCaptureSession { driver.session }

    func activate() async {
        generation += 1
        let ticket = generation
        status = .preparing
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: granted = true
        case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
        default: granted = false
        }
        guard generation == ticket, !Task.isCancelled else { return }
        guard granted else { status = .denied; return }
        let result: Result<Void, PreviewSessionDriver.Failure> = await withCheckedContinuation { continuation in
            driver.start { continuation.resume(returning: $0) }
        }
        guard generation == ticket, !Task.isCancelled else { return }
        switch result {
        case .success: status = .ready
        case .failure(.noCamera): status = .unavailable
        case .failure(.configuration): status = .failed
        }
    }

    func deactivate() {
        generation += 1
        shutterTask?.cancel()
        shutterTask = nil
        countdown = nil
        flash = false
        isShuttering = false
        status = .idle
        driver.stop()
    }

    func pressShutter() {
        guard status == .ready, !isShuttering else { return }
        isShuttering = true
        let ticket = generation
        shutterTask = Task { @MainActor in
            do {
                for number in [3, 2, 1] {
                    countdown = number
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
                try Task.checkCancellation()
                guard generation == ticket else { return }
                countdown = nil
                flash = true
                try await Task.sleep(nanoseconds: 100_000_000)
                flash = false
                try await Task.sleep(nanoseconds: 250_000_000)
                isShuttering = false
                shutterTask = nil
            } catch { return }
        }
    }
}

struct UnrecordedCameraView: View {
    @ObservedObject var camera: UnrecordedCamera
    let isActive: Bool

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if isActive && camera.status == .ready {
                CameraPreview(session: camera.session).ignoresSafeArea()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "camera").font(.system(size: 36, weight: .light))
                    Text(statusText).font(.body).multilineTextAlignment(.center)
                    if camera.status == .denied {
                        Button(L("打开相机权限设置")) {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(32)
            }
            if let number = camera.countdown {
                Text(String(number))
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 8)
                    .accessibilityLabel(L("倒计时%ld", number))
            }
            VStack {
                Spacer()
                Button { camera.pressShutter() } label: {
                    Circle()
                        .strokeBorder(camera.status == .ready ? Color.white : Color.gray, lineWidth: 3)
                        .frame(width: 72, height: 72)
                        .overlay(Circle().fill(camera.status == .ready ? Color.white : Color.gray.opacity(0.3)).padding(7))
                        .shadow(color: .black.opacity(0.15), radius: 4)
                }
                .buttonStyle(.plain)
                .disabled(camera.status != .ready || camera.isShuttering || !isActive)
                .accessibilityLabel(L("快门，三秒后拍照"))
                .padding(.bottom, 24)
            }
            Color.white.opacity(camera.flash ? 1 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.15), value: camera.flash)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var statusText: String {
        switch camera.status {
        case .idle, .preparing: return L("相机准备中")
        case .ready: return ""
        case .denied: return L("需要相机权限才能取景")
        case .unavailable: return L("这台设备没有可用相机")
        case .failed: return L("相机暂时无法使用，请稍后再试")
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) { view.setNeedsLayout() }
    static func dismantleUIView(_ view: PreviewView, coordinator: ()) { view.previewLayer.session = nil }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            guard let connection = previewLayer.connection, connection.isVideoOrientationSupported else { return }
            switch window?.windowScene?.interfaceOrientation {
            case .landscapeLeft: connection.videoOrientation = .landscapeLeft
            case .landscapeRight: connection.videoOrientation = .landscapeRight
            case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
            default: connection.videoOrientation = .portrait
            }
        }
    }
}
