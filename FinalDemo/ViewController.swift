//
//  ViewController.swift
//  FinalDemo
//  This View controller class will handle th preview of the front and back camera, handle responses from the user in terms of starting the stream/ starting a workout and updates the screen accordingly
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
    // varables from the Haiskinkit SDK
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
        // create a stream calls to set up the stream
        self.streamClass = Stream();
        self.screenRecorder = RPScreenRecorder.shared();
        self.screenRecorder.isMicrophoneEnabled = true;// enables the usagge of micriphone
        showCameras();// will setup the viewfinder of the camera
        setupLocationManager();// setuo for location services
        if(!setUpWatchSession()){
            watchSessionAvailable = false// gloabal variable to know if there is a compatible apple watch
        }
        //setupHealthStore()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    func showCameras(){
        guard AVCaptureMultiCamSession.isMultiCamSupported else{// checks to see if the users iphone does not support multi camera usage
            print("Muli camera capture is not supported on this device :(");
            return;
        }
        self.multiCapSession = AVCaptureMultiCamSession()//creates an instance of a AVMultiCamSession
        
      //  print("This is the available modes \(avAudioSession.availableModes)\n This is the available catagories \(avAudioSession.availableCategories)\n This is the avaialable inputs \(avAudioSession.availableInputs)")
        let frontCam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front);// creates a reference to the front camera of the iphone using AVCaputureDevice
        let backCam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back);// creates a reference to the back camera of the iphone using AVCaptureDevice
        let mic = AVCaptureDevice.default(for: .audio)// creates a reference to the microphone using the AVCaptureDevice
    
       // self.streamClass.attachAudio(device: mic!)
        let (frontCamPort, backCamPort, micPort) = self.camSessionInputsAndOutputs(frontCam: frontCam!, backCam: backCam!, mic: mic!);// calls the function that will setup the input and output ports and returns the video/audio ports
        
        self.backPreviewLayer = AVCaptureVideoPreviewLayer()// preview layer for displaying the back camera video
        self.backPreviewLayer.setSessionWithNoConnection(self.multiCapSession);// REALLY import to have no connections between anything that will be giving/getting data from the multicam capture
        self.backPreviewLayer.connection?.videoOrientation = .portrait;// portrait mode
        self.backPreviewLayer.videoGravity = .resizeAspectFill;// fills area witht the preview layer
//       self.backPreviewLayer.frame = self.smallView.frame;
        
        self.frontPreviewLayer = AVCaptureVideoPreviewLayer();// preview layer for displaying the front camer video
        self.frontPreviewLayer.setSessionWithNoConnection(self.multiCapSession);/// REALLY import to have no connections between anything that will be giving/getting data from the multicam capture
        self.frontPreviewLayer.connection?.videoOrientation = .portrait;// protait mode for the preview layer
        self.frontPreviewLayer.videoGravity = .resizeAspectFill;// files the space of the preview layer
