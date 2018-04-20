//
//  ViewController.m
//  MixPlaying
//
//  Created by StevenKuo on 2015/11/19.
//  Copyright © 2015年 StevenKuo. All rights reserved.
//

#import "ViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "SKAudioParser.h"
#import "SKAudioBuffer.h"
#import "SKAudioConverter.h"

@interface ViewController ()<SKAudioParserDelegate>
{
    AUGraph audioGraph;
    AUNode mixNode;
    AudioUnit mixAudioUnit;
    AUNode outputNode;
    AudioUnit outputAudioUnit;
    
    SKAudioParser *parser;
    SKAudioBuffer *buffer;
    SKAudioBuffer *buffer2;
    SKAudioParser *parser2;
    
    SKAudioConverter *converter;
    SKAudioConverter *converter2;
    
    NSURLSessionDataTask *task1;
    NSURLSessionDataTask *task2;
    
    BOOL firstComplete;
    IBOutlet UITextField *textFeild;
    IBOutlet UITextField *textFeild2;
    IBOutlet UILabel *tip;
}

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
        
        parser2 = [[SKAudioParser alloc] init];
        parser2.delegate = self;
        
        buffer = [[SKAudioBuffer alloc] init];
        
        
        buffer2 = [[SKAudioBuffer alloc] init];
        
        
        OSStatus status = noErr;
        status = NewAUGraph(&audioGraph);
        status = AUGraphOpen(audioGraph);
        
        AudioComponentDescription outputUnitDescription = [self outputUnitDescription];
        status = AUGraphAddNode(audioGraph, &outputUnitDescription, &outputNode);
        status = AUGraphNodeInfo(audioGraph, outputNode, &outputUnitDescription, &outputAudioUnit);
        UInt32 maxFPS = 4096;
        status = AudioUnitSetProperty(outputAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,&maxFPS, sizeof(maxFPS));
        
        AudioComponentDescription mixUnitDescription = [self mixUnitDescription];
        status = AUGraphAddNode(audioGraph, &mixUnitDescription, &mixNode);
        status = AUGraphNodeInfo(audioGraph, mixNode, &mixUnitDescription, &mixAudioUnit);
        status = AudioUnitSetProperty(mixAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,&maxFPS, sizeof(maxFPS));
        
        status = AUGraphConnectNodeInput(audioGraph, mixNode, 0, outputNode, 0);
        
        AudioStreamBasicDescription destFormat = LinearPCMStreamDescription();
        
        status = AudioUnitSetProperty(mixAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &destFormat, sizeof(destFormat));
        
        status = AudioUnitSetProperty(mixAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &destFormat, sizeof(destFormat));
        
        status = AudioUnitSetProperty(mixAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &destFormat, sizeof(destFormat));
        
        status = AudioUnitSetProperty(outputAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &destFormat, sizeof(destFormat));
        
//        status = AudioUnitSetParameter(mixAudioUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 0.5, 0);
//        status = AudioUnitSetParameter(mixAudioUnit, kMultiChannelMixerParam_Pan, kAudioUnitScope_Input, 0, 1, 1);
//        status = AudioUnitSetParameter(mixAudioUnit, kMultiChannelMixerParam_Pan, kAudioUnitScope_Input, 1, -1, 1);
        
        
        status = AudioUnitAddPropertyListener(outputAudioUnit, kAudioOutputUnitProperty_IsRunning, MyAudioUnitPropertyListenerProc, (__bridge void *)(self));
        
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProcRefCon = (__bridge void *)(self);
        callbackStruct.inputProc = RenderCallback;
        status = AUGraphSetNodeInputCallback(audioGraph, mixNode, 0, &callbackStruct);
        
        AURenderCallbackStruct callbackStruct2;
        callbackStruct2.inputProcRefCon = (__bridge void *)(self);
        callbackStruct2.inputProc = RenderCallback2;
        status = AUGraphSetNodeInputCallback(audioGraph, mixNode, 1, &callbackStruct2);
        
        status = AUGraphInitialize(audioGraph);
        AudioOutputUnitStop(outputAudioUnit);
    }
    return self;
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


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [textField setEnabled:NO];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [textField resignFirstResponder];
    [textField setEnabled:NO];
    if (textFeild.text.length != 0 && textFeild2.text.length != 0) {
        NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
        NSURLSessionConfiguration *myConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        NSURLSession *operationSession = [NSURLSession sessionWithConfiguration:myConfiguration delegate:(id)self delegateQueue:operationQueue];
        
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:textFeild.text]];
        task1 = [operationSession dataTaskWithRequest:request];
        [task1 resume];
        
        NSURLRequest *request2 = [NSURLRequest requestWithURL:[NSURL URLWithString:textFeild2.text]];
        task2 = [operationSession dataTaskWithRequest:request2];
        [task2 resume];
    }

}

