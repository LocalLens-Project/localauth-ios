import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onCodeScanned = { code in
            onCodeScanned(code)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onCodeScanned: ((String) -> Void)?
        private let captureSession = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var hasScanned = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            setupCamera()
            setupOverlay()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            captureSession.stopRunning()
        }

        private func setupCamera() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            let output = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.qr]
            }

            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            previewLayer = layer
        }

        private func setupOverlay() {
            // Viewfinder frame / 取景框
            let frameSize: CGFloat = 250
            let frameView = UIView()
            frameView.layer.borderColor = UIColor.cyan.cgColor
            frameView.layer.borderWidth = 2
            frameView.layer.cornerRadius = 12
            frameView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(frameView)

            NSLayoutConstraint.activate([
                frameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                frameView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
                frameView.widthAnchor.constraint(equalToConstant: frameSize),
                frameView.heightAnchor.constraint(equalToConstant: frameSize),
            ])

            // Torch toggle button / 手电筒按钮
            let torchButton = UIButton(type: .system)
            torchButton.setImage(UIImage(systemName: "flashlight.off.fill"), for: .normal)
            torchButton.tintColor = .white
            torchButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            torchButton.layer.cornerRadius = 22
            torchButton.translatesAutoresizingMaskIntoConstraints = false
            torchButton.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)
            view.addSubview(torchButton)

            NSLayoutConstraint.activate([
                torchButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                torchButton.topAnchor.constraint(equalTo: frameView.bottomAnchor, constant: 40),
                torchButton.widthAnchor.constraint(equalToConstant: 44),
                torchButton.heightAnchor.constraint(equalToConstant: 44),
            ])
        }

        @objc private func toggleTorch() {
            guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
            try? device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            device.unlockForConfiguration()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            Task { @MainActor in
                guard !hasScanned,
                      let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                      let value = object.stringValue else { return }
                hasScanned = true
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                onCodeScanned?(value)
            }
        }
    }
}
