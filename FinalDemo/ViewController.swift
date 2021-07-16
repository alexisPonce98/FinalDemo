//
//  ViewController.swift
//  FinalDemo
//
//  Created by Alexis Ponce on 7/13/21.
//

import UIKit
import HaishinKit
import HealthKit
import CoreLocation
import AVFoundation
import AVKit
import ReplayKit
import VideoToolbox
class ViewController: UIViewController, StreamDelegate, RPScreenRecorderDelegate {

    //MARK:variable decl
    //rtmp varables
    let rtmpConnection = RTMPConnection()
    var rtmpStream:RTMPStream!
    var streamClass:Stream!
    
    //AV caputre variables
    var multiCapSession:AVCaptureMultiCamSession!
    var frontPreviewLayer:AVCaptureVideoPreviewLayer!
    var backPreviewLayer:AVCaptureVideoPreviewLayer!
    var frontCamOutput:AVCaptureMovieFileOutput!
    var backCamOutput:AVCaptureMovieFileOutput!
    
    @IBOutlet weak var LargeView: UIView!
    @IBOutlet weak var smallView: UIView!
    
    //screen recording variables
    var screenRecorder:RPScreenRecorder!
    //location variables
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.screenRecorder = RPScreenRecorder.shared();
        showCameras();
    }
    
    func showCameras(){
        guard AVCaptureMultiCamSession.isMultiCamSupported else{
            print("Muli camera capture is not supported on this device :(");
            return;
        }
        self.multiCapSession = AVCaptureMultiCamSession()
        let frontCam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front);
        let backCam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back);
        let mic = AVCaptureDevice.default(for: .audio)
        let (frontCamPort, backCamPort, micPort) = self.camSessionInputsAndOutputs(frontCam: frontCam!, backCam: backCam!, mic: mic!);
        
        self.backPreviewLayer = AVCaptureVideoPreviewLayer()
        self.backPreviewLayer.setSessionWithNoConnection(self.multiCapSession);
        self.backPreviewLayer.connection?.videoOrientation = .portrait;
        self.backPreviewLayer.videoGravity = .resizeAspectFill;
        
        self.frontPreviewLayer = AVCaptureVideoPreviewLayer();
        self.frontPreviewLayer.setSessionWithNoConnection(self.multiCapSession);
        self.frontPreviewLayer.connection?.videoOrientation = .portrait;
        self.frontPreviewLayer.videoGravity = .resizeAspectFill;
        
        //setting up the connections
        guard let frontCameraPort = frontCamPort else{
            print("FrontCamPort does not have a value");
            return
        }
        
        guard let backCameraPort = backCamPort else{
            print("BackCamPort does not have a value");
            return;
        }
        guard let micInputPort = micPort else{
            print("micPort does not have a value")
            return
        }
        guard setUpCaptureSessionConnections(frontCamPort: frontCameraPort, backCamPort: backCameraPort, micPort: micInputPort) else{
            print("The capture session Connections were not set up correctly");
            return;
        }
        
        self.LargeView.layer.addSublayer(self.backPreviewLayer);
        self.smallView.layer.addSublayer(self.frontPreviewLayer);
        
        self.view.addSubview(LargeView);
       // self.view.sendSubviewToBack(LargeView);
        self.view.addSubview(smallView);
        //self.view.sendSubviewToBack(smallView);
        
        DispatchQueue.main.async {
            self.multiCapSession.startRunning();
            self.frontPreviewLayer.bounds = self.smallView.bounds;
            self.backPreviewLayer.bounds = self.LargeView.bounds;
        }
    }
    
    func setUpCaptureSessionConnections(frontCamPort:AVCaptureInput.Port, backCamPort:AVCaptureInput.Port, micPort:AVCaptureInput.Port)->Bool{
        
        self.multiCapSession.beginConfiguration()
        let frontVidPreviewLayerConnection = AVCaptureConnection(inputPort:frontCamPort, videoPreviewLayer: self.frontPreviewLayer);
        if(self.multiCapSession.canAddConnection(frontVidPreviewLayerConnection)){
            self.multiCapSession.addConnection(frontVidPreviewLayerConnection);
        }else{
            print("Could not add the frontPreviewLayer connection");
            return false;
        }
        self.multiCapSession.commitConfiguration();
        self.multiCapSession.beginConfiguration();
        let frontVideOuputConnection = AVCaptureConnection(inputPorts: [frontCamPort], output: self.frontCamOutput);
        if(self.multiCapSession.canAddConnection(frontVideOuputConnection)){
            self.multiCapSession.addConnection(frontVideOuputConnection);
        }
        else{
            print("Could not add the frontVidOutputConnection");
            return false;
        }
        self.multiCapSession.commitConfiguration();
        
        let backVideoPreviewLayerConnection = AVCaptureConnection(inputPort: backCamPort, videoPreviewLayer: self.backPreviewLayer);
        if(self.multiCapSession.canAddConnection(backVideoPreviewLayerConnection)){
            self.multiCapSession.addConnection(backVideoPreviewLayerConnection);
        }
        else{
            print("Could not add the backVideoOutputConnection");
            return false;
        }
        let backVidOuputConnection = AVCaptureConnection(inputPorts: [backCamPort], output: self.backCamOutput);
        if(self.multiCapSession.canAddConnection(backVidOuputConnection)){
            self.multiCapSession.addConnection(backVidOuputConnection);
        }
        else{
            print("Could not add the backOutput Connection");
            return false;
        }
        
        let frontCamAudioConnection = AVCaptureConnection(inputPorts: [micPort], output: self.frontCamOutput);
        if(self.multiCapSession.canAddConnection(frontCamAudioConnection)){
            self.multiCapSession.addConnection(frontCamAudioConnection);
        }else{
            print("Coult not add audio connection to the front cam");
            return false;
        }
        let backCamAudioConnection = AVCaptureConnection(inputPorts: [micPort], output: self.backCamOutput);
        if(self.multiCapSession.canAddConnection(backCamAudioConnection)){
            self.multiCapSession.addConnection(backCamAudioConnection);
        }else{
            print("Could not add the audio connection to the back cam");
            return false;
        }
        self.multiCapSession.commitConfiguration()
        return true;
    }
    
    func camSessionInputsAndOutputs(frontCam:AVCaptureDevice!, backCam:AVCaptureDevice!, mic:AVCaptureDevice!)-> (AVCaptureInput.Port?,AVCaptureInput.Port?, AVCaptureInput.Port?){
        var frontCamVidPort:AVCaptureInput.Port!;
        var backCamVidPort:AVCaptureInput.Port!;
        var micAudioPort:AVCaptureInput.Port!
        self.frontCamOutput = AVCaptureMovieFileOutput()
        self.backCamOutput = AVCaptureMovieFileOutput()
        
        self.multiCapSession.beginConfiguration()
        
        //adding the inputs to the capture seesion and finding the ports
        do{
            let frontCamInput = try AVCaptureDeviceInput(device: frontCam)
            let frontCamInputPortsArray = frontCamInput.ports;
            if(self.multiCapSession.canAddInput(frontCamInput)){
                self.multiCapSession.addInputWithNoConnections(frontCamInput);
            }
            else{
                print("There was a problem trying to add the front cam input to the capture session");
                return(nil,nil,nil)
            }
            for port in frontCamInputPortsArray{
                if(port.mediaType == .video){
                    frontCamVidPort = port;
                }
            }
        }catch let error{
            print("There was an error when trying to get the front camera devices input: \(String(describing: error.localizedDescription))")
            return(nil,nil,nil);
        }
        do{
            let backCamInput = try AVCaptureDeviceInput(device: backCam);
            let backCamPortsArray = backCamInput.ports;
            if(self.multiCapSession.canAddInput(backCamInput)){
                self.multiCapSession.addInputWithNoConnections(backCamInput);
            }else{
                print("There was a problem trying to add the back cam input to the capture session");
                return(nil,nil,nil)
            }
            for port in backCamPortsArray{
                if(port.mediaType == .video){
                    backCamVidPort = port;
                }
            }
        }catch let error{
            print("There was a problem when trying to add the input from the back cam device \(error.localizedDescription)")
            return(nil,nil,nil);
        }
        
        do{
            let micInput = try AVCaptureDeviceInput(device: mic);
            let micPortsArray = micInput.ports;
            if(self.multiCapSession.canAddInput(micInput)){
                self.multiCapSession.addInputWithNoConnections(micInput);
            }
            else{
                print("There was a problem trying to add the mic input to the capture session");
                return(nil,nil,nil);
            }
            for port in micPortsArray{
                if(port.mediaType == .audio){
                    micAudioPort = port;
                }
            }
        }catch let error{
            print("There was an error when trying to add the mic input: \(String(describing: error.localizedDescription))");
            return(nil,nil,nil);
        }
        
        //adding the ouputs to the capture session
        
        if(self.multiCapSession.canAddOutput(self.frontCamOutput)){
            self.multiCapSession.addOutputWithNoConnections(self.frontCamOutput);
        }else{
            print("The front cam output could not be added")
            return(nil,nil,nil);
        }
        
        if(self.multiCapSession.canAddOutput(self.backCamOutput)){
            self.multiCapSession.addOutputWithNoConnections(self.backCamOutput)
        }else{
            print("The back cam output could not be added");
            return(nil,nil,nil);
        }
        self.multiCapSession.commitConfiguration()
        return (frontCamVidPort, backCamVidPort, micAudioPort)
    }
    
    @IBAction func beginStream(_ sender: Any){
        if(self.screenRecorder.isRecording){
            self.screenRecorder.stopCapture { (error) in
                if(error != nil){
                    print("There was a problem when stopping the recording")
                }
            }
        }else{
            self.streamClass = Stream();
            self.streamClass.beginStream();
            self.screenRecorder.startCapture { (sampleBuffer, sampleBufferType, error) in
                if(error != nil){
                    print("There was an error gathering sample buffers from screen capture: \(String(describing: error?.localizedDescription))")
                }
                switch sampleBufferType{
                case .video:
                    print("recieved video buffers from screen capture");
                    self.streamClass.samples(sample: sampleBuffer, isvdeo: true)
                    break;
                case .audioApp:
                    print("recieved app audio buffers from screen capture");
                    self.streamClass.samples(sample: sampleBuffer, isvdeo: false)
                    break;
                case .audioMic:
                    print("Recieved mic audio buffers from screen capture");
                    break;
                default:
                    print("Reieved unknown buffer from screen capture");
                    break;
                }
            } completionHandler: { (error) in
                if(error != nil){
                    print("There was an error completing the screen capture request \(String(describing: error?.localizedDescription))");
                }
                
            }
        }
    }
    

}

