//
//  InterfaceController.swift
//  FinalDemoHeart Extension
//  This class is for the apple watch app that will grab the users heart rate
//  Created by Alexis Ponce on 7/14/21.
//

import WatchKit
import Foundation
import HealthKit
import WatchConnectivity
import os.log
class InterfaceController: WKInterfaceController{
    //MARK: Global Variable Decl
    
    @IBOutlet weak var workoutStateLabel: WKInterfaceLabel!// label to the show what the workout state is
    
    var watchSession:WCSession?// global variable for the watch sesion
    var healthStore:HKHealthStore?// global variable for the healthstore
    var workoutConfigutation = HKWorkoutConfiguration();// global variable for the workout configuration
    var workoutSession: HKWorkoutSession?// global variable for the workout session
    var workoutBuilder: HKLiveWorkoutBuilder?// global variable for the live workout builder
    

    @IBOutlet weak var heartRateLevelLabel: WKInterfaceLabel!// label to show the heart rate
    
    let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "FinalDemo")// used to debug issuses, prints on the OS level
    override func awake(withContext context: Any?) {
        // Configure interface objects here.
        setUpWCSession();
    }
    
    func setUpWCSession(){// sets up the watch session
        if(WCSession.isSupported()){// if watch session is supported
            self.watchSession = WCSession.default;// sets the watch session to default config
            self.watchSession?.delegate = self;// lets the watch session know to call delegate methods
            self.watchSession?.activate();// activates the watch session
        }
    }
    
    func setUpHealthData(){// method to setup the health data
        //setting up health data
        if(HKHealthStore.isHealthDataAvailable()){// if health data is available on this device
            self.healthStore = HKHealthStore();// initializes the health store
            
            let typeToShare:Set = [HKWorkoutType.workoutType(), HKWorkoutType.quantityType(forIdentifier: .heartRate)!, HKSeriesType.workoutRoute(), HKWorkoutType.quantityType(forIdentifier: .activeEnergyBurned)!, HKWorkoutType.quantityType(forIdentifier: .distanceWalkingRunning)!]// types that we would like access to share
            
            let typeToRead:Set = [HKWorkoutType.workoutType(), HKWorkoutType.quantityType(forIdentifier: .heartRate)!, HKSeriesType.workoutRoute(), HKWorkoutType.quantityType(forIdentifier: .activeEnergyBurned)!, HKWorkoutType.quantityType(forIdentifier: .distanceWalkingRunning)!];// data types that we would like access to read
            
            self.healthStore?.requestAuthorization(toShare: typeToShare, read: typeToRead, completion: {// requests healthstore authorization from the user
                (success, error) in
                if(!success){
                    if(error != nil){// if unsucessfule and there is an error
                        print("There was a problem trying to request health access \(error!)")
                    }else{
                        print("Requesting health access was not succesfull, no error tho")
                    }
                }
            })
            self.workoutConfigutation.activityType = .running;// sets the activity type ad running
            self.workoutConfigutation.locationType = .outdoor;// sets the location to outside
            
            do{
                self.workoutSession = try HKWorkoutSession(healthStore: self.healthStore!, configuration: self.workoutConfigutation)// tries to start the workout session
                self.workoutBuilder = (self.workoutSession?.associatedWorkoutBuilder())!// begins the live workout
            }catch{
                print("Something went wrong when trying to create the workout session and builder");
            }
            
            self.workoutBuilder!.dataSource = HKLiveWorkoutDataSource(healthStore: self.healthStore!, workoutConfiguration: self.workoutConfigutation);// tell the live workout builder where to get the data from
            self.workoutSession?.delegate = self;// tell the workout sesion to call the delegate methods
            self.workoutBuilder?.delegate = self;// tells the workout builder to call the delegate methods
            
        }
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }

}

extension InterfaceController:HKWorkoutSessionDelegate{// extension of the interface controllert for the workout session
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        
    }
    
    
}

