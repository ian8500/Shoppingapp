import AVFoundation
import SwiftUI

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned, onError: onError)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let viewController = ScannerViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        private let onCodeScanned: (String) -> Void
        private let onError: (String) -> Void

        init(onCodeScanned: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
            self.onError = onError
        }

        func scannerViewController(_ controller: ScannerViewController, didScan code: String) {
            onCodeScanned(code)
        }

        func scannerViewController(_ controller: ScannerViewController, didFail message: String) {
            onError(message)
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func scannerViewController(_ controller: ScannerViewController, didScan code: String)
    func scannerViewController(_ controller: ScannerViewController, didFail message: String)
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasReportedCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasReportedCode = false
        if !session.isRunning {
            session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureCaptureSession() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.scannerViewController(self, didFail: "Camera unavailable on this device")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .qr]
            }

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.layer.bounds
            view.layer.addSublayer(layer)
            previewLayer = layer
        } catch {
            delegate?.scannerViewController(self, didFail: "Failed to configure camera: \(error.localizedDescription)")
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasReportedCode else { return }

        guard let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = readableObject.stringValue
        else {
            return
        }

        hasReportedCode = true
        session.stopRunning()
        delegate?.scannerViewController(self, didScan: code)
    }
}
