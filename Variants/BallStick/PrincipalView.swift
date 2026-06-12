import ScreenSaver

/// Principal class for the Ball-and-stick-only saver variant.
@objc(BallStickStructureView)
final class BallStickStructureView: StructureView {
    override var forcedRenderMode: RenderMode? { .ballAndStick }
}
