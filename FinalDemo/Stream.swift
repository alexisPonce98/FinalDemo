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
import AudioToolbox
class Stream:NSObject{
    var rtmpConnection = RTMPConnection();
    var rtmpStream:RTMPStream!;
    var Channels:Int?
    override init(){
        super.init()
        self.rtmpStream = RTMPStream(connection: self.rtmpConnection);
    }
    
    func beginStream(){
        //self.rtmpStream.receiveAudio = true;
        self.rtmpStream.audioSettings = [
            .sampleRate: 44100.0,
            .bitrate: 32 * 1024,
            .actualBitrate: 96000,
        ]
        self.rtmpStream.recorderSettings = [
            AVMediaType.audio: [
                AVNumberOfChannelsKey: 0,
                AVSampleRateKey: 0
            ]
        ]
        self.rtmpConnection.connect("rtmps://a.rtmps.youtube.com/live2/", arguments: nil);
        self.rtmpStream.publish("a96x-69j1-4e7u-zqg9-ac2g");
        self.rtmpStream.attachAudio(nil)
        self.rtmpStream.attachCamera(nil)
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
            print("Trying to append audio");
            self.rtmpStream.appendSampleBuffer(recievedSample, withType: .audio);
        }
    }
    
    func attachAudio(device:AVCaptureDevice){
        self.rtmpStream.attachAudio(device, automaticallyConfiguresApplicationAudioSession: false) { (error) in
            if(error != nil){
                print("There was an error when attaching the audio device to the stream")
            }
        }
    }
}
