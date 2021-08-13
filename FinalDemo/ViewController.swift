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
import Photos
class ViewController: UIViewController, StreamDelegate, RPScreenRecorderDelegate {

    //MARK:variable decl
    // varables
    let rtmpConnection = RTMPConnection()
    var rtmpStream:RTMPStream!
    var streamClass:Stream!
    
    @IBOutlet weak var streamLabel: UIButton!
    
    //AV caputre variables
    var multiCapSession:AVCaptureMultiCamSession!
    var frontPreviewLayer:AVCaptureVideoPreviewLayer!
    var backPreviewLayer:AVCaptureVideoPreviewLayer!
    var frontCamOutput:AVCaptureMovieFileOutput!
    var backCamOutput:AVCaptureMovieFileOutput!
    var assetWriter:AVAssetWriter!
    var assetVideoInput:AVAssetWriterInput!
    var assetAudioOutput:AVAssetWriterInput!
    var fileManager:FileManager!
    var tempFileURL:URL!
    var assetWriterJustStartedWriting = false;
    var justStartedRecording = false;

    //location variables
    var locationManager = CLLocationManager()
    @IBOutlet weak var mapView: MKMapView!
    var globalLocationsCoordinates = [CLLocationCoordinate2D]()
    var didWorkoutStart = false;
    //health store variables
    var healthStore:HKHealthStore!
    var fistLocation:CLLocation!
    var secondLocation:CLLocation!
    var isFirstLocationInDistanceTracking = true;
    var workoutDistance = 0.0;
    
    @IBOutlet weak var distanceLabel: UILabel!
    
    //Watch Session variable decl
    var watchSession:WCSession?
    var workoutState = 0;// 0 = begin; 1 = end
    var watchSessionAvailable = true;
    
    @IBOutlet weak var LargeView: UIView!
    @IBOutlet weak var smallView: UIView!
    
