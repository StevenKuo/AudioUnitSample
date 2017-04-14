//
//  ViewController.m
//  RemoteInput
//
//  Created by StevenKuo on 2015/12/2.
//  Copyright © 2015年 StevenKuo. All rights reserved.
//

#import "ViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "SKAudioParser.h"
#import "SKAudioBuffer.h"
#import "SKAudioConverter.h"

@interface ViewController ()
{
    AUGraph audioGraph;
    AUNode mixNode;
    AudioUnit mixAudioUnit;
    AUNode remoteIONode;
    AudioUnit remoteIOAudioUnit;
    
    SKAudioParser *parser;
    SKAudioBuffer *buffer;
    
    SKAudioConverter *converter;
}
- (OSStatus)requestNumberOfFrames:(UInt32)inNumberOfFrames ioData:(AudioBufferList  *)inIoData busNumber:(UInt32)inBusNumber;
@end


static void MyAudioUnitPropertyListenerProc(void *inRefCon, AudioUnit inUnit, AudioUnitPropertyID	inID, AudioUnitScope inScope,AudioUnitElement inElement);

static OSStatus RenderCallback(void *userData, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
static OSStatus RenderCallback2(void *userData, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

@implementation ViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        
        parser = [[SKAudioParser alloc] init];
        parser.delegate = self;
        
        buffer = [[SKAudioBuffer alloc] init];
        buffer.delegate = self;
        
        OSStatus status = noErr;
        status = NewAUGraph(&audioGraph);
        status = AUGraphOpen(audioGraph);
        
        AudioComponentDescription outputUnitDescription = [self outputUnitDescription];
        status = AUGraphAddNode(audioGraph, &outputUnitDescription, &remoteIONode);
        status = AUGraphNodeInfo(audioGraph, remoteIONode, &outputUnitDescription, &remoteIOAudioUnit);
        UInt32 maxFPS = 4096;
        status = AudioUnitSetProperty(remoteIOAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,&maxFPS, sizeof(maxFPS));
        
        AudioComponentDescription mixUnitDescription = [self mixUnitDescription];
        status = AUGraphAddNode(audioGraph, &mixUnitDescription, &mixNode);
        status = AUGraphNodeInfo(audioGraph, mixNode, &mixUnitDescription, &mixAudioUnit);
        status = AudioUnitSetProperty(mixAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,&maxFPS, sizeof(maxFPS));
        
        status = AUGraphConnectNodeInput(audioGraph, mixNode, 0, remoteIONode, 0);
        status = AUGraphConnectNodeInput(audioGraph, remoteIONode, 1, mixNode, 1);
        
        AudioStreamBasicDescription destFormat = LinearPCMStreamDescription();
        
        UInt32 oneFlag = 1;
        UInt32 busOne = 1;
        status = AudioUnitSetProperty(remoteIOAudioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, busOne, &oneFlag, sizeof(oneFlag));
        
        status = AudioUnitSetProperty(remoteIOAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &destFormat, sizeof(destFormat));
        
        status = AudioUnitSetProperty(remoteIOAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &destFormat, sizeof(destFormat));
        
        status = AudioUnitSetProperty(mixAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &destFormat, sizeof(destFormat));
        
        status = AudioUnitSetProperty(mixAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &destFormat, sizeof(destFormat));
        
        status = AudioUnitSetProperty(mixAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &destFormat, sizeof(destFormat));
        
        status = AudioUnitSetProperty(mixAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &destFormat, sizeof(destFormat));
        
        status = AudioUnitSetParameter(mixAudioUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 0.3, 0);
        
        
        status = AudioUnitAddPropertyListener(remoteIOAudioUnit, kAudioOutputUnitProperty_IsRunning, MyAudioUnitPropertyListenerProc, (__bridge void *)(self));
        
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProcRefCon = (__bridge void *)(self);
        callbackStruct.inputProc = RenderCallback;
        status = AUGraphSetNodeInputCallback(audioGraph, mixNode, 0, &callbackStruct);
        
        status = AUGraphInitialize(audioGraph);
        
        CAShow(audioGraph);
        AudioOutputUnitStop(remoteIOAudioUnit);
    }
    return self;
}

