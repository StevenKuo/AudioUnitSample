//
//  SKAudioConverter.h
//  SimplePlaying
//
//  Created by StevenKuo on 2015/11/11.
//  Copyright © 2015年 StevenKuo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "SKAudioBuffer.h"

@interface SKAudioConverter : NSObject
{
    AudioStreamBasicDescription audioStreamDescription;
    AudioStreamBasicDescription destFormat;
    AudioConverterRef converter;
    AudioBufferList *renderBufferList;
    UInt32 renderBufferSize;
}

AudioStreamBasicDescription LinearPCMStreamDescription();

- (instancetype)initWithSourceFormat:(AudioStreamBasicDescription *)sourceFormat;
- (OSStatus)requestNumberOfFrames:(UInt32)inNumberOfFrames ioData:(AudioBufferList  *)inIoData busNumber:(UInt32)inBusNumber buffer:(SKAudioBuffer *)inBuffer;

- (void)_fillBufferlist:(AudioBufferList *)ioData withBuffer:(SKAudioBuffer *)buffer packetDescription:(AudioStreamPacketDescription** )outDataPacketDescription;

@end
