//
//  ViewController.swift
//  CoreML-Project
//
//  Created by Eduardo Lombardi on 18/04/2018.
//  Copyright © 2018 Eduardo Lombardi. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var uiRecognitionLabel: UILabel?
    
    @IBOutlet weak var uiCameraView: UIView?

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

       
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.cameraLayer.frame = self.uiCameraView?.bounds ?? .zero
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