    @IBOutlet weak var BPMLabel: UILabel!
    @IBOutlet weak var workoutButton: UIButton!
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
        if(!setUpWatchSession()){
            watchSessionAvailable = false
        }
        //setupHealthStore()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    func showCameras(){
        guard AVCaptureMultiCamSession.isMultiCamSupported else{
            print("Muli camera capture is not supported on this device :(");
            return;
        }
        self.multiCapSession = AVCaptureMultiCamSession()
        
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
            self.streamLabel.setTitle("Begin Stream", for: .normal)
//            let doc = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .userDomainMask, true)[0] as NSString;
//            FileManager.default.createFile(atPath: doc as String, contents: self.tempFileURL.dataRepresentation, attributes: nil)
//            var stringUrl = doc as String
//            stringUrl += "/"
//            if(FileManager.default.fileExists(atPath: <#T##String#>))
            self.justStartedRecording = false;
//           self.assetWriter.finishWriting {
//                let status = PHPhotoLibrary.authorizationStatus();
//                
//                if(status == .denied || status == .notDetermined || status == .restricted || status == .limited){
//                    PHPhotoLibrary.requestAuthorization { (auth) in
//                        if(auth == .authorized){
//                            self.saveToPhotoLibrary();
//                        }else{
//                            print("User denied access to phot library");
//                        }
//                    }
//                }else{
//                    self.saveToPhotoLibrary();
//                }
//            }
            self.screenRecorder.stopCapture { (error) in
                if(error != nil){
                    print("There was a problem when stopping the recording")
                }
            }
        }else{
            self.streamClass.beginStream();
            self.streamLabel.setTitle("End Stream", for: .normal)
           // self.setUpAssetWriter();
           
            self.screenRecorder.startCapture { (sampleBuffer, sampleBufferType, error) in
                if(error != nil){
                    print("There was an error gathering sample buffers from screen capture: \(String(describing: error?.localizedDescription))")
                }
//                if(self.justStartedRecording){
//                    self.setUpAssetWriter(sampleBuff: sampleBuffer)
//                    self.assetWriter.startSession(atSourceTime: CMTime.zero)
//                    print("Setting the source time")
//                    self.assetWriterJustStartedWriting = false;
//                    print("Entered trying to setup recording")
//                    self.justStartedRecording = false;
//                }
//                if(self.assetWriterJustStartedWriting){
//                    self.assetWriter.startSession(atSourceTime: CMTime.zero)
//                    print("Setting the source time")
//                    self.assetWriterJustStartedWriting = false;
//                }
//                guard let writer = self.assetWriter else{ return;}
//                if(writer.status == .unknown){
//                    if(CMSampleBufferDataIsReady(sampleBuffer)){
//                        if(!self.justStartedRecording){
//                            self.justStartedRecording = true;
//                            DispatchQueue.main.async {
//                                print("About to start the assetWriter")
//                                self.assetWriter.startWriting()
//                                self.assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer));
//
//                            }
//                        }
//
//                    }
//                }else if(writer.status == .writing){
//                    if(CMSampleBufferDataIsReady(sampleBuffer)){
//                        print("Ready to send sample buffers")
                        switch sampleBufferType{
                        case .video:
                            print("Sending video sample")
                            self.streamClass.samples(sample: sampleBuffer, isvdeo: true)
                           // self.assetVideoInput.append(sampleBuffer);
                            break;
                        case .audioApp:

                            break;
                        case .audioMic:
                            print("audio sample is\(sampleBuffer)")
                            self.streamClass.Channels = Int((sampleBuffer.formatDescription?.audioStreamBasicDescription!.mBitsPerChannel)!)
                            if(CMSampleBufferDataIsReady(sampleBuffer)){
                                self.streamClass.samples(sample: sampleBuffer, isvdeo: false)
                               // self.assetAudioOutput.append(sampleBuffer)
                            }
                            break;
                        default:

                            print("Reieved unknown buffer from screen capture");
                            break;
                        }
//                    }
//                }else if(writer.status == .failed){
//                    print("Not sending anything asset writer failed\n with error code \(writer.error)")
//                    print(sampleBuffer)
//                }else if(writer.status == .cancelled){
//                    print("Something cancelled the assetwriter")
//                }

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
        
        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        self.locationManager.startUpdatingLocation()
    }

    
    func setupHealthStore(){
        if(HKHealthStore.isHealthDataAvailable()){
            self.healthStore = HKHealthStore();
            let typeToShare:Set = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()];
            let typeToRead = Set([HKObjectType.quantityType(forIdentifier: .heartRate)!, HKObjectType.workoutType(), HKSeriesType.workoutRoute()]);
            self.healthStore.requestAuthorization(toShare: typeToShare, read: typeToRead) { (Success, error) in
                if(!Success){
                    print("Requesting acess was not succesfull");
                    if(error != nil){
                        print("There was an error when requesting health access \(String(describing: error))")
                    }
                }else{
                    if(error != nil){
                        print("There was an error when requesting health access \(String(describing: error))")
                    }
                }
            }
        }else{
            print("Health data is not available");
        }
    }
    
    func setUpWatchSession()->Bool{
       
        if(WCSession.isSupported()){
            self.watchSession = WCSession.default
            self.watchSession?.delegate = self;
            self.watchSession?.activate()
            print("Setting up the watch session")
            return true;
        }
        return false;
    }
    
    func saveToPhotoLibrary(){
        
        PHPhotoLibrary.shared().performChanges {
            if(FileManager.default.fileExists(atPath: self.tempFileURL.path)){
                print("File does exist before trying to save")
            }else{
                print("File does not exist")
            }
            let request = PHAssetCreationRequest.forAsset();
            request.addResource(with: .video, fileURL: self.tempFileURL, options: nil)
//            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.tempFileURL!)
        } completionHandler: { (completed, error) in
            if(completed){
                print("Completed the save to photo library");
                self.cleanFile()
            }else{
                print("File was not saved to photo library")
                print("With error \(error?.localizedDescription)")
                self.cleanFile()
            }
            
        }
    }
    
    func cleanFile(){
        if(FileManager.default.fileExists(atPath: self.tempFileURL.path)){
            do{
                try FileManager.default.removeItem(at: self.tempFileURL)
                if(!FileManager.default.fileExists(atPath: self.tempFileURL.path)){
                    print("File did exist after trying to save the video and is being removed")
                }else{
                    print("File was found but wasnt able to delete")
                }
            }catch let error{
                print("Could not remove the temp aset video file after trying to save to photolibrary");
            }
        }
    }
    
    @IBAction func startWorkout(_ sender: Any) {
        if(watchSessionAvailable){
            if(self.workoutState == 0){
                    guard let validSession = self.watchSession else{
                        print("The watch Session was not setup before attempting to access");
                        return
                    }
                    if(validSession.isReachable){
                        print("Bout to send the message to the apple watch");
                        self.workoutButton.setTitle("Stop Workout", for: .normal);
                        self.workoutState = 1;
                        self.didWorkoutStart = true;
                        let workoutMSG = ["Workout":"Start"]
                        validSession.sendMessage(workoutMSG, replyHandler: nil) { (error) in
                            if(error != nil){
                                print("Ther was a prblem trying to send the workout message to the watch");
                            }
                        }
                        
                    }else{
                        let alertController = UIAlertController(title: "Watch app not found", message: "Would you like to start the workout without the watch app?", preferredStyle: .alert)
                        let yesAction = UIAlertAction(title: "Yes", style: .default) { (action) in
                            self.didWorkoutStart = true;
                            self.workoutButton.setTitle("Stop Workout", for: .normal)
                            self.workoutState = 1;
                        }
                        let noAction = UIAlertAction(title: "No", style: .default) { (action) in
                            self.didWorkoutStart = false;
                            self.workoutState = 0;
                        }
                        alertController.addAction(yesAction);
                        alertController.addAction(noAction);
                        self.present(alertController, animated: true, completion: nil)
                    }
            }else{
                self.workoutState = 0;
                self.didWorkoutStart = false;
                guard let validSession = self.watchSession else {
                    print("The watch Session is nil when trying to stop the workout");
                    return;
                }
                for overlay in self.mapView.overlays{
                    self.mapView.removeOverlay(overlay)
                }
                self.globalLocationsCoordinates = [CLLocationCoordinate2D]()
                self.workoutButton.setTitle("Start workout", for: .normal)
                let workoutMSG = ["Workout1":"Stop"]
                validSession.sendMessage(workoutMSG, replyHandler: nil) { (erro) in
                    print("There was an error when trying to stop the workout witht the session message");
                }
            }
        }else{
            print("Watch Session is not availble on this device");
        }
    }
    
    func setUpAssetWriter(){
        self.assetWriterJustStartedWriting = true;
//        self.tempFileURL = self.videoLocation();
        let outputFileName = NSUUID().uuidString
        let outPutFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mp4")!)
        let currentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let out = currentDir.appendingPathComponent("videoFile.mov")
        print("THIS IS CURRENTDIR \(currentDir)")
        let output = currentDir.appendingPathComponent("videoFile").appendingPathExtension("mov");
//        self.tempFileURL = URL(fileURLWithPath: outPutFilePath)
        self.tempFileURL = out
        print("THIS IS THE TEMP FILE \(self.tempFileURL)")
        print("THIS IS TEMPFILE \(self.tempFileURL)")
        let appURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        print("THIS IS THE APPURL\(appURL)")
        print("THIS IS THE CURRENT DIRECTORY\(FileManager.default.currentDirectoryPath)")
        print(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask))
        if(FileManager.default.fileExists(atPath: self.tempFileURL.path)){
            print("trying to delete the file before starting the session")
            do{
                try FileManager.default.removeItem(at: self.tempFileURL!)
            }catch{
                print("was not able to delete file when trying to start the assetWriter");
            }
            if(FileManager.default.fileExists(atPath: self.tempFileURL.path)){
                print("File still exist after trying to delete")
            }
        }
        do{
            self.assetWriter = try AVAssetWriter(outputURL: self.tempFileURL!, fileType: .mov)
        }catch let error{
            print("There was an error setting up the assetWriter \(error.localizedDescription)")
        }
