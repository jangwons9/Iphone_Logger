# iPhone Trajectory Logger - ViewController

This repository contains the main `ViewController.swift` file for an iPhone app designed to log IMU data (gyroscope and accelerometer) and capture video frames.

## Features
- Logs gyroscope and accelerometer data at high frequency (200Hz).
- Captures video frames at 20 FPS and saves them as PNG images.
- Outputs structured data in CSV files for further analysis.

## File Overview
- **ViewController.swift**: Implements the core functionality for IMU data logging, video capture, and file storage.

## Requirements
- CoreMotion and AVFoundation frameworks.

## Usage
1. Integrate `ViewController.swift` into your Xcode project.
2. Set up necessary permissions in the `Info.plist` file:
   - `Privacy - Camera Usage Description`
   - `Privacy - Motion Usage Description`
3. Build and run on an iOS device.
4. Data will be saved in the app's Documents directory under `/mav0`.

## Notes
This repository only includes the `ViewController.swift` file. To build the full app, additional project files such as `AppDelegate.swift`, `Info.plist`, and the `.xcodeproj` are required.

## License
This project is licensed under the MIT License.
