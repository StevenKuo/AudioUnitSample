//
//  SKAudioParser.h
//  SKAudioQueue
//
//  Created by steven on 2015/1/22.
//  Copyright (c) 2015年 KKBOX. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class SKAudioParser;

@protocol SKAudioParserDelegate <NSObject>

- (void)audioStreamParser:(SKAudioParser *)inParser didObtainStreamDescription:(AudioStreamBasicDescription *)inDescription;
- (void)audioStreamParser:(SKAudioParser *)inParser packetData:(const void * )inBytes dataLength:(UInt32)inLength packetDescriptions:(AudioStreamPacketDescription* )inPacketDescriptions packetsCount:(UInt32)inPacketsCount;

@end

@interface SKAudioParser : NSObject
{
	AudioFileStreamID audioFileStreamID;
	__weak id <SKAudioParserDelegate> delegate;
}

- (void)parseData:(NSData *)inData;

@property (weak, nonatomic) id <SKAudioParserDelegate> delegate;
@end