//            let description = CMSampleBufferGetFormatDescription(sampleBuff)
//            let dimension = CMVideoFormatDescriptionGetDimensions(description!)
            self.assetVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
//                                                      outputSettings: [
//                AVVideoCodecKey: AVVideoCodecType.h264,
//                AVVideoWidthKey: self.view.bounds.width,
//                AVVideoHeightKey: self.view.bounds.height,
//            ])
            self.assetVideoInput.expectsMediaDataInRealTime = true;
            if(self.assetWriter.canAdd(self.assetVideoInput)){
                self.assetWriter.add(self.assetVideoInput);
                print("Asset Writer input added");
            }else{
                print("Could not add the asset writer input");
            }
            
        self.assetAudioOutput = AVAssetWriterInput(mediaType: .audio, outputSettings:nil)
        
            if(self.assetWriter.canAdd(self.assetAudioOutput)){
                self.assetWriter.add(self.assetAudioOutput);
                print("Asset writer was able to add the adio output");
            }else{
                print("Asset Writert was not able to add the audio output");
            }
            
//            if(self.assetWriter.startWriting()){
//                print("succesfull start writing on av asset writer");
//            }else{
//                print("Unable to start writing")
//            }
            if(assetWriter.status == .unknown){
                print("Asset writer status unknown");
            }else if(self.assetWriter.status == .cancelled){
                print("Asset writer status cancelled");
            }else if(self.assetWriter.status == .failed){
                print("Asset writert status failed");
                print(self.assetWriter.error);
            }else if(self.assetWriter.status == .writing){
                print("Asset writer status writing");
            }else if(self.assetWriter.status == .completed){
                print("AssetWriter status completed");
            }
    }
    
    func videoLocation()->URL{
//        let doc = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .userDomainMask, true)[0] as NSString;
//        if(FileManager.default.fileExists(atPath: "\(doc)/videoFile.mov")){
//            print("There is a file there")
//        }
//        let urlString = "\(doc)/videoFile.mp4"
//        if(FileManager.default.fileExists(atPath: urlString)){
//
//        }else{
//            FileManager.default.createFile(atPath: urlString, contents: nil, attributes: [FileAttributeKey.])
//        }
//        let videoURL = URL(fileURLWithPath: doc.appendingPathComponent("Library/Caches/VideoFile.mp4"));
        let outputFileName = NSUUID().uuidString
        let outPutFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
        let appURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        print("THIS IS THE APPURL\(appURL)")
//        var videoURLString:String!
//        do{
//            try videoURLString = String(contentsOf: videoURL)
//        }catch let error{
//            print("There was an error converting vdieo url to string")
//        }
//        do{
//            try FileManager.default.createDirectory(atPath: videoURLString, withIntermediateDirectories: true, attributes: nil)
//        }catch let error{
//         print("There was an error creating file dir")
//        }
        
       
//        do{
//            if(FileManager.default.fileExists(atPath: videoURL.path)){
//                try FileManager.default.removeItem(at: videoURL);
//            }
//            print("deleted old file")
//        }catch let error{
//            print(error);
//        }
        let returned = URL(string: outPutFilePath)
        return returned!;
    }

}

