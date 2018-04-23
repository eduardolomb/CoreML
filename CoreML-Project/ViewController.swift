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

    @IBOutlet weak var uiProgressView: UIProgressView?
    @IBOutlet weak var uiDownloadLabel: UILabel?
    
    @IBOutlet weak var uiSwitch: UISwitch?
    @IBOutlet weak var uiCameraView: UIView?
    private var requests = [VNRequest]()
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)

    var downloaded = false
    
    
    //MARK: - Interface Buttons Functions
    
    @IBAction func downloadBtnTap(_ sender: Any) {
        self.captureSession.stopRunning()
        self.cameraLayer.isHidden = true
        self.uiSwitch?.isOn = false
        downloadModel()
    }
    
    @IBAction func validateSwitchTap(_ sender: UISwitch) {
        if sender.isOn {
            setupVision()
            self.cameraLayer.isHidden = false
            self.captureSession.startRunning()
        } else {
            self.captureSession.stopRunning()
        }
    }
    
    //MARK: - ViewControllerDelegates
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.uiCameraView?.layer.addSublayer(self.cameraLayer)
        self.cameraLayer.zPosition = -100
//        self.uiProgressView?.layer.zPosition = 100
//        self.uiDownloadLabel?.layer.zPosition = 100
//        self.uiSwitch?.layer.zPosition = 100
//        self.uiRecognitionLabel?.layer.zPosition = 100
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyCameraQueue"))
        self.captureSession.addOutput(videoOutput)
        uiProgressView?.isHidden = true
        uiRecognitionLabel?.text = ""
        uiDownloadLabel?.text = ""
        uiSwitch?.setOn(false, animated: false)
        setupVision()
       
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
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
                print("encontrado")
                return "\(round(prediction.confidence * 100 * 100)/100)%: \(prediction.identifier)"
            
        }
        DispatchQueue.main.async {
            print(classifications.joined(separator: "###"))
            self.uiRecognitionLabel?.text = classifications.joined(separator: "\n")
        }
    }
    
    
    func setupVision() {
        if(downloaded) {
            let fm = FileManager.default
            let docsurl = try! fm.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let myurl = docsurl.appendingPathComponent("MobileNet.mlmodel")
            guard let compiledUrl = try? MLModel.compileModel(at: myurl) else {
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
        
        let urlString = "https://s3-us-west-2.amazonaws.com/coreml-models/MobileNet.mlmodel"
        let destination = DownloadRequest.suggestedDownloadDestination(for: .documentDirectory)
        
        Alamofire.download(urlString, to: destination)
            .downloadProgress { progress in
                self.uiProgressView?.isHidden = false
                let value = progress.fractionCompleted * 100
                let rounded = round(value)
                
                self.uiDownloadLabel?.text = String(format: "%.1f",rounded) + "%"
                
                print("Download Progress: \(progress.fractionCompleted)")
                
                self.uiProgressView?.setProgress(Float(progress.fractionCompleted), animated: true)
               
            
            }
            .responseData { response in
                self.downloaded = true
                if let data = response.result.value {
                    print("file downloaded")
                    self.downloaded = true
                    self.uiProgressView?.isHidden = false
                }
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

