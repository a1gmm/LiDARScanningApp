import SwiftUI

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
  
    init(fileToExport: Data) {
        let temporaryFolder = FileManager.default.temporaryDirectory
        let fileName = "SceneMesh-\(Date()).data"
        
        let temporaryFileURL = temporaryFolder.appendingPathComponent(fileName)
        try! fileToExport.write(to: temporaryFileURL)
        
        activityItems = [temporaryFileURL]
    }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let controller = UIActivityViewController(activityItems: activityItems,
                                                  applicationActivities: nil)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
}
