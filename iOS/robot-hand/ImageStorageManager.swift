import UIKit // For UIImage, needed for easy PNG/JPEG conversion
import SwiftUI // For CGImage
import Zip // For zipping files (using the Zip library)

class ImageStorageManager {

    enum ImageStorageError: Error {
        case couldNotCreateDirectory
        case couldNotConvertToData
        case couldNotSaveImage
        case invalidDirectory
        case couldNotCreateZipFile // New error case
        case couldNotDeleteData // For clearing data errors
        case unknownError

        var localizedDescription: String {
            switch self {
            case .couldNotCreateDirectory:
                return "Failed to create storage directory."
            case .couldNotConvertToData:
                return "Failed to convert image to data format."
            case .couldNotSaveImage:
                return "Failed to save image to disk."
            case .invalidDirectory:
                return "Could not access valid storage directory."
            case .couldNotCreateZipFile: // New description
                return "Failed to create ZIP archive."
            case .couldNotDeleteData:
                return "Failed to delete training data."
            case .unknownError:
                return "An unknown error occurred."
            }
        }
    }

    static let shared = ImageStorageManager() // Singleton for easy access

    private init() {} // Private init for singleton

    private func resizeImage(image: UIImage, targetMaxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxDimension = max(size.width, size.height)

        // If image is already smaller than or equal to target, return original
        if maxDimension <= targetMaxDimension {
            return image
        }

        var newSize: CGSize
        if size.width > size.height {
            // Landscape or square: scale based on width
            let aspectRatio = size.height / size.width
            newSize = CGSize(width: targetMaxDimension, height: targetMaxDimension * aspectRatio)
        } else {
            // Portrait: scale based on height
            let aspectRatio = size.width / size.height
            newSize = CGSize(width: targetMaxDimension * aspectRatio, height: targetMaxDimension)
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let newImage = renderer.image { (context) in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        // If renderer fails (e.g. newSize is zero), return original image to prevent crash
        return newImage.cgImage == nil ? image : newImage 
    }

    private func getTrainingDataDirectoryUrl() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error: Could not find documents directory.")
            return nil
        }
        let trainingDataUrl = documentsDirectory.appendingPathComponent("training_data", isDirectory: true)
        // Ensure the base training_data directory exists
        if !FileManager.default.fileExists(atPath: trainingDataUrl.path) {
            do {
                try FileManager.default.createDirectory(at: trainingDataUrl, withIntermediateDirectories: true, attributes: nil)
                print("Created base training_data directory: \(trainingDataUrl.path)")
            } catch {
                print("Error creating base training_data directory \(trainingDataUrl.path): \(error)")
                return nil // If we can't create it, we can't proceed
            }
        }
        return trainingDataUrl
    }

    func saveImage(_ cgImage: CGImage, forGesture gesture: Gesture) -> Result<URL, ImageStorageError> {
        guard let trainingDataDirectoryUrl = getTrainingDataDirectoryUrl() else {
            return .failure(.invalidDirectory)
        }

        let gestureDirectoryUrl = trainingDataDirectoryUrl.appendingPathComponent(gesture.rawValue, isDirectory: true)

        // Create directories if they don't exist
        do {
            if !FileManager.default.fileExists(atPath: gestureDirectoryUrl.path) {
                try FileManager.default.createDirectory(at: gestureDirectoryUrl, withIntermediateDirectories: true, attributes: nil)
                print("Created directory: \(gestureDirectoryUrl.path)")
            }
        } catch {
            print("Error creating directory \(gestureDirectoryUrl.path): \(error)")
            return .failure(.couldNotCreateDirectory)
        }

        // Convert CGImage to UIImage
        let uiImage = UIImage(cgImage: cgImage)

        // Resize the UIImage
        let resizedUiImage = resizeImage(image: uiImage, targetMaxDimension: 512.0)

        // Convert resized UIImage to Data (e.g., PNG)
        guard let imageData = resizedUiImage.pngData() else { // Or jpegData(compressionQuality: 0.8)
            print("Error: Could not convert CGImage to PNG data.")
            return .failure(.couldNotConvertToData)
        }

        // Create a unique filename
        let timestamp = Int(Date().timeIntervalSince1970 * 1000) // Milliseconds for uniqueness
        let filename = "\(gesture.rawValue)_\(timestamp).png"
        let fileUrl = gestureDirectoryUrl.appendingPathComponent(filename)

        // Save the image data
        do {
            try imageData.write(to: fileUrl)
            print("Successfully saved image to: \(fileUrl.path)")
            return .success(fileUrl)
        } catch {
            print("Error saving image to \(fileUrl.path): \(error)")
            return .failure(.couldNotSaveImage)
        }
    }

