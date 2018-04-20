//
//  SKAudioBuffer.h
//  SKAudioQueue
//
//  Created by steven on 2015/1/22.
//  Copyright (c) 2015年 KKBOX. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

typedef struct {
    AudioStreamPacketDescription packetDescription;
    void *data;
} AudioPacketInfo;

@class SKAudioBuffer;

@protocol SKAudioBufferDelegate <NSObject>

- (AudioStreamBasicDescription)usedAudioStreamBasicDescription;
- (void)audioBufferDidBeginReadPacket:(SKAudioBuffer *)inBuffer;
@end

@interface SKAudioBuffer : NSObject
{
    __weak id <SKAudioBufferDelegate> delegate;
    
    AudioPacketInfo *packets;
    size_t packetWriteIndex;
    size_t packetReadIndex;
    size_t packetCount;
    
    NSMutableData *audioData;
    NSMutableData *packetDescData;
    NSUInteger packetReadHead;
    NSUInteger readPacketIndex;
}


- (void)storePacketData:(const void * )inBytes dataLength:(UInt32)inLength packetDescriptions:(AudioStreamPacketDescription* )inPacketDescriptions packetsCount:(UInt32)inPacketsCount;
- (void)movePacketReadIndex;

@property (readonly, nonatomic) size_t availablePacketCount;
@property (weak, nonatomic) id <SKAudioBufferDelegate> delegate;
@property (readonly, nonatomic) AudioPacketInfo currentPacketInfo;
@end
