//
//  Stream.swift
//  FinalDemo
//  this class will handle the initilization of the stream, and receive/ send audio/video buffers
//  Created by Alexis Ponce on 7/14/21.
//

import Foundation
import HaishinKit
import AVFoundation
import AVKit
import VideoToolbox
import AudioToolbox
class Stream:NSObject{
    
    var rtmpConnection = RTMPConnection();// instance of the RTMP connection from haishinkit
    var rtmpStream:RTMPStream!;// instance of the stream to handle the audio and video
    var Channels:Int?// audio channels used
    override init(){
        super.init()
        self.rtmpStream = RTMPStream(connection: self.rtmpConnection);// initializes the RTMP connection isntance
    }
    
    func beginStream(){// method will be call to setup the stream settings and setup the connection
        //self.rtmpStream.receiveAudio = true;
        self.rtmpStream.audioSettings = [// sets up the audio settings
            .sampleRate: 44100.0,
            .bitrate: 32 * 1024,
            .actualBitrate: 96000,
        ]
        self.rtmpStream.recorderSettings = [// sets up the recording settings
            AVMediaType.audio: [
                AVNumberOfChannelsKey: 0,
                AVSampleRateKey: 0
            ]
        ]
//        self.rtmpConnection.connect("rtmps://a.rtmps.youtube.com/live2/", arguments: nil);
//        self.rtmpStream.publish("a96x-69j1-4e7u-zqg9-ac2g");
        let streamURL = "rtmps://030c054ffef4.global-contribute.live-video.net:443/app/"// url where the stream will be sent to
        let pub = "sk_us-east-1_j2IQHDjSZbcm_BpLZpO7esixBxSgqg9RTdH6jlpXV4P"// the key for the account where the stream is being sent
        self.rtmpConnection.connect(streamURL, arguments: nil)// connects to the stream url
        self.rtmpStream.publish(pub)// sends the public key
        self.rtmpStream.attachAudio(nil)
        self.rtmpStream.attachCamera(nil)
    }
    
    func samples(sample:CMSampleBuffer?, isvdeo:Bool){// method to send the audio and video samples
        guard let recievedSample = sample else{// checks to see if the passed bufer is not nil
            print("The sample buffers were NULL");
            return;
        }
        if(isvdeo){// if the buffer is a video
            if let description = CMSampleBufferGetFormatDescription(recievedSample){// stores the sample buffer format description
                let dimensions = CMVideoFormatDescriptionGetDimensions(description)// stores the dimensions of the sample buffer
                self.rtmpStream.videoSettings = [
                    .width: dimensions.width,// stores the width
                    .height: dimensions.height,// stored the heigh
                    .profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel// sets the profile of the video
                ]
            }
            self.rtmpStream.appendSampleBuffer(recievedSample, withType: .video);// sends the buffere to the stream

        }else{
            self.rtmpStream.appendSampleBuffer(recievedSample, withType: .audio);// sends the audio to the stream
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
