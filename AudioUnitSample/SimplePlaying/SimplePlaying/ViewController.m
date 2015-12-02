//
//  ViewController.m
//  SimplePlaying
//
//  Created by StevenKuo on 2015/11/11.
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
    AUNode node;
    AudioUnit audioUnit;
    
    SKAudioParser *parser;
    SKAudioBuffer *buffer;
    
    SKAudioConverter *converter;
}
@end

static void MyAudioUnitPropertyListenerProc(void *inRefCon, AudioUnit inUnit, AudioUnitPropertyID	inID, AudioUnitScope inScope,AudioUnitElement inElement);

static OSStatus RenderCallback(void *userData, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

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
        
        AudioComponentDescription unitDescription = [self unitDescription];
        status = AUGraphAddNode(audioGraph, &unitDescription, &node);
        status = AUGraphNodeInfo(audioGraph, node, &unitDescription, &audioUnit);
        UInt32 maxFPS = 4096;
        status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,&maxFPS, sizeof(maxFPS));
        
        AudioStreamBasicDescription destFormat = LinearPCMStreamDescription();
        
        status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &destFormat, sizeof(destFormat));
        status = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &destFormat, sizeof(destFormat));
        
        status = AudioUnitAddPropertyListener(audioUnit, kAudioOutputUnitProperty_IsRunning, MyAudioUnitPropertyListenerProc, (__bridge void *)(self));
        
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProcRefCon = (__bridge void *)(self);
        callbackStruct.inputProc = RenderCallback;
        
        status = AUGraphSetNodeInputCallback(audioGraph, node, 0, &callbackStruct);
        status = AUGraphInitialize(audioGraph);
        AudioOutputUnitStop(audioUnit);
        
    }
    return self;
}

- (AudioComponentDescription)unitDescription
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
    
    NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
    NSURLSessionConfiguration *myConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *operationSession = [NSURLSession sessionWithConfiguration:myConfiguration delegate:(id)self delegateQueue:operationQueue];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://s3-us-west-2.amazonaws.com/kkstevenbucket/0806d9c94785710f646501c0312b.mp3"]];
    NSURLSessionDataTask *task = [operationSession dataTaskWithRequest:request];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        OSStatus aError = AUGraphStart(audioGraph);
        aError = AudioOutputUnitStart(audioUnit);
        NSLog(@"loading complete");
    });
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
    OSStatus status = [converter requestNumberOfFrames:inNumberOfFrames ioData:inIoData busNumber:inBusNumber buffer:buffer];
    /* remove vocal
     UInt16 *data = inIoData->mBuffers[0].mData;
     for (int i = 0; i < inIoData->mBuffers[0].mDataByteSize; i += 2) {
     UInt16 left = data[i];
     UInt16 right = data[i + 1];
     UInt16 new = left - right;
     data[i] = new;
     data[i+1] = new;
     
     }
     */
    return status;
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
