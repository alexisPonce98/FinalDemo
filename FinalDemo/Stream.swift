//
//  Stream.swift
//  FinalDemo
//
//  Created by Alexis Ponce on 7/14/21.
//

import Foundation
import HaishinKit
import AVFoundation
import AVKit
import VideoToolbox
class Stream:NSObject{
    var rtmpConnection = RTMPConnection();
    var rtmpStream:RTMPStream!;
    
    override init(){
        super.init()
        self.rtmpStream = RTMPStream(connection: self.rtmpConnection);
    }
    
    func beginStream(){
        self.rtmpConnection.connect("rtmps://a.rtmps.youtube.com/live2/", arguments: nil);
        self.rtmpStream.publish("a96x-69j1-4e7u-zqg9-ac2g");
    }
    
    func samples(sample:CMSampleBuffer?, isvdeo:Bool){
        guard let recievedSample = sample else{
            print("The sample buffers were NULL");
            return;
        }
        if(isvdeo){
            if let description = CMSampleBufferGetFormatDescription(recievedSample){
                let dimensions = CMVideoFormatDescriptionGetDimensions(description)
                self.rtmpStream.videoSettings = [
                    .width: dimensions.width,
                    .height: dimensions.height,
                    .profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel
                ]
            }
            self.rtmpStream.appendSampleBuffer(recievedSample, withType: .video);
        }else{
            self.rtmpStream.appendSampleBuffer(recievedSample, withType: .audio);
        }
    }
    
}