- (AudioComponentDescription)mixUnitDescription
{
    AudioComponentDescription mixerUnitDescription;
    bzero(&mixerUnitDescription, sizeof(AudioComponentDescription));
    mixerUnitDescription.componentType = kAudioUnitType_Mixer;
    mixerUnitDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerUnitDescription.componentFlags = 0;
    mixerUnitDescription.componentFlagsMask = 0;
    return mixerUnitDescription;
}

- (AudioComponentDescription)outputUnitDescription
{
    AudioComponentDescription outputUnitDescription;
    bzero(&outputUnitDescription, sizeof(AudioComponentDescription));
    outputUnitDescription.componentType = kAudioUnitType_Output;
    outputUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    outputUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputUnitDescription.componentFlags = 0;
    outputUnitDescription.componentFlagsMask = 0;
    return outputUnitDescription;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    OSStatus aError = AUGraphStart(audioGraph);
    aError = AudioOutputUnitStart(remoteIOAudioUnit);
    
    NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
    NSURLSessionConfiguration *myConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *operationSession = [NSURLSession sessionWithConfiguration:myConfiguration delegate:(id)self delegateQueue:operationQueue];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://s3-us-west-2.amazonaws.com/666666bucket/ece985aece828873749cf0e0d699.mp3"]];
    NSURLSessionTask *task = [operationSession dataTaskWithRequest:request];
    [task resume];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [parser parseData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    OSStatus aError = AUGraphStart(audioGraph);
    aError = AudioOutputUnitStart(remoteIOAudioUnit);
    
    NSLog(@"loading complete");
}


- (void)audioStreamParser:(SKAudioParser *)inParser didObtainStreamDescription:(AudioStreamBasicDescription *)inDescription
{
    NSLog(@"mSampleRate: %f", inDescription->mSampleRate);
    NSLog(@"mFormatID: %u", (unsigned int)inDescription->mFormatID);
    NSLog(@"mFormatFlags: %u", (unsigned int)inDescription->mFormatFlags);
    NSLog(@"mBytesPerPacket: %u", (unsigned int)inDescription->mBytesPerPacket);
    NSLog(@"mFramesPerPacket: %u", (unsigned int)inDescription->mFramesPerPacket);
    NSLog(@"mBytesPerFrame: %u", (unsigned int)inDescription->mBytesPerFrame);
    NSLog(@"mChannelsPerFrame: %u", (unsigned int)inDescription->mChannelsPerFrame);
    NSLog(@"mBitsPerChannel: %u", (unsigned int)inDescription->mBitsPerChannel);
    NSLog(@"mReserved: %u", (unsigned int)inDescription->mReserved);
    
    converter = [[SKAudioConverter alloc] initWithSourceFormat:inDescription];
}
- (void)audioStreamParser:(SKAudioParser *)inParser packetData:(const void * )inBytes dataLength:(UInt32)inLength packetDescriptions:(AudioStreamPacketDescription* )inPacketDescriptions packetsCount:(UInt32)inPacketsCount
{
    [buffer storePacketData:inBytes dataLength:inLength packetDescriptions:inPacketDescriptions packetsCount:inPacketsCount];
}

- (OSStatus)requestNumberOfFrames:(UInt32)inNumberOfFrames ioData:(AudioBufferList  *)inIoData busNumber:(UInt32)inBusNumber
{
    return [converter requestNumberOfFrames:inNumberOfFrames ioData:inIoData busNumber:inBusNumber buffer:buffer];
}

void MyAudioUnitPropertyListenerProc(void *inRefCon, AudioUnit inUnit, AudioUnitPropertyID inID, AudioUnitScope inScope,AudioUnitElement inElement)
{
    
}

static OSStatus RenderCallback(void *userData, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    ViewController *self = (__bridge ViewController *)userData;
    
    OSStatus status = [self requestNumberOfFrames:inNumberFrames ioData:ioData busNumber:inBusNumber];
    
    return status;
}

@end
