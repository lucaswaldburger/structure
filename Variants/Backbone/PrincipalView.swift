import ScreenSaver

/// Principal class for the Backbone-only saver variant.
@objc(BackboneStructureView)
final class BackboneStructureView: StructureView {
    override var forcedRenderMode: RenderMode? { .backbone }
}
