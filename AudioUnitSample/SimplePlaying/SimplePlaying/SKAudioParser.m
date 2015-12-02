//
//  SKAudioParser.m
//  SKAudioQueue
//
//  Created by steven on 2015/1/22.
//  Copyright (c) 2015年 KKBOX. All rights reserved.
//

#import "SKAudioParser.h"

@implementation SKAudioParser


void audioFileStreamPropertyListenerProc(void *inClientData, AudioFileStreamID	inAudioFileStream, AudioFileStreamPropertyID inPropertyID, UInt32 *ioFlags)
{
	/*
  kAudioFileStreamProperty_ReadyToProducePackets           =    'redy',
  kAudioFileStreamProperty_FileFormat                      =    'ffmt',
  kAudioFileStreamProperty_DataFormat                      =    'dfmt',
  kAudioFileStreamProperty_FormatList                      =    'flst',
  kAudioFileStreamProperty_MagicCookieData                 =    'mgic',
  kAudioFileStreamProperty_AudioDataByteCount              =    'bcnt',
  kAudioFileStreamProperty_AudioDataPacketCount            =    'pcnt',
  kAudioFileStreamProperty_MaximumPacketSize               =    'psze',
  kAudioFileStreamProperty_DataOffset                      =    'doff',
  kAudioFileStreamProperty_ChannelLayout                   =    'cmap',
  kAudioFileStreamProperty_PacketToFrame                   =    'pkfr',
  kAudioFileStreamProperty_FrameToPacket                   =    'frpk',
  kAudioFileStreamProperty_PacketToByte                    =    'pkby',
  kAudioFileStreamProperty_ByteToPacket                    =    'bypk',
  kAudioFileStreamProperty_PacketTableInfo                 =    'pnfo',
  kAudioFileStreamProperty_PacketSizeUpperBound            =    'pkub',
  kAudioFileStreamProperty_AverageBytesPerPacket           =    'abpp',
  kAudioFileStreamProperty_BitRate                         =    'brat',
  kAudioFileStreamProperty_InfoDictionary                  =    'info'
	*/
	if (inPropertyID == 'dfmt') {
		AudioStreamBasicDescription description;
		UInt32 descriptionSize = sizeof(description);
		AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &descriptionSize, &description);
		[((__bridge SKAudioParser *)inClientData).delegate audioStreamParser:(__bridge SKAudioParser *)inClientData didObtainStreamDescription:&description];
	}
}


void audioFileStreamPacketsProc(void *inClientData, UInt32 inNumberBytes, UInt32 inNumberPackets, const void *inInputData, AudioStreamPacketDescription	*inPacketDescriptions)
{
	[((__bridge SKAudioParser *)inClientData).delegate audioStreamParser:((__bridge SKAudioParser *)inClientData) packetData:inInputData dataLength:inNumberBytes packetDescriptions:inPacketDescriptions packetsCount:inNumberPackets];
	
}

- (id)init
{
	self = [super init];
	if (self) {
		
		AudioFileStreamOpen((__bridge void *)(self), audioFileStreamPropertyListenerProc, audioFileStreamPacketsProc, kAudioFileMP3Type, &audioFileStreamID);
		
	}
	return self;
}

- (void)parseData:(NSData *)inData
{
	AudioFileStreamParseBytes(audioFileStreamID, (UInt32)[inData length], [inData bytes], 0);
}

@synthesize delegate;
@end