//       self.frontPreviewLayer.frame = self.LargeView.frame;
        
        //setting up the connections
        guard let frontCameraPort = frontCamPort else{// checks to see if there was an error when setting up the inuts and outputs
            print("FrontCamPort does not have a value");
            return
        }
        
        guard let backCameraPort = backCamPort else{// checks to see if there was an error when setting up the inuts and outputs
            print("BackCamPort does not have a value");
            return;
        }
        guard let micInputPort = micPort else{// checks to see if there was an error when setting up the inuts and outputs
            print("micPort does not have a value")
            return
        }
        
        //will setup the connections between the inputs ports/outputs(recording) and the input ports/previewlayer(camera viewfinder)
        guard setUpCaptureSessionConnections(frontCamPort: frontCameraPort, backCamPort: backCameraPort, micPort: micInputPort) else{
            print("The capture session Connections were not set up correctly");
            return;
        }
        
        self.LargeView.layer.addSublayer(self.backPreviewLayer);// adds the back camera preview layer to the larger view
        self.smallView.layer.addSublayer(self.frontPreviewLayer);// adds the front camera preview layer to the smaller view
        
        self.view.sendSubviewToBack(LargeView);// sends the larger view to the back to the smaller one will pop in front of it(PIP- Picture in picture)
       
        
        DispatchQueue.main.async {// dispatcht eh process to the main thread, allows for faster loading
            self.multiCapSession.startRunning();// starts the multi cam caputure session
            self.frontPreviewLayer.frame = self.smallView.bounds;// sets the preview layer frame to the small view bounds
            self.backPreviewLayer.frame = self.LargeView.bounds;// sets the preview layer frame to the boudns of the larger view
        }
    }
    
    func setUpCaptureSessionConnections(frontCamPort:AVCaptureInput.Port, backCamPort:AVCaptureInput.Port, micPort:AVCaptureInput.Port)->Bool{
        print("this is the mics port format description \(micPort)")
        self.multiCapSession.beginConfiguration()// tells the multicam capture session changes are being made
        let frontVidPreviewLayerConnection = AVCaptureConnection(inputPort:frontCamPort, videoPreviewLayer: self.frontPreviewLayer);// creates an connection instance with the preview layer and the front camera port and the previw layer
        if(self.multiCapSession.canAddConnection(frontVidPreviewLayerConnection)){// adds the front preview layer/ front cam port connection to the multicam caputre if possible
            self.multiCapSession.addConnection(frontVidPreviewLayerConnection);
        }else{
            print("Could not add the frontPreviewLayer connection");
            return false;
        }
        self.multiCapSession.commitConfiguration();// commites changes to the multicam capture
        self.multiCapSession.beginConfiguration();// tells the multicam cap that changes are bing made
        let frontVideOuputConnection = AVCaptureConnection(inputPorts: [frontCamPort], output: self.frontCamOutput);// creates connection between the input port and the front cam output, mainly for recording
        if(self.multiCapSession.canAddConnection(frontVideOuputConnection)){// checks to see if we can add the connection to the mutlicam capture session instance
            self.multiCapSession.addConnection(frontVideOuputConnection);
        }
        else{// if the connection was not able to be made
            print("Could not add the frontVidOutputConnection");
            return false;
        }
        self.multiCapSession.commitConfiguration();// commites the changes made to the mutlicam capture session
        
        let backVideoPreviewLayerConnection = AVCaptureConnection(inputPort: backCamPort, videoPreviewLayer: self.backPreviewLayer);// creates a connection instance with the back camera port and the preview layer
        if(self.multiCapSession.canAddConnection(backVideoPreviewLayerConnection)){// checks to see if we can add the connecion to the multicap seession(Global)
            self.multiCapSession.addConnection(backVideoPreviewLayerConnection);
        }
        else{// could not be added to the multu cap session(Global)
            print("Could not add the backVideoOutputConnection");
            return false;
        }
        let backVidOuputConnection = AVCaptureConnection(inputPorts: [backCamPort], output: self.backCamOutput);// creates a connection instance between the back cam port(local) and the ouptut(global) mainly for recording
        if(self.multiCapSession.canAddConnection(backVidOuputConnection)){// checks to see if we can add the connection to the multic cap sesion(global) and then we add it
            self.multiCapSession.addConnection(backVidOuputConnection);
        }
        else{
            print("Could not add the backOutput Connection");
            return false;
        }
        
        let frontCamAudioConnection = AVCaptureConnection(inputPorts: [micPort], output: self.frontCamOutput);// creates a connectin isntance with the mic port and the front cam output port for recording
        if(self.multiCapSession.canAddConnection(frontCamAudioConnection)){// checks to see if we can add the connection
            self.multiCapSession.addConnection(frontCamAudioConnection);
        }else{
            print("Coult not add audio connection to the front cam");
            return false;
        }
        let backCamAudioConnection = AVCaptureConnection(inputPorts: [micPort], output: self.backCamOutput);// creates a connection instance with the mic port and the back cam port, mainly for recording
        if(self.multiCapSession.canAddConnection(backCamAudioConnection)){
            self.multiCapSession.addConnection(backCamAudioConnection);
        }else{
            print("Could not add the audio connection to the back cam");
            return false;
        }
        self.multiCapSession.commitConfiguration()
        return true;// succesfully able to add the connections
    }
    
    func camSessionInputsAndOutputs(frontCam:AVCaptureDevice!, backCam:AVCaptureDevice!, mic:AVCaptureDevice!)-> (AVCaptureInput.Port?,AVCaptureInput.Port?, AVCaptureInput.Port?){// returns the input ports
        var frontCamVidPort:AVCaptureInput.Port!;
        var backCamVidPort:AVCaptureInput.Port!;
        var micAudioPort:AVCaptureInput.Port!
        self.frontCamOutput = AVCaptureMovieFileOutput()//will be the for the front cam input port
        self.backCamOutput = AVCaptureMovieFileOutput()// will be the outputut for the back cam port
        
        self.multiCapSession.beginConfiguration()// tells the multicamCaputre that changes are being made
        
        //adding the inputs to the capture seesion and finding the ports
        do{
            let frontCamInput = try AVCaptureDeviceInput(device: frontCam)// checks whether there is an object inside the passed variable of frontcam
            let frontCamInputPortsArray = frontCamInput.ports;// creates an array of all port instanced on the front camera
            if(self.multiCapSession.canAddInput(frontCamInput)){// checks whether the input could be added to the multicamcap session
                self.multiCapSession.addInputWithNoConnections(frontCamInput);
            }
            else{
                print("There was a problem trying to add the front cam input to the capture session");
                return(nil,nil,nil)//
            }
            for port in frontCamInputPortsArray{// linearly iterates through the input port array
                if(port.mediaType == .video){
                    frontCamVidPort = port;// finds the video port and stores it
                }
            }
        }catch let error{// error case for when the object passes is not set up correctly
            print("There was an error when trying to get the front camera devices input: \(String(describing: error.localizedDescription))")
            return(nil,nil,nil);
        }
        do{// checks whethere there is an object in the passed variable of backCamInput
            let backCamInput = try AVCaptureDeviceInput(device: backCam);// grabs the input into a different variable
            let backCamPortsArray = backCamInput.ports;// creates an array of the backCaminput array
            if(self.multiCapSession.canAddInput(backCamInput)){// checks whether the input can be added to the multiCamSession
                self.multiCapSession.addInputWithNoConnections(backCamInput);// adds the input to the multiCamSession
            }else{
                print("There was a problem trying to add the back cam input to the capture session");
                return(nil,nil,nil)
            }
            for port in backCamPortsArray{//linearly iterates through the ports array
                if(port.mediaType == .video){// if the port is video we store it
                    backCamVidPort = port;
                }
            }
        }catch let error{// error case for when the object passes is not set up correctly
            print("There was a problem when trying to add the input from the back cam device \(error.localizedDescription)")
            return(nil,nil,nil);
        }
        
        do{
            let micInput = try AVCaptureDeviceInput(device: mic);// checks to see if the mic device wa setup correctly
            let micPortsArray = micInput.ports;// creats an array of all the ports inside the mic input
            if(self.multiCapSession.canAddInput(micInput)){// checks to see if we can add the mic input to the multicamSession
                self.multiCapSession.addInputWithNoConnections(micInput);
            }
            else{
                print("There was a problem trying to add the mic input to the capture session");
                return(nil,nil,nil);
            }
            for port in micPortsArray{//linearly iterates through the mic ports to find the audio
                if(port.mediaType == .audio){
                    micAudioPort = port;// saves the audio port
                }
            }
        }catch let error{//error case for when the mic object passes is not set up correctly
            print("There was an error when trying to add the mic input: \(String(describing: error.localizedDescription))");
            return(nil,nil,nil);
        }
        
        //adding the ouputs to the capture session
        
        if(self.multiCapSession.canAddOutput(self.frontCamOutput)){// adds the front cam output to the multicam session
            self.multiCapSession.addOutputWithNoConnections(self.frontCamOutput);
        }else{
            print("The front cam output could not be added")
            return(nil,nil,nil);
        }
        
        if(self.multiCapSession.canAddOutput(self.backCamOutput)){// adds the back cam output to the multicam
            self.multiCapSession.addOutputWithNoConnections(self.backCamOutput)
        }else{
            print("The back cam output could not be added");
            return(nil,nil,nil);
        }
        self.multiCapSession.commitConfiguration()//saves all the chagnes made to the multicamSession
        return (frontCamVidPort, backCamVidPort, micAudioPort)// return all the ports found on the audio and video
    }
    
    @IBAction func beginStream(_ sender: Any){// method used to start a "Screcapture" that will send the audio/video buffers to the streaming class
        
        if(self.screenRecorder.isRecording){// checks to see if it is already recording
            self.streamLabel.setTitle("Begin Stream", for: .normal)//changes the button to show the user that the stream has ended
//            let doc = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .userDomainMask, true)[0] as NSString;
//            FileManager.default.createFile(atPath: doc as String, contents: self.tempFileURL.dataRepresentation, attributes: nil)
//            var stringUrl = doc as String
//            stringUrl += "/"
//            if(FileManager.default.fileExists(atPath: <#T##String#>))
            self.justStartedRecording = false;// Global variable to keep in track of the streaming state
//           self.assetWriter.finishWriting {
//                let status = PHPhotoLibrary.authorizationStatus();
//                
//                if(status == .denied || status == .notDetermined || status == .restricted || status == .limited){
//                    PHPhotoLibrary.requestAuthorization { (auth) ind
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
            self.screenRecorder.stopCapture { (error) in// stops grabbing video/audio buffers
                if(error != nil){
                    print("There was a problem when stopping the recording")
                }
            }
        }else{
            self.streamClass.beginStream();// calls the stream class beginStream method to properly setup the the stream
            self.streamLabel.setTitle("End Stream", for: .normal)// updates the user to show that the stream has started
           // self.setUpAssetWriter();
           
            self.screenRecorder.startCapture { (sampleBuffer, sampleBufferType, error) in// starts grabbing the video/audio buffers
                if(error != nil){// checks to see if there was a problem when trying to start capturing
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
                        switch sampleBufferType{// checks to see what buffers we got in return
                        case .video:
                            print("Sending video sample")
                            self.streamClass.samples(sample: sampleBuffer, isvdeo: true)// if we got video buffers it will pass it along to the stream class
                           // self.assetVideoInput.append(sampleBuffer);
                            break;
                        case .audioApp:

                            break;
                        case .audioMic:
                            print("audio sample is\(sampleBuffer)")
                            self.streamClass.Channels = Int((sampleBuffer.formatDescription?.audioStreamBasicDescription!.mBitsPerChannel)!)
                            if(CMSampleBufferDataIsReady(sampleBuffer)){// makes sure the buffer is ready to be sent
                                self.streamClass.samples(sample: sampleBuffer, isvdeo: false)// sends the audio buffer to the stream class
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

            } completionHandler: { (error) in// if there was an error trying to start the capture
                if(error != nil){
                    print("There was an error completing the screen capture request \(String(describing: error?.localizedDescription))");
                }
                
            }
        }
    }
    
    func setupLocationManager(){//starts tracking the location services
        self.locationManager.delegate = self;// lets it know to call location delegate methods
        self.mapView.delegate = self;// lets it know to call mapView delegate methods
        self.locationManager.requestAlwaysAuthorization()// asks to be constantly trakcing the users location
        
        
        switch locationManager.authorizationStatus{// checks the tracking status
        case .denied:// if user denied we will show a message asking the user to allow
            print("The use denied the use of location services for the app or they are disabled globally in Settings");
            let alertController = UIAlertController.init(title: "Location services", message: "Please allow the app to use location services in order to get location tracking availble for stream", preferredStyle: .alert)// alert to ask the user to allow the use of location
            let alertActionOk = UIAlertAction.init(title: "OK", style: .default) { (action) in
                // button to exit the alert
            }
            alertController.addAction(alertActionOk);
            self.present(alertController, animated: true, completion: nil)// presents the alert
            break;
        case.restricted://
            print(" The app is not authorized to use location services");
            break;
        case .authorizedAlways:
            print("ViewController: [322] The user authorized the app o use location services");
            break
        case .authorizedWhenInUse:
            print("ViewController: [325] the user authorized the app to start location services while it is in use");
            break;
        case .notDetermined:// neither accepted or denied location access to the app
            print(" User has not determined whether the app can use location services");
            print("The use denied the use of location services for the app or they are disabled globally in Settings");
            let alertController = UIAlertController.init(title: "Location services", message: "Please allow the app to use location services in order to get location tracking availble for stream", preferredStyle: .alert)// alert to ask the user to enable location
            let alertActionOk = UIAlertAction.init(title: "OK", style: .default) { (action) in
                // button to exit alert
            }
            alertController.addAction(alertActionOk);// attaches the button to the alert
            self.present(alertController, animated: true, completion: nil)// presents the alert
            break;
        default:
            break;
        }
        
        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters// sets the accuracy of the location services
        self.locationManager.startUpdatingLocation()// begins grabbing the users location
    }

    
    func setupHealthStore(){// sets the health store to be able to grab user telemetrics(heart rate)
        if(HKHealthStore.isHealthDataAvailable()){// checks to see if the users iphone is available to grab health data
            self.healthStore = HKHealthStore();// initializes the health store object
            let typeToShare:Set = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()];// the data we are asking to be able to share
            let typeToRead = Set([HKObjectType.quantityType(forIdentifier: .heartRate)!, HKObjectType.workoutType(), HKSeriesType.workoutRoute()]);// the data we are asking to be able to see
            self.healthStore.requestAuthorization(toShare: typeToShare, read: typeToRead) { (Success, error) in// asks the user if we can have access to the health data
                if(!Success){// if wer are not granted access
                    print("Requesting acess was not succesfull");
                    if(error != nil){// checks to see if it was because an error
                        print("There was an error when requesting health access \(String(describing: error))")
                    }
                }else{// success but need to chek for error
                    if(error != nil){
                        print("There was an error when requesting health access \(String(describing: error))")
                    }
                }
            }
        }else{// otherwise health data is not availbale on device
            print("Health data is not available");
        }
    }
    
    func setUpWatchSession()->Bool{// will setup the watch session return if available
       
        if(WCSession.isSupported()){// checks to see if watch sesion are supported
            self.watchSession = WCSession.default// default watch sesion
            self.watchSession?.delegate = self;// tell watch sesion to be calling the delegate methods
            self.watchSession?.activate()// begins the watch sesion
            print("Setting up the watch session")
            return true;// return true if was able to be setup
        }
        return false;// will only return false if not supported
    }
    
    func saveToPhotoLibrary(){// can be used to save the videos of the stream, not supported currently
        
        PHPhotoLibrary.shared().performChanges {// tells the photolibrary that we will make some changes
            if(FileManager.default.fileExists(atPath: self.tempFileURL.path)){// checks to see if the file exist on the app directory
                print("File does exist before trying to save")
            }else{
                print("File does not exist")
            }
            let request = PHAssetCreationRequest.forAsset();// request to photo library to make some chagnes
            request.addResource(with: .video, fileURL: self.tempFileURL, options: nil)// adds the video/audio file to the chagnes
//            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.tempFileURL!)
        } completionHandler: { (completed, error) in// will be called once attempted to save the video/audio
            if(completed){// if was able to save the video/audio
                print("Completed the save to photo library");
                self.cleanFile()// fucntion to call to delete the file off the app directory
            }else{// the vdieo/audio file was not able to be saved to users photolibrary
                print("File was not saved to photo library")
                print("With error \(error?.localizedDescription)")
                self.cleanFile()//function to delete the file of the app directory
            }
            
        }
    }
    
    func cleanFile(){// deletes the file off the app directory
        if(FileManager.default.fileExists(atPath: self.tempFileURL.path)){// checks to see if the global file exitst
            do{
                try FileManager.default.removeItem(at: self.tempFileURL)// removes the file
                if(!FileManager.default.fileExists(atPath: self.tempFileURL.path)){// checks to see if the file was deleted
                    print("File did exist after trying to save the video and is being removed")
                }else{
                    print("File was found but wasnt able to delete")
                }
            }catch let error{
                print("Could not remove the temp aset video file after trying to save to photolibrary");
            }
        }
    }
    
    @IBAction func startWorkout(_ sender: Any) {// function to be called when the user has requested to begin the workout
        if(watchSessionAvailable){// if the watch sessoin was able to be set up
            if(self.workoutState == 0){// 0 = no workout in progress
                    guard let validSession = self.watchSession else{// checks to see if the watch sesion was setup correctly
                        print("The watch Session was not setup before attempting to access");
                        return
                    }
                    if(validSession.isReachable){// if apple watch is in reach of the iphone
                        print("Bout to send the message to the apple watch");
                        self.workoutButton.setTitle("Stop Workout", for: .normal);// updates the user to show the workout has started
                        self.workoutState = 1;// 1 = workout in progress
                        self.didWorkoutStart = true;// variable to to alos keep track of the workout state, use this
                        let workoutMSG = ["Workout":"Start"]// the message that will be sent to the apple watch
                        validSession.sendMessage(workoutMSG, replyHandler: nil) { (error) in// sends the message to the apple watch
                            if(error != nil){
                                print("Ther was a prblem trying to send the workout message to the watch");
                            }
                        }
                        
                    }else{// if the apple watch was not in reach
                        let alertController = UIAlertController(title: "Watch app not found", message: "Would you like to start the workout without the watch app?", preferredStyle: .alert)// alert to notify the user the apple watch is not in reach
                        let yesAction = UIAlertAction(title: "Yes", style: .default) { (action) in
                            // action to allow the user to begin the workout without the iphone, no data is being gathered
                            self.didWorkoutStart = true;// keps track of the workout state
                            self.workoutButton.setTitle("Stop Workout", for: .normal)/// notifies the user the workout has started
                            self.workoutState = 1;// chagnes the workout state to workoout in progress
                        }
                        let noAction = UIAlertAction(title: "No", style: .default) { (action) in
                            // does not start a workout
                            self.didWorkoutStart = false;
                            self.workoutState = 0;
                        }
                        alertController.addAction(yesAction);
                        alertController.addAction(noAction);
                        self.present(alertController, animated: true, completion: nil)// presents the alert that no apple watch in reach
                    }
            }else{// ends the workout
                self.workoutState = 0;// changes state to no workout in progress
                self.didWorkoutStart = false;// chagnes state to no workout in progress
                guard let validSession = self.watchSession else {// checks to see if apple watch session is valid
                    print("The watch Session is nil when trying to stop the workout");
                    return;
                }
                for overlay in self.mapView.overlays{//removes the overlays from the mapview
                    self.mapView.removeOverlay(overlay)
                }
                self.globalLocationsCoordinates = [CLLocationCoordinate2D]()// resets the locations array to empty
                self.workoutButton.setTitle("Start workout", for: .normal)// notifies the user that the workout has ended
                let workoutMSG = ["Workout1":"Stop"]// message to apple watch to end the workout
                validSession.sendMessage(workoutMSG, replyHandler: nil) { (erro) in// sends the mesage to the apple watch
                    print("There was an error when trying to stop the workout witht the session message");
                }
            }
        }else{
            print("Watch Session is not availble on this device");
        }
    }
    
    func setUpAssetWriter(){// used to be able to write the data to a file that will be used to save the video and audio- NOT CURRENTLY USED
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
extension ViewController:CLLocationManagerDelegate{// extenstion of the viewController class with the location delegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {// Got a new location update
        let location = locations[0]// grabs the first instance in the new location update
        if(self.didWorkoutStart){// checks to see the workout state to begin drawing the locaiton on the map
            self.globalLocationsCoordinates.append(location.coordinate)// apends the location to the lcoation array
            let polyline = MKPolyline(coordinates: self.globalLocationsCoordinates, count: self.globalLocationsCoordinates.count// creates a polyline instance on the loation array
            )
            self.mapView.addOverlay(polyline)// adds the polyline overaly to the map
            if(self.isFirstLocationInDistanceTracking){//begin calculating distance
                self.fistLocation = CLLocation(latitude: (location.coordinate.latitude), longitude: location.coordinate.longitude);//grabs the lat and lattude of the first locaiton
                self.workoutDistance = 0;// starts with defaul of 0 in calculation
                print("Woekout distance \(workoutDistance)")
                self.isFirstLocationInDistanceTracking = false;// shows that it will no longer be the first location in the calculated distance
                DispatchQueue.main.async {//updates the diatnce on the viewcontroller
                    self.distanceLabel.text = "\(self.workoutDistance)"
                }
                
            }else{// calucats the distance after grabbing the first locaiton
                self.secondLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude);//  grabs the lat and latitiude of the second distance
                self.workoutDistance += secondLocation.distance(from: self.fistLocation);// calcualtes the change between the locations
                self.fistLocation = secondLocation;// sets up the location for the next call
                
                DispatchQueue.main.async {// updates the user on the distance
                    self.distanceLabel.text = "\(self.workoutDistance)"
                }
                
            }
        }else{//no workout in progress, does not draw the locaitons on the map
            self.isFirstLocationInDistanceTracking = true;
            self.workoutDistance = 0.0;
            DispatchQueue.main.async {
                self.distanceLabel.text = "\(self.workoutDistance)"
            }
        }
        
        let coordSpan = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)// how big of an area the map will display
        let coordRegion = MKCoordinateRegion(center: location.coordinate, span: coordSpan)// where the map should display
        self.mapView.setRegion(coordRegion, animated: true)// adds the region to the map
        if(!self.didWorkoutStart){// if there is a workout in progress
            let coordinatePin = MKPointAnnotation()// creates an annotation instance
            coordinatePin.coordinate = location.coordinate;//adds the coordinate to the annotation instance
            //coordinatePin.title = location.description;
            self.mapView.addAnnotation(coordinatePin)// adds the annotation to the map
        }else{
            for annot in self.mapView.annotations{//removes any annotations if there is no workout in progress
                self.mapView.removeAnnotation(annot)
            }
        }
        
    }
    
}
//MARK: Watch Session Delegates
extension ViewController:WCSessionDelegate{// ectension of viewcontroller class, for watch sesion delegate methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {// method is called if the watch sesion was setup succesfully
        print("WCSession was succesfully activated activation state: \(activationState)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {// can be used to see if the session is inactive
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {// can be used to see if the session got deavtivated
        
    }
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {// called when there is a message from the apple watch app
        //Do something because the apple watch is trying to communicate
        print("Just recieved message from the apple watch");
        if let realMessage = message["BPM"] as? Double{// checks to see if the message is in regards to the BPM
            print("Message is from BPM")
            DispatchQueue.main.async {
                self.BPMLabel.text = "\(realMessage)"// updates the users screen with the BPM passed
            }
        }
    }
}

//MARK: Map Overlay Delegate
extension ViewController:MKMapViewDelegate{// extension for the view controllert, for the mapview delegate methods
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {// method used to render the polylines
        //rendering method
        if(overlay is MKPolyline){// makes sure the over is of type MKPolyline
            let renderer = MKPolylineRenderer(overlay: overlay);// renders the overlay
            renderer.strokeColor = .red;// sets the color to red
            renderer.lineWidth = 3;// width of 3
            return renderer;//returns the renderer
        }
        
        return MKOverlayRenderer()// will return empty instance of render calss if not MKPolyline
    }
}