    // Function to count images for feedback
    func countImages(forGesture gesture: Gesture) -> Int {
        guard let trainingDataDirectoryUrl = getTrainingDataDirectoryUrl() else { return 0 }
        let gestureDirectoryUrl = trainingDataDirectoryUrl.appendingPathComponent(gesture.rawValue, isDirectory: true)
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: gestureDirectoryUrl, includingPropertiesForKeys: nil)
            return fileURLs.filter { $0.pathExtension.lowercased() == "png" || $0.pathExtension.lowercased() == "jpg" }.count
        } catch {
            // This can happen if the directory doesn't exist yet, which is fine.
            // print("Error listing files for \(gesture.rawValue): \(error)")
            return 0
        }
    }

    // New function to export training data to a ZIP file using the 'Zip' library
    func exportTrainingDataToZip() -> Result<URL, ImageStorageError> {
        guard let sourceDirectoryURL = getTrainingDataDirectoryUrl() else {
            return .failure(.invalidDirectory)
        }

        // Check if the source directory actually contains any files to zip.
        // The Zip library might create an empty zip if the source is empty or doesn't exist,
        // so an explicit check can be useful.
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: sourceDirectoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            if contents.isEmpty {
                print("No files found in training_data to zip.")
                // You might want a specific error case for this, e.g., .noDataToExport
                return .failure(.invalidDirectory) // Or a more specific error
            }
        } catch {
            print("Could not read contents of training_data directory: \(error)")
            return .failure(.invalidDirectory)
        }

        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        // It's good practice to use a unique name for the zip file, e.g., with a timestamp,
        // or ensure it's cleaned up if it's always the same name.
        // For simplicity, we'll use a fixed name here but ensure it's removed if it exists.
        let zipFileURL = temporaryDirectoryURL.appendingPathComponent("training_data_export.zip")

        // Remove existing zip file if it exists to prevent Zip library errors or appending to an old archive.
        if FileManager.default.fileExists(atPath: zipFileURL.path) {
            do {
                try FileManager.default.removeItem(at: zipFileURL)
                print("Removed existing zip file at: \(zipFileURL.path)")
            } catch {
                print("Could not remove existing zip file: \(error)")
                return .failure(.couldNotCreateZipFile) // Or a more specific error
            }
        }

        do {
            // The Zip library can directly zip a directory's contents.
            // The first parameter is an array of URLs to zip. We provide the source directory.
            // The second parameter is the destination URL for the zip file.
            // The third parameter `zipName` is the name of the root folder within the zip file. 
            // If nil, files are at the root. If you want them inside a 'training_data' folder in the zip:
            // try Zip.zipFiles(paths: [sourceDirectoryURL], zipFilePath: zipFileURL, password: nil, progress: nil)
            // This will put the *contents* of sourceDirectoryURL into the zip. 
            // If sourceDirectoryURL is /Documents/training_data/ and it contains Rock/, Paper/, Scissors/,
            // then the zip will contain Rock/, Paper/, Scissors/ at its root.

            // To have a 'training_data' folder inside the zip, you'd typically zip the parent of 'training_data'
            // and specify 'training_data' as one of the paths, or create a temporary structure.
            // For this use case, zipping the contents directly is usually what's desired.
            
            try Zip.zipFiles(paths: [sourceDirectoryURL], zipFilePath: zipFileURL, password: nil, progress: { (progress) -> () in
                print("Zipping progress: \(progress * 100)%")
            })
            
            print("Successfully created ZIP file at: \(zipFileURL.path)")
            return .success(zipFileURL)
        } catch {
            print("Error creating ZIP file: \(error)")
            return .failure(.couldNotCreateZipFile)
        }
    }

    func clearAllTrainingData() -> Result<Void, ImageStorageError> {
        guard let trainingDataUrl = getTrainingDataDirectoryUrl() else {
            // If getTrainingDataDirectoryUrl() itself fails (e.g., can't access Documents), it's an issue.
            // It also attempts to create the directory if it's missing.
            // If it returns nil here, it means the basic setup for the directory failed.
            return .failure(.invalidDirectory) 
        }

        if FileManager.default.fileExists(atPath: trainingDataUrl.path) {
            do {
                try FileManager.default.removeItem(at: trainingDataUrl)
                print("Successfully removed training_data directory.")
            } catch {
                print("Error removing training_data directory: \(error)")
                return .failure(.couldNotDeleteData)
            }
        }

        // After removal or if it didn't exist, ensure the base directory is (re)created for future use.
        // getTrainingDataDirectoryUrl() handles creation if it's missing.
        if getTrainingDataDirectoryUrl() == nil {
            // This would be an unexpected secondary failure if re-creation fails.
            return .failure(.couldNotCreateDirectory)
        }
        
        return .success(())
    }
}