- (BOOL)_outputNodePlaying
{
    UInt32 property = 0;
    UInt32 propertySize = sizeof(property);
    AudioUnitGetProperty(outputAudioUnit, kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0, &property, &propertySize);
    return property != 0;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    dispatch_async(dispatch_get_main_queue(), ^{
        tip.text = @"receiving data...";
        tip.textColor = UIColor.blackColor;
        firstComplete = YES;
    });
    if ([dataTask isEqual:task1]) {
        [parser parseData:data];
    }
    else if ([dataTask isEqual:task2]) {
        if (![self _outputNodePlaying] && firstComplete) {
            OSStatus aError = AUGraphStart(audioGraph);
            aError = AudioOutputUnitStart(outputAudioUnit);
        }
        [parser2 parseData:data];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            tip.textColor = UIColor.redColor;
            tip.text = @"Fail";
            textFeild.text = @"";
            [textFeild setEnabled:YES];
            return;
        }
        tip.text = @"";
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
    
    if ([inParser isEqual:parser]) {
        converter = [[SKAudioConverter alloc] initWithSourceFormat:inDescription];
    }
    else if ([inParser isEqual:parser2]) {
        converter2 = [[SKAudioConverter alloc] initWithSourceFormat:inDescription];
    }
}
- (void)audioStreamParser:(SKAudioParser *)inParser packetData:(const void * )inBytes dataLength:(UInt32)inLength packetDescriptions:(AudioStreamPacketDescription* )inPacketDescriptions packetsCount:(UInt32)inPacketsCount
{
    if ([inParser isEqual:parser]) {
        [buffer storePacketData:inBytes dataLength:inLength packetDescriptions:inPacketDescriptions packetsCount:inPacketsCount];
    }
    else if ([inParser isEqual:parser2]){
        [buffer2 storePacketData:inBytes dataLength:inLength packetDescriptions:inPacketDescriptions packetsCount:inPacketsCount];
    }
}

- (OSStatus)requestNumberOfFrames:(UInt32)inNumberOfFrames ioData:(AudioBufferList  *)inIoData busNumber:(UInt32)inBusNumber
{
    if (buffer.availablePacketCount < converter.packetsPerSecond * 4) {
        return -1;
    }
    return [converter requestNumberOfFrames:inNumberOfFrames ioData:inIoData busNumber:inBusNumber buffer:buffer];
}

- (OSStatus)requestNumberOfFrames2:(UInt32)inNumberOfFrames ioData:(AudioBufferList  *)inIoData busNumber:(UInt32)inBusNumber
{
    if (buffer2.availablePacketCount < converter2.packetsPerSecond * 4) {
        return -1;
    }
    return [converter2 requestNumberOfFrames:inNumberOfFrames ioData:inIoData busNumber:inBusNumber buffer:buffer2];
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

static OSStatus RenderCallback2(void *userData, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    ViewController *self = (__bridge ViewController *)userData;
    
    OSStatus status = [self requestNumberOfFrames2:inNumberFrames ioData:ioData busNumber:inBusNumber];
    
    return status;
}

@end