//MARK: Location Delegates
extension ViewController:CLLocationManagerDelegate{
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        if(self.didWorkoutStart){
            self.globalLocationsCoordinates.append(location.coordinate)
            let polyline = MKPolyline(coordinates: self.globalLocationsCoordinates, count: self.globalLocationsCoordinates.count
            )
            self.mapView.addOverlay(polyline)
            if(self.isFirstLocationInDistanceTracking){
                self.fistLocation = CLLocation(latitude: (location.coordinate.latitude), longitude: location.coordinate.longitude);
                self.workoutDistance = 0;
                print("Woekout distance \(workoutDistance)")
                self.isFirstLocationInDistanceTracking = false;
                DispatchQueue.main.async {
                    self.distanceLabel.text = "\(self.workoutDistance)"
                }
                
            }else{
                self.secondLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude);
                self.workoutDistance += secondLocation.distance(from: self.fistLocation);
                self.fistLocation = secondLocation;
                
                DispatchQueue.main.async {
                    self.distanceLabel.text = "\(self.workoutDistance)"
                }
                
            }
        }else{
            self.isFirstLocationInDistanceTracking = true;
            self.workoutDistance = 0.0;
            DispatchQueue.main.async {
                self.distanceLabel.text = "\(self.workoutDistance)"
            }
        }
        
        // initialize the mapView
        let coordSpan = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        let coordRegion = MKCoordinateRegion(center: location.coordinate, span: coordSpan)
        self.mapView.setRegion(coordRegion, animated: true)
        if(!self.didWorkoutStart){
            let coordinatePin = MKPointAnnotation()
            coordinatePin.coordinate = location.coordinate;
            //coordinatePin.title = location.description;
            self.mapView.addAnnotation(coordinatePin)
        }else{
            for annot in self.mapView.annotations{
                self.mapView.removeAnnotation(annot)
            }
        }
        
    }
    
}
//MARK: Watch Session Delegates
extension ViewController:WCSessionDelegate{
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession was succesfully activated activation state: \(activationState)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        //Do something because the apple watch is trying to communicate
        print("Just recieved message from the apple watch");
        if let realMessage = message["BPM"] as? Double{
            print("Message is from BPM")
            DispatchQueue.main.async {
                self.BPMLabel.text = "\(realMessage)"
            }
        }
    }
}

//MARK: Map Overlay Delegate
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
