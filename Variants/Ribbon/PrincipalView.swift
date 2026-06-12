import ScreenSaver

/// Principal class for the Ribbon-only saver variant.
@objc(RibbonStructureView)
final class RibbonStructureView: StructureView {
    override var forcedRenderMode: RenderMode? { .ribbon }
}