extension InterfaceController:HKLiveWorkoutBuilderDelegate{// extension of the interface controller for the live workout builder delgate methods
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {// method is called when there is data ready
        guard let session = self.watchSession else{ return;}// makes sure the watch sesion is not nil
        if(session.isReachable){//makes sure the iphone is reachable
            for type in collectedTypes{// iterates through the colleciotn
                guard let quantityType = type as? HKQuantityType else{// grabs the data of HKQuantitytype
                    print("Type collected is not quantity type");
                    return;
                }
                
                let statistics = self.workoutBuilder?.statistics(for: quantityType);// grabs the statistics from the quantity type
                    switch statistics?.quantityType{
                    case HKObjectType.quantityType(forIdentifier: .heartRate):// if there is heart rate data
                    
                        guard let validSession = self.workoutSession else{// checks to see if there is a wrokout session
                            print("Something is wrong with the session");
                            return;
                        }
                        let heartUnit = HKUnit.count().unitDivided(by: HKUnit.minute());// the unit to be measured by
                        let heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: heartUnit);//grabs the most recent calculated value fore heart rate, with units
                        self.heartRateLevelLabel.setText("BPM: \(String(describing: heartRate!))")// updates the user of the most recent calculated heart rate
                        let dic:[String:Double] = ["BPM": heartRate!]// message to be sent to the iphone app
                        os_log("Got heart rate data")
                        self.watchSession?.sendMessage(dic, replyHandler: nil, errorHandler: { (error) in// heart rate message to send to the iphone app
                            if(error != nil){
                                print("There was a problem when trying to send the message from the watch to the iPhone");
                            }
                        })
                        break;
                    case HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning):
                        break;
                    default:
                        break;
                    }
            }
        }else{// if iphone app not reachable
            self.workoutSession!.end();//ends the workout session
            self.workoutStateLabel.setText("Workout Stopped")// updates the user that the workout has ended
            self.workoutBuilder?.endCollection(withEnd: Date()){ (Success, error) in//ends the collesion of the workout live builder
                if(!Success){
                    print("Something happened when trying to end collection of wokrout data for the builder: \(String(describing: error?.localizedDescription))");
                }
                
                self.workoutBuilder?.finishWorkout(completion: { (HKWorkout, error) in
                    guard HKWorkout != nil else{
                        print("Something went wrong when finishing the workout error code: \(String(describing: error?.localizedDescription))");
                        return
                    }
                })
            }
        }
    }
    
    
}

extension InterfaceController:WCSessionDelegate{// extension of the interfacecontroller for the watch session
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {// if recieved a message from the iphone app
        if let realMessage = message["Workout"] as? String{// checks if there is a key "workout"
            //there is a value in the index "Workout"
            if(realMessage == "Start"){
                //User is trying to start a workout
                self.setUpHealthData();// calls the method to set up the healthdata
                self.workoutStateLabel.setText("Wokout Started")// lets the user know that the workout started
                let sem = DispatchSemaphore(value: 0);// semaphore to wait for the completion of the workout builder
                self.workoutSession?.startActivity(with: Date());// sets the date of the begining of the workout
                self.workoutBuilder?.beginCollection(withStart: Date(), completion: { (Success, error) in
                    guard Success else{
                        print("Something went wrong with starting to being the builder colelction \(String(describing: error?.localizedDescription))")
                        return;
                    }
                    sem.signal();// lets the semaphore know to continue
                })
                sem.wait()
            }
        }
        if let realMessage = message["Workout1"] as? String{// checks to see if there is a message under "workout1"
            //there is a value in the index "Workout1"
            if(realMessage == "Stop"){
                //User is trying to stop the workout
                self.workoutSession!.end();// ends the workoutsession
                self.workoutStateLabel.setText("Workout Stopped")// lets the user know the workout has stopped
                self.workoutBuilder?.endCollection(withEnd: Date()){ (Success, error) in// ends the collection of health data
                    if(!Success){
                        print("Something happened when trying to end collection of wokrout data for the builder: \(String(describing: error?.localizedDescription))");
                    }
                    
                    self.workoutBuilder?.finishWorkout(completion: { (HKWorkout, error) in// ends the workout
                        guard HKWorkout != nil else{
                            print("Something went wrong when finishing the workout error code: \(String(describing: error?.localizedDescription))");
                            return
                        }
                    })
                }
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        
    }
    
}
