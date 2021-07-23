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
import CoreMedia
import WatchConnectivity
import MapKit
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
    
    //location variables
    var locationManager = CLLocationManager()
    @IBOutlet weak var mapView: MKMapView!
    var globalLocationsCoordinates = [CLLocationCoordinate2D]()
    
    @IBOutlet weak var LargeView: UIView!
    @IBOutlet weak var smallView: UIView!
    
    //screen recording variables
    var screenRecorder:RPScreenRecorder!
    
    //location variables
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.streamClass = Stream();
        self.screenRecorder = RPScreenRecorder.shared();
        self.screenRecorder.isMicrophoneEnabled = true;
        showCameras();
        setupLocationManager();
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print(".\n.\n.\n.\n.\n.\n.\n.\n.\n memory error .\n.\n.\n.\n.\n.\n")
    }
    func showCameras(){
        guard AVCaptureMultiCamSession.isMultiCamSupported else{
            print("Muli camera capture is not supported on this device :(");
            return;
        }
        self.multiCapSession = AVCaptureMultiCamSession()
        let avAudioSession = AVAudioSession()
      //  print("This is the available modes \(avAudioSession.availableModes)\n This is the available catagories \(avAudioSession.availableCategories)\n This is the avaialable inputs \(avAudioSession.availableInputs)")
        let frontCam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front);
        let backCam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back);
        let mic = AVCaptureDevice.default(for: .audio)
    
       // self.streamClass.attachAudio(device: mic!)
        let (frontCamPort, backCamPort, micPort) = self.camSessionInputsAndOutputs(frontCam: frontCam!, backCam: backCam!, mic: mic!);
        
        self.backPreviewLayer = AVCaptureVideoPreviewLayer()
        self.backPreviewLayer.setSessionWithNoConnection(self.multiCapSession);
        self.backPreviewLayer.connection?.videoOrientation = .portrait;
        self.backPreviewLayer.videoGravity = .resizeAspectFill;
//       self.backPreviewLayer.frame = self.smallView.frame;
        
        self.frontPreviewLayer = AVCaptureVideoPreviewLayer();
        self.frontPreviewLayer.setSessionWithNoConnection(self.multiCapSession);
        self.frontPreviewLayer.connection?.videoOrientation = .portrait;
        self.frontPreviewLayer.videoGravity = .resizeAspectFill;
//       self.frontPreviewLayer.frame = self.LargeView.frame;
        
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
        
        self.view.sendSubviewToBack(LargeView);
       
        
        DispatchQueue.main.async {
            self.multiCapSession.startRunning();
            self.frontPreviewLayer.frame = self.smallView.bounds;
            self.backPreviewLayer.frame = self.LargeView.bounds;
        }
    }
    
    func setUpCaptureSessionConnections(frontCamPort:AVCaptureInput.Port, backCamPort:AVCaptureInput.Port, micPort:AVCaptureInput.Port)->Bool{
        print("this is the mics port format description \(micPort)")
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
            self.streamClass.beginStream();
            
            self.screenRecorder.startCapture { (sampleBuffer, sampleBufferType, error) in
                if(error != nil){
                    print("There was an error gathering sample buffers from screen capture: \(String(describing: error?.localizedDescription))")
                }
                switch sampleBufferType{
                case .video:
                   // print("recieved video buffers from screen capture");
                    self.streamClass.samples(sample: sampleBuffer, isvdeo: true)
                    break;
                case .audioApp:
                    print("recieved app audio buffers from screen capture");
                    
                  // self.streamClass.samples(sample: sampleBuffer, isvdeo: false)
                    break;
                case .audioMic:
                   print("Recieved mic audio buffers from screen capture");
//                    print(" this is the format description \(sampleBuffer.formatDescription)")
                    print(" this is the format description \(sampleBuffer)")
                    print(" this is the samples \(sampleBuffer.numSamples)")
                    self.streamClass.Channels = Int((sampleBuffer.formatDescription?.audioStreamBasicDescription!.mBitsPerChannel)!)
                    if(CMSampleBufferDataIsReady(sampleBuffer)){
                   self.streamClass.samples(sample: sampleBuffer, isvdeo: false)
                    }
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
    
    func setupLocationManager(){//starts tracking the location services
        self.locationManager.delegate = self;
        self.mapView.delegate = self;
        self.locationManager.requestAlwaysAuthorization()
        switch locationManager.authorizationStatus{
        case .denied:
            print("ViewController: [310] The use denied the use of location services for the app or they are disabled globally in Settings");
            let alertController = UIAlertController.init(title: "Location services", message: "Please allow the app to use location services in order to get location tracking availble for stream", preferredStyle: .alert)
            let alertActionOk = UIAlertAction.init(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(alertActionOk);
            self.present(alertController, animated: true, completion: nil)
            break;
        case.restricted:
            print("ViewController: [310] The app is not authorized to use location services");
            break;
        case .authorizedAlways:
            print("ViewController: [322] The user authorized the app o use location services");
            break
        case .authorizedWhenInUse:
            print("ViewController: [325] the user authorized the app to start location services while it is in use");
            break;
        case .notDetermined:
            print("ViewController: [328] User has not determined whether the app can use location services");
            print("ViewController: [310] The use denied the use of location services for the app or they are disabled globally in Settings");
            let alertController = UIAlertController.init(title: "Location services", message: "Please allow the app to use location services in order to get location tracking availble for stream", preferredStyle: .alert)
            let alertActionOk = UIAlertAction.init(title: "OK", style: .default) { (action) in
                
            }
            alertController.addAction(alertActionOk);
            self.present(alertController, animated: true, completion: nil)
            break;
        default:
            break;
        }
        
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
        self.locationManager.startUpdatingLocation()
    }

    
}

//MARK: Location Delegates
extension ViewController:CLLocationManagerDelegate{
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        self.globalLocationsCoordinates.append(location.coordinate)
        let polyline = MKPolyline(coordinates: self.globalLocationsCoordinates, count: self.globalLocationsCoordinates.count
        )
        self.mapView.addOverlay(polyline)
        
        // initialize the mapView
        let coordSpan = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        let coordRegion = MKCoordinateRegion(center: location.coordinate, span: coordSpan)
        self.mapView.setRegion(coordRegion, animated: true)
        
        let coordinatePin = MKPointAnnotation()
        coordinatePin.coordinate = location.coordinate;
        //coordinatePin.title = location.description;
        self.mapView.addAnnotation(coordinatePin)
        
    }
    
}
//MARK: Watch Session Delegates
extension ViewController:WCSessionDelegate{
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
}

extension ViewController:MKMapViewDelegate{
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        //rendering method
        if(overlay is MKPolyline){
            let renderer = MKPolylineRenderer(overlay: overlay);
            renderer.strokeColor = .red;
            renderer.lineWidth = 3;
            return renderer;
        }
        
        return MKOverlayRenderer()
    }
}



