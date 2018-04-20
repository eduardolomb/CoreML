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


class ViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var uiRecognitionLabel: UILabel?
    
    @IBOutlet weak var uiCameraView: UIView?
    private var requests = [VNRequest]()
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)

    
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard
            let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: backCamera)
            else { return session }
        session.addInput(input)
        return session
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.uiCameraView?.layer.addSublayer(self.cameraLayer)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyCameraQueue"))
        self.captureSession.addOutput(videoOutput)
        self.captureSession.startRunning()
        setupVision()
       
    }
    
    
    func setupVision() {
        guard let visionModel = try? VNCoreMLModel(for: imageClassifier().model)
            else { fatalError("Can't load VisionML model") }
        let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassifications)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
        self.requests = [classificationRequest]
    }
    
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
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.cameraLayer.frame = self.uiCameraView?.bounds ?? .zero
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
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


}

