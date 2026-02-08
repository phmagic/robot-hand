//
//  DocumentPicker.swift
//  rps-robot-hand
//
//  Created by Phu Nguyen on 6/9/25.
//

import UIKit // Ensure UIKit is imported for UIViewControllerRepresentable
import SwiftUI

struct DocumentPicker: UIViewControllerRepresentable {
    var url: URL // URL of the file to export

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // For exporting, action should be .exportToService or .moveToService
        // .exportToService is generally preferred for "Save As..." type functionality.
        let controller = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No update needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // This delegate method is called when the user selects a destination or cancels.
            if let pickedURL = urls.first {
                print("File exported/picked at: \(pickedURL)")
                // You could potentially clean up the temporary zip file from parent.url here if desired,
                // but UIDocumentPickerViewController usually handles the copy.
            } else {
                print("Document picker operation concluded (cancelled or failed).")
            }
            // Reset the state in ContentView to dismiss the sheet
            // This needs to be done carefully, perhaps via a binding or callback if direct access isn't clean.
            // For now, the sheet will dismiss when zipFileURLToExport becomes nil again if it's a @State.
            // If zipFileURLToExport is an @State, setting it to nil in ContentView after this delegate fires would be one way.
            // However, the .sheet(item: $zipFileURLToExport) handles dismissal automatically when item becomes nil.
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("Document picker was cancelled by the user.")
            // As above, sheet dismissal is handled by the binding.
        }
    }
}

// Helper to make URL identifiable for .sheet(item:)
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

