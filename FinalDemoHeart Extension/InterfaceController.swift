//
//  InterfaceController.swift
//  FinalDemoHeart Extension
//
//  Created by Alexis Ponce on 7/14/21.
//

import WatchKit
import Foundation
import HealthKit
import WatchConnectivity
import os.log
class InterfaceController: WKInterfaceController{
    //MARK: Global Variable Decl
    
    @IBOutlet weak var workoutStateLabel: WKInterfaceLabel!
    
    var watchSession:WCSession?
    var healthStore:HKHealthStore?
    var workoutConfigutation = HKWorkoutConfiguration();
    var workoutSession: HKWorkoutSession?
    var workoutBuilder: HKLiveWorkoutBuilder?
    

    @IBOutlet weak var heartRateLevelLabel: WKInterfaceLabel!
    
    let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "FinalDemo")
    override func awake(withContext context: Any?) {
        // Configure interface objects here.
        setUpWCSession();
    }
    
    func setUpWCSession(){
        if(WCSession.isSupported()){
            self.watchSession = WCSession.default;
            self.watchSession?.delegate = self;
            self.watchSession?.activate();
        }
    }
    
    func setUpHealthData(){
        //setting up health data
        if(HKHealthStore.isHealthDataAvailable()){
            self.healthStore = HKHealthStore();
            
            let typeToShare:Set = [HKWorkoutType.workoutType(), HKWorkoutType.quantityType(forIdentifier: .heartRate)!, HKSeriesType.workoutRoute(), HKWorkoutType.quantityType(forIdentifier: .activeEnergyBurned)!, HKWorkoutType.quantityType(forIdentifier: .distanceWalkingRunning)!]
            
            let typeToRead:Set = [HKWorkoutType.workoutType(), HKWorkoutType.quantityType(forIdentifier: .heartRate)!, HKSeriesType.workoutRoute(), HKWorkoutType.quantityType(forIdentifier: .activeEnergyBurned)!, HKWorkoutType.quantityType(forIdentifier: .distanceWalkingRunning)!];
            
            self.healthStore?.requestAuthorization(toShare: typeToShare, read: typeToRead, completion: { (success, error) in
                if(!success){
                    if(error != nil){
                        print("There was a problem trying to request health access \(error!)")
                    }else{
                        print("Requesting health access was not succesfull, no error tho")
                    }
                }
            })
            self.workoutConfigutation.activityType = .running;
            self.workoutConfigutation.locationType = .outdoor;
            
            do{
                self.workoutSession = try HKWorkoutSession(healthStore: self.healthStore!, configuration: self.workoutConfigutation)
                self.workoutBuilder = (self.workoutSession?.associatedWorkoutBuilder())!
            }catch{
                print("Something went wrong when trying to create the workout session and builder");
            }
            
            self.workoutBuilder!.dataSource = HKLiveWorkoutDataSource(healthStore: self.healthStore!, workoutConfiguration: self.workoutConfigutation);
            self.workoutSession?.delegate = self;
            self.workoutBuilder?.delegate = self;
            
        }
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }

}

extension InterfaceController:HKWorkoutSessionDelegate{
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        
    }
    
    
}

extension InterfaceController:HKLiveWorkoutBuilderDelegate{
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let session = self.watchSession else{ return;}
        if(session.isReachable){
            for type in collectedTypes{
                guard let quantityType = type as? HKQuantityType else{
                    print("Type collected is not quantity type");
                    return;
                }
                
                let statistics = self.workoutBuilder?.statistics(for: quantityType);
                    switch statistics?.quantityType{
                    case HKObjectType.quantityType(forIdentifier: .heartRate):
                    
                        guard let validSession = self.workoutSession else{
                            print("Something is wrong with the session");
                            return;
                        }
                        let heartUnit = HKUnit.count().unitDivided(by: HKUnit.minute());
                        let heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: heartUnit);
                        self.heartRateLevelLabel.setText("BPM: \(String(describing: heartRate!))")
                        let dic:[String:Double] = ["BPM": heartRate!]
                        os_log("Got heart rate data")
                        self.watchSession?.sendMessage(dic, replyHandler: nil, errorHandler: { (error) in
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
        }else{
            self.workoutSession!.end();
            self.workoutStateLabel.setText("Workout Stopped")
            self.workoutBuilder?.endCollection(withEnd: Date()){ (Success, error) in
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

extension InterfaceController:WCSessionDelegate{
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let realMessage = message["Workout"] as? String{
            //there is a value in the index "Workout"
            if(realMessage == "Start"){
                //User is trying to start a workout
                self.setUpHealthData();
                self.workoutStateLabel.setText("Wokout Started")
                let sem = DispatchSemaphore(value: 0);
                self.workoutSession?.startActivity(with: Date());
                self.workoutBuilder?.beginCollection(withStart: Date(), completion: { (Success, error) in
                    guard Success else{
                        print("Something went wrong with starting to being the builder colelction \(String(describing: error?.localizedDescription))")
                        return;
                    }
                    sem.signal();
                })
                sem.wait()
            }
        }
        if let realMessage = message["Workout1"] as? String{
            //there is a value in the index "Workout1"
            if(realMessage == "Stop"){
                //User is trying to stop the workout
                self.workoutSession!.end();
                self.workoutStateLabel.setText("Workout Stopped")
                self.workoutBuilder?.endCollection(withEnd: Date()){ (Success, error) in
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
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        
    }
    
}
