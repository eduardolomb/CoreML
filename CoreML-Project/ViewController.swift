//
//  ViewController.swift
//  CoreML-Project
//
//  Created by Eduardo Lombardi on 18/04/2018.
//  Copyright © 2018 Eduardo Lombardi. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision
import Alamofire

class ViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var uiRecognitionLabel: UILabel?
    @IBOutlet weak var uiDownloadBtn: UIButton?
    @IBOutlet weak var uiProgressView: UIProgressView?
    @IBOutlet weak var uiSwitch: UISwitch?
    @IBOutlet weak var uiCameraView: UIView?
    
    
    private var requests = [VNRequest]()
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)

    var fileName = ""
    let url = "https://s3-us-west-2.amazonaws.com/coreml-models/MobileNet.mlmodel"
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    //MARK: - Interface Buttons Functions
    @IBAction func downloadBtnTap(_ sender: UIButton) {
        
        sender.isUserInteractionEnabled = false
        self.captureSession.stopRunning()
        self.cameraLayer.isHidden = true
        self.uiSwitch?.isOn = false
        self.uiSwitch?.isUserInteractionEnabled = false
        
        downloadModel()
    }
    
    @IBAction func validateSwitchTap(_ sender: UISwitch) {
        if sender.isOn {
            setupVision()
            self.cameraLayer.isHidden = false
            uiProgressView?.isHidden = true
            self.captureSession.startRunning()
        } else {
            self.cameraLayer.isHidden = true
            self.uiRecognitionLabel?.text = ""
            self.captureSession.stopRunning()
        }
    }
    
    //MARK: - ViewControllerDelegates
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.uiCameraView?.layer.addSublayer(self.cameraLayer)
        self.cameraLayer.zPosition = -100
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyCameraQueue"))
        self.captureSession.addOutput(videoOutput)
        uiProgressView?.isHidden = true
        uiRecognitionLabel?.text = ""
        uiSwitch?.setOn(false, animated: false)
        setupVision()
       
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        
        let app = UIApplication.shared
        switch app.statusBarOrientation {
        case .portrait:
            cameraLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait;
        case .portraitUpsideDown:
            cameraLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown;
        case .landscapeLeft:
            cameraLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft;
        case .landscapeRight:
            cameraLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight;
        default:
            cameraLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight;
        }
        
        self.cameraLayer.frame = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight)
    }
    
    
    //MARK: - CoreML Classifier and configurer
    func handleClassifications(request: VNRequest, error: Error?) {
        guard let observations = request.results
            else { print("no results: \(error!)"); return }
        
        print(observations)
        let classifications = observations[0...4]
            .flatMap({ $0 as? VNClassificationObservation })
            .filter({ $0.confidence > 0.3 })
            .sorted(by: { $0.confidence > $1.confidence })
            .map {

                (prediction: VNClassificationObservation) -> String in
                return "\(round(prediction.confidence * 100 * 100)/100)%: \(prediction.identifier)"
            
        }
        DispatchQueue.main.async {
            print(classifications.joined(separator: "###"))
            self.uiRecognitionLabel?.text = classifications.joined(separator: "\n")
        }
    }
    
    
    func setupVision() {
        if(fileChecker()) {
            let urlString = URL(string: fileName)
            guard let path = urlString?.path else {
                return
            }
            let url = URL(fileURLWithPath: path)
            guard let compiledUrl = try? MLModel.compileModel(at: url) else {
                fatalError("ruim")
            }
            guard let model = try? MLModel(contentsOf: compiledUrl) else {
                fatalError("ruim")
            }
            
            guard let visionModel = try? VNCoreMLModel(for: model)
                else { fatalError("Can't load VisionML model") }
            let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassifications)
            classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
            self.requests = [classificationRequest]
            
        } else {
            guard let visionModel = try? VNCoreMLModel(for: imageClassifier().model)
                else { fatalError("Can't load VisionML model") }
            let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassifications)
            classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
            self.requests = [classificationRequest]
            
        }
    }

    //MARK: - Core ML model Downloader
    func downloadModel() {
        

        let destination = DownloadRequest.suggestedDownloadDestination(for: .documentDirectory)
        
        Alamofire.download(url, to: destination)
            .downloadProgress { progress in
                self.uiProgressView?.isHidden = false
                let value = progress.fractionCompleted * 100
                let rounded = round(value)
                
                self.uiRecognitionLabel?.text = String(format: "%.1f",rounded) + "%"
                print("Download Progress: \(progress.fractionCompleted)")
                self.uiProgressView?.setProgress(Float(progress.fractionCompleted), animated: true)
               
            
            }
            .response { response in
                print(response)
                self.uiDownloadBtn?.isUserInteractionEnabled = true
                self.uiSwitch?.isUserInteractionEnabled = true
                guard let url = response.destinationURL?.absoluteString else {
                    return
                }
                self.fileName = url
            
        }

    }
    
    
    func fileChecker() -> Bool{
        if fileName.isEmpty {
            return false
        }
        
        let url = URL(string: fileName)
        guard let path = url?.path else {
            return false
        }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            return true
        } else {
            return false
        }
        
    }
    
    
    //MARK: - Camera capture delegates
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        var requestOptions:[VNImageOption : Any] = [:]
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics:cameraIntrinsicData]
        }
        
        guard let value = CGImagePropertyOrientation(rawValue: 1) else {
            return
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation:value , options: requestOptions)
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
    
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        guard
            let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: backCamera)
            else { return session }
        session.addInput(input)
        return session
    }()

}

