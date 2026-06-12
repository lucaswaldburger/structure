import ScreenSaver

/// Principal class for the Cartoon-only saver variant.
@objc(CartoonStructureView)
final class CartoonStructureView: StructureView {
    override var forcedRenderMode: RenderMode? { .cartoon }
}
