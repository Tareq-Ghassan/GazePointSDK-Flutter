import AVFoundation
import UIKit

/// Live camera preview plus white face-box overlay, owned by the iOS SDK.
@available(iOS 16.0, *)
public final class GazePreviewView: UIView {
    public override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    public var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    private let boxesLayer = CAShapeLayer()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        boxesLayer.fillColor = UIColor.clear.cgColor
        boxesLayer.strokeColor = UIColor.white.cgColor
        boxesLayer.lineWidth = 3
        layer.addSublayer(boxesLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        boxesLayer.fillColor = UIColor.clear.cgColor
        boxesLayer.strokeColor = UIColor.white.cgColor
        boxesLayer.lineWidth = 3
        layer.addSublayer(boxesLayer)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
        boxesLayer.frame = bounds
    }

    /// Vision boxes are normalized, origin at the bottom-left of the oriented image.
    public func setFaceBoxes(
        _ visionBoxes: [CGRect],
        imageSize: CGSize,
        flipX: Bool
    ) {
        let path = UIBezierPath()
        for box in visionBoxes {
            path.append(
                UIBezierPath(
                    rect: FaceBoxMapping.mapVisionBox(
                        box,
                        imageSize: imageSize,
                        viewSize: bounds.size,
                        flipX: flipX
                    )
                )
            )
        }
        boxesLayer.path = path.cgPath
    }

    public func clearFaceBoxes() {
        boxesLayer.path = nil
    }
}
