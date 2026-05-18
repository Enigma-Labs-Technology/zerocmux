import AppKit
import SwiftUI

struct DetachedFolderDragIcon: NSViewRepresentable {
    let directory: String

    func makeNSView(context: Context) -> DraggableFolderNSView {
        DraggableFolderNSView(directory: directory)
    }

    func updateNSView(_ nsView: DraggableFolderNSView, context: Context) {
        if nsView.directory != directory {
            nsView.directory = directory
            nsView.updateIcon()
        }
    }
}
