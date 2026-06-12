import ScreenSaver

/// Principal class for the Spacefill-only saver variant.
@objc(SpacefillStructureView)
final class SpacefillStructureView: StructureView {
    override var forcedRenderMode: RenderMode? { .spacefill }
}
