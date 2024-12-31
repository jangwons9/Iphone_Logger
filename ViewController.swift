import CoreMotion
import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var gyrox: UILabel!
    @IBOutlet weak var gyroy: UILabel!
    @IBOutlet weak var gyroz: UILabel!
    @IBOutlet weak var accela: UILabel!
    @IBOutlet weak var accely: UILabel!
    @IBOutlet weak var accelz: UILabel!

    let motion = CMMotionManager()
    let captureSession = AVCaptureSession()
    var videoDataOutput = AVCaptureVideoDataOutput()
    var outputFolder: URL?
    var timer: Timer?

    var lastIMUTimestamp: Int64?
    var latestGyroData: CMGyroData?
    var latestAccelerometerData: CMAccelerometerData?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupOutputFolder()
        setupCaptureSession()
        startIMUUpdates()
    }

    func setupOutputFolder() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let baseFolderPath = URL(fileURLWithPath: documentsPath).appendingPathComponent("mav0")
        
        // Create cam0 and imu0 directories inside CameraFrames
        let camFolderPath = baseFolderPath.appendingPathComponent("cam0")
        let imuFolderPath = baseFolderPath.appendingPathComponent("imu0")
        let camDataFolderPath = camFolderPath.appendingPathComponent("data") // New data folder inside cam0

        do {
            try FileManager.default.createDirectory(at: camFolderPath, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(at: imuFolderPath, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.createDirectory(at: camDataFolderPath, withIntermediateDirectories: true, attributes: nil)
            outputFolder = baseFolderPath

            // Initialize IMU CSV file with headers
            let imuCSVFileURL = imuFolderPath.appendingPathComponent("/imu0/data.csv")
            let imuHeader = "#timestamp [ns],w_RS_S_x [rad s^-1],w_RS_S_y [rad s^-1],w_RS_S_z [rad s^-1],a_RS_S_x [m s^-2],a_RS_S_y [m s^-2],a_RS_S_z [m s^-2]\r\n"
            try imuHeader.write(to: imuCSVFileURL, atomically: true, encoding: .utf8)

            // Initialize camera frames CSV file with headers
            let cameraCSVFileURL = camFolderPath.appendingPathComponent("/cam0/data.csv")
            let cameraHeader = "#timestamp [ns],filename\r\n"
            try cameraHeader.write(to: cameraCSVFileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error creating folder or initializing CSV files: \(error)")
        }
    }

    func startIMUUpdates() {
//        motion.gyroUpdateInterval = 0.01 // 100Hz
//        motion.accelerometerUpdateInterval = 0.01 // 100Hz
          motion.gyroUpdateInterval = 0.005 // 100Hz
          motion.accelerometerUpdateInterval = 0.005 // 100Hz
        
        guard motion.isGyroAvailable, motion.isAccelerometerAvailable else {
            print("Gyroscope or Accelerometer not available")
            return
        }

        motion.startGyroUpdates(to: OperationQueue.main) { [weak self] (gyroData, error) in
            if let gyroData = gyroData {
                self?.latestGyroData = gyroData
            } else if let error = error {
                print("Gyroscope update error: \(error)")
            }
        }

        motion.startAccelerometerUpdates(to: OperationQueue.main) { [weak self] (accelerometerData, error) in
            if let accelerometerData = accelerometerData {
                self?.latestAccelerometerData = accelerometerData
            } else if let error = error {
                print("Accelerometer update error: \(error)")
            }
        }

        // Timer to write data at 100Hz
//        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
//            self?.writeIMUDataToCSV()
//        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.005, repeats: true) { [weak self] _ in
            self?.writeIMUDataToCSV()
        }
    }

    func writeIMUDataToCSV() {
        guard let outputFolder = outputFolder else {
            print("Output folder is nil")
            return
        }

        // Ensure both gyro and accelerometer data are available
        guard let gyroData = latestGyroData, let accelerometerData = latestAccelerometerData else {
            return
        }

        // Get current time in nanoseconds since 1970
        let timestamp = Int64(Date().timeIntervalSince1970 * 1_000_000_000) // Convert to nanoseconds

        let accelX = accelerometerData.acceleration.x * -9.81
        let accelY = (accelerometerData.acceleration.y * -9.81)
        let accelZ = accelerometerData.acceleration.z * -9.81
        
        
        let output = "\(timestamp),\(gyroData.rotationRate.x),\(gyroData.rotationRate.y),\(gyroData.rotationRate.z),\(accelX),\(accelY),\(accelZ)\r\n"

        let imuCSVFileURL = outputFolder.appendingPathComponent("imu0/data.csv")
        do {
            if FileManager.default.fileExists(atPath: imuCSVFileURL.path) {
                // Append to the existing file
                let fileHandle = try FileHandle(forWritingTo: imuCSVFileURL)
                fileHandle.seekToEndOfFile()
                if let data = output.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                // Create a new file and write the content
                let imuHeader = "#timestamp [ns],w_RS_S_x [rad s^-1],w_RS_S_y [rad s^-1],w_RS_S_z [rad s^-1],a_RS_S_x [m s^-2],a_RS_S_y [m s^-2],a_RS_S_z [m s^-2]\r\n"
                try (imuHeader + output).write(to: imuCSVFileURL, atomically: true, encoding: .utf8)
            }
            print("IMU data appended to: \(imuCSVFileURL.path)")
        } catch {
            print("Error writing IMU data to file: \(error)")
        }
    }

    func setupCaptureSession() {
        captureSession.sessionPreset = .vga640x480 // Set the preset to VGA

        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Unable to access back camera")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            captureSession.addInput(input)
            
            // Set video output settings
            videoDataOutput.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32BGRA),
            ]
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
            captureSession.addOutput(videoDataOutput)

            try backCamera.lockForConfiguration()
            backCamera.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 20) // 20 FPS
            backCamera.unlockForConfiguration()

            captureSession.startRunning()
        } catch {
            print("Error setting up capture session: \(error)")
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let outputFolder = outputFolder else {
            print("Output folder is nil")
            return
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let timestampInNanoseconds = Int64(timestamp * 1_000_000_000) // Convert to nanoseconds

        // Convert sample buffer timestamp to POSIX nanoseconds
        let posixTimestamp = Int64(Date().timeIntervalSince1970 * 1_000_000_000)

        let fileName = "\(posixTimestamp).png"
        let fileURL = outputFolder.appendingPathComponent("cam0/data").appendingPathComponent(fileName)


        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            
            // Convert to grayscale
            //let grayscaleFilter = CIFilter(name: "CIColorControls")!
            //grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
            //grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey)
            //let grayscaleImage = grayscaleFilter.outputImage!
            
            // Rotate 90 degrees clockwise
            let rotatedImage = ciImage.oriented(.right)

            //let rotatedImage = ciImage
            
            let context = CIContext()
            
            if let cgImage = context.createCGImage(rotatedImage, from: rotatedImage.extent) {
                let image = UIImage(cgImage: cgImage)
                if let pngData = image.pngData() {
                    do {
                        try pngData.write(to: fileURL)
                        print("Image written to: \(fileURL.path)")
                    } catch {
                        print("Error writing image to file: \(error)")
                    }
                } else {
                    print("Failed to convert image to PNG data")
                }

                let csvOutput = "\(posixTimestamp),\(fileName)\r\n"
                let csvFileURL = outputFolder.appendingPathComponent("cam0/data.csv")
                do {
                    if FileManager.default.fileExists(atPath: csvFileURL.path) {
                        // Append to the existing file
                        let fileHandle = try FileHandle(forWritingTo: csvFileURL)
                        fileHandle.seekToEndOfFile()
                        if let data = csvOutput.data(using: .utf8) {
                            fileHandle.write(data)
                        }
                        fileHandle.closeFile()
                    } else {
                        // Create a new file and write the header
                        let header = "#timestamp [ns],filename\r\n"
                        try (header + csvOutput).write(to: csvFileURL, atomically: true, encoding: .utf8)
                    }
                    print("CSV entry written to: \(csvFileURL.path)")
                } catch {
                    print("Error writing CSV entry to file: \(error)")
                }
            } else {
                print("Failed to create CGImage from CIImage")
            }
        } else {
            print("Failed to get image buffer from sample buffer")
        }
    }

}


