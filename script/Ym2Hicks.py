#!/usr/bin/env python3
import io
import os
import sys
import struct
import lhafile

NR_YM_REGISTERS = 14

###################################################################################
#
# Helper functions
#
###################################################################################

#
# Read a NULL-terminated string from binary file.
#
def ReadString(fd):
	return ''.join(iter(lambda: fd.read(1).decode("utf-8"), '\x00'))

#
# Print a byte array as formated 2 digits hex
#
def hprint(data):
	for i in range(len(data)):
		print(f"{data[i]:02x}", end=" ")
		if i % 16 == 15:
			print("")

###################################################################################
#
# Compute stat on a sliding window
#
###################################################################################

class WindowStat:
	#
	# Constructor
	#
	def __init__(self, WindowSize):
		self.Size = WindowSize
		self.Index = 0
		self.SumArray = [0] * WindowSize
		self.MinAvg = 1000
		self.MaxAvg = 0
		self.Sum = 0
		self.Loop = False

	def AddValue(self, Val):
		if self.Loop:
			self.MinAvg = min (self.MinAvg, sum(self.SumArray) / self.Size)
			self.MaxAvg = max (self.MaxAvg, sum(self.SumArray) / self.Size)
			self.Sum = self.Sum - self.SumArray[self.Index]

		self.Sum = self.Sum + Val
		self.SumArray[self.Index] = Val
		self.Index = (self.Index + 1) % self.Size		
		if self.Index == 0:
			self.Loop = True

###################################################################################
#
# YM File Reader
#
###################################################################################

class YmReader:
	#
	# Constructor: open and check the file is a valid and supported YM file.
	#
	def __init__(self, FileName):
		self.FileName = FileName

		# Open descriptor on the file and handle special case for LHA compressed files
		if lhafile.is_lhafile(FileName):
			LhaHandle = lhafile.Lhafile(FileName)
			for info in LhaHandle.infolist():
				LhaFileName = info.filename
			self.fd = io.BytesIO(LhaHandle.read(LhaFileName))
		else:
			self.fd = open(FileName,"rb")
		
		# Check the file is a valid YM file.
		Magic = self.fd.read(4)
		Magic = Magic.decode("utf-8")
		if Magic[:2] != "YM" and Magic[3] != "!":
			raise Exception(f"{self.FileName} is not a YM file.")

		if Magic[2] != "5" and Magic[2] != "6":
			raise Exception(f"YM version {Magic[2]} is not supported.")
	
		self.YmVersion = Magic[2]

	#
	# Import YM header
	#
	def ReadHeader(self):
		YmHeaderFormat = '> 8s I I H I H I H'
		self.Header = {}
		RawData = self.fd.read(struct.calcsize(YmHeaderFormat))
		(CheckString,
		 self.NbFrames,
		 Attributes,
		 self.NbDigidrums,
		 self.Clock,
		 self.FrameRate,
		 self.LoopFrame,
		 ExtraDataSize
		 ) = struct.unpack(YmHeaderFormat, RawData)

		#
		# Verify header check string
		#
		CheckString = CheckString.decode("utf-8")
		if CheckString != "LeOnArD!":
			raise Exception(f"Invalid file header. {CheckString}")

		self.Interleaved = (Attributes & 0x01) != 0
		self.SignedDigidrums = (Attributes & 0x02) != 0
		self.St4Digidrums = (Attributes & 0x04) != 0
		self.NrRegisters = 16

		print("\nFile header:")
		print(f"  - Nb of frames:    {self.NbFrames}")
		print(f"  - Interleaved:     {self.Interleaved}")
		print(f"  - Nb of digidrums: {self.NbDigidrums}")
		print(f"  - Clock:           {self.Clock}")
		print(f"  - Frame rate:      {self.FrameRate}")
		print(f"  - Loop Frame:      {self.LoopFrame}")
		print(f"  - Extra Data size: {ExtraDataSize}")

		if (ExtraDataSize != 0):
			raise Exception("Non null extra Data size is not supported")

	#
	# Load digidrums
	#
	def LoadDigidrums(self):
		if (self.NbDigidrums != 0):
			raise Exception("Not implemented")

	#
	# Import YM header
	#
	def LoadSongInfo(self):
		self.SongName = ReadString(self.fd)
		self.Author = ReadString(self.fd)
		self.Comment = ReadString(self.fd)

		print("\nSong Informations:")		
		print(f"  - Song name: {self.SongName}")
		print(f"  - Author:    {self.Author}")
		print(f"  - Comment:   {self.Comment}")

	#
	# Load frames as a 2D array indexed as [Register #] [Frame #]
	#
	def LoadInterleavedFrames(self):
		RawData = self.fd.read(self.NrRegisters * self.NbFrames)

		Magic = self.fd.read(4)
		Magic = Magic.decode("utf-8")
		
		if	Magic != "End!":
			raise Exception(f"Truncated or malformed file.")

		self.Registers = {}
		for r in range(NR_YM_REGISTERS):
			Frames = b''
			for f in range(self.NbFrames):
				Frames = Frames + (RawData[r * self.NbFrames + f]).to_bytes(1, "little")
			self.Registers[r] = bytearray(Frames)

	#
	# Some YM exports can insert zeroes in registers R11/R12/R13 when bit 4 is not set in volume control registers.
	# This could decrease the quality of compression routines.
	#
	def FixHoles(self, R8, R9, R10, R11, R12, R13):
		for i in range (1, len(R8)):
			if ((R8[i] & 0x10) == 0) and ((R9[i] & 0x10) == 0) and ((R10[i] & 0x10) == 0):
				R11[i] = R11[i-1]
				R12[i] = R12[i-1]
				R13[i] = R13[i-1]

	#
	# Import YM File
	#
	def Import(self):
		print("Import YM File");
		print(f"  - YM Version: {self.YmVersion}")

		self.ReadHeader()
		self.LoadDigidrums()
		self.LoadSongInfo()
		if self.Interleaved:
			self.LoadInterleavedFrames()
		else:
			raise Exception(f"Non Interleaved Data: not implemented.")

		self.FixHoles(self.Registers[8], self.Registers[9], self.Registers[10], self.Registers[11], self.Registers[12], self.Registers[13])
	
###################################################################################
#
# Compress Data
#
###################################################################################

class LzssCompressor:
	#
	# Constructor
	#
	def __init__(self, WindowSize, LitMaxSize):
		self.WindowSize = WindowSize
		self.LitMaxSize = LitMaxSize
		self.MatchMaxSize = 256 - LitMaxSize + 1
		self.OffsetLen = 2

	def GetWrappedSlice(self, x, NumBytes):
		Repetitions = NumBytes // len(x)
		Remainder = NumBytes % len(x)
		return x * Repetitions + x[:Remainder]

	def FindLongestMatch(self, Data, CurPos):
		EndOfBuffer = min(CurPos + self.MatchMaxSize, len(Data))
		SearchStart = max(0, CurPos - self.WindowSize)
	
		for MatchCandidateEnd in range(EndOfBuffer, CurPos + self.OffsetLen, -1):
			MatchCandidate = Data[CurPos:MatchCandidateEnd]
			for SearchPos in range(SearchStart, CurPos):
				if MatchCandidate == self.GetWrappedSlice(Data[SearchPos:CurPos], len(MatchCandidate)):
					return CurPos - SearchPos, len(MatchCandidate)

	#
	# Encode a Literal into the crunch Buffer
	#
	def EncodeLiteral(self, Buffer, Literal):
		# Write Literal length
		LitLen = len(Literal)-1
		Buffer = Buffer + LitLen.to_bytes(1, "little")
		
		# Write Literals
		Buffer = Buffer + Literal
		return Buffer

	#
	# Encode a match into the crunch Buffer
	#
	def EncodeMatch(self, Buffer, Distance, Length):	
		# Write copy Length
		CopyLen = Length + 0x1D
		Buffer = Buffer + CopyLen.to_bytes(1, "little")
		# Write offset
		Distance = Distance - 1
		Buffer = Buffer + Distance.to_bytes(1, "little")
		
		return Buffer		

	# Copy Literal: Save NLit-1 + Lit
	# Copy from Buffer: Save BufSize +1D + (Offset - 1)
	#      --> Min Buffer size = 3	
	def compress(self, Data, LoopStart):
		Stats = WindowStat(20)
		i = 0
		Literal=b''
		Crunch=b''
		MinDecrunchRatio = 2
		if LoopStart:
			PrevLen1 = PrevLen2 = 1
		else:
			PrevLen1 = PrevLen2 = -1

		while i < len(Data):
			Match = self.FindLongestMatch(Data, i)

			if Match:
				#
				# Make sure that 2 following tokens decrunch at least X values
				# TODO: We can adjust the value MinDecrunchRatio if necessary, but probably useless
				#
				MatchDistance, MatchLength = Match
				if Literal and len(Literal) + MatchLength < MinDecrunchRatio:
					Match = False
				elif PrevLen2 + MatchLength < MinDecrunchRatio:
					Match = False

			if Match:
				MatchDistance, MatchLength = Match
				if Literal:
					PrevLen1 = PrevLen2
					PrevLen2 = len(Literal)
					Crunch = self.EncodeLiteral(Crunch, Literal)
					Stats.AddValue(len(Literal))
					Literal = b''

				Crunch = self.EncodeMatch(Crunch, MatchDistance, MatchLength)
				Stats.AddValue(MatchLength)

				PrevLen1 = PrevLen2
				PrevLen2 = MatchLength

				i += MatchLength
			else:
				Literal = Literal + Data[i:i+1]
				if len(Literal) == self.LitMaxSize:
					Crunch = self.EncodeLiteral(Crunch, Literal)
					Stats.AddValue(len(Literal))
					Literal = b''
					PrevLen1 = -1
					PrevLen2 = -1
				i += 1

		if Literal:
			Crunch = self.EncodeLiteral(Crunch, Literal)
			PrevLen1 = PrevLen2
			PrevLen2 = len(Literal)

		return Crunch, Stats

###################################################################################
#
# Hicks File Writer
#
###################################################################################

class HicksConvertor:
	#
	# Constructor
	#
	def __init__(self, FileName):
		self.R12IsConst = False
		self.RegistersToPlay = 13
		self.FileName = FileName
		self.Compressor = LzssCompressor(256, 31)
#			         0, 2, (1+3), 4, (5+13), 6, 7, 8, 9, 10, 11, 12]
		self.RegOrder = [0, 2, 1,     4, 5,      6, 7, 8, 9, 10, 11, 12]

	def MergeRegisters(self, R1, R2):
		for i in range (len(R1)):
			R1[i] = (R2[i] & 0x0f) << 4 | (R1[i] & 0x0f)

	def AdjustR6ForR5(self, R6, R5):
		for i in range (1, len(R6)):
			if R5[i] == R5[i-1]:
				R6[i] = R6[i] | 0x20

	def AdjustR6ForR13(self, R6, R13):
		for i in range (len(R6)):
			if R13[i] == 0xFF:
				R6[i] = R6[i] | 0x40
				R13[i] = R13[i-1]

	def SmoothRegisters(self, PeriodLow, PeriodHigh, Volume, Mixer, Voice):
		VoiceToneMask = 1 << (Voice-1)
		VoiceNoiseMask = VoiceToneMask << 3
		for i in range (1, len(Volume)):
			CurVol = Volume[i] & 0x0F
			PrevVol = Volume[i-1] & 0x0F
			VolMode = Volume[i] & 0x10
			ToneOff = (Mixer[i] & VoiceToneMask) == VoiceToneMask
			NoiseOff = (Mixer[i] & VoiceNoiseMask) == VoiceNoiseMask

			# Smooth Period if volume is 0 or tone if off.
			if Volume[i] == 0 or ToneOff:
				PeriodLow[i] = PeriodLow[i-1]
				PeriodHigh[i] = PeriodHigh[i-1]

			# Smooth volume if tone is off
			# In this case, volume is not used by the PSG.
			if ToneOff and NoiseOff:
				Volume[i] = VolMode | PrevVol

	#
	# Switch all 1 to 0 for period low byte. The 1 value will later be use to mark a "delta-play".
	#
	def FixPeriodLow(self, PeriodLow):
		for i in range (0, len(PeriodLow)):
			# 0 and 1 encode the same value. Smooth all 1 to 0.
			if PeriodLow[i] == 1:
				PeriodLow[i] = 0

	#
	# Smooth noise register when noise is off on every channels
	#
	def SmoothNoise(self, Noise, Mixer):

		for i in range (1, len(Noise)):
			NoiseOff = (Mixer[i] & 0b00111000) == 0b00111000
			if NoiseOff:
				Noise[i] = Noise[i-1]

	#
	# Count the number of constant registers
	#
	def CountConstantReg(self):
		ConstRegTxt = ""
		for r in range(NR_YM_REGISTERS):
			Constant = True
			for f in range(len(self.YmFile.Registers[r])):
				if self.YmFile.Registers[r][f] != self.YmFile.Registers[r][0]:
					Constant = False
			if Constant:
				if r == 12:
					self.R12IsConst = True					
				if ConstRegTxt == "":
					ConstRegTxt = ConstRegTxt + f"R{r}"
				else:
					ConstRegTxt = ConstRegTxt + f", R{r}"

		if ConstRegTxt == "":
			ConstRegTxt = "None"

		print(f"  - Constant registers:", ConstRegTxt)

	#
	# Compute the distance between the current register value and the previous value
	#
	def DistFromPrevValue(self, Register, Current, Next, MarkerValue, VolumeRegister):
		if Register[Current] == MarkerValue:
			return 1000
		if VolumeRegister and ((Register[Current] & 0x80) == (Register[Next] & 0x80)):
			return 1000
		if Current == 0:
			Start = self.YmFile.NbFrames - 1
		else:
			Start = Current-1
		for i in range (Start, 0, -1):
			if Register[i] != MarkerValue:
				return abs(Register[i] - Register[Current])
		return 1000

	#
	# Delay one register programming to the next frame.
	#
	def DelayOneRegister(self, Current, Next):
		Distance = {}
		PeriodLowRegisters = [0, 2, 4, 11]
		VolumeRegisters = [8, 9, 10]

		for r in PeriodLowRegisters:
			Distance[r] = self.DistFromPrevValue(self.YmFile.Registers[r], Current, Next, 1, False)
		for r in VolumeRegisters:
			Distance[r] = self.DistFromPrevValue(self.YmFile.Registers[r], Current, Next, 0xF4, True) * 8
		MinIndex, MinValue = min(Distance.items(), key=lambda x: x[1])

		if MinValue != 1000:
			self.YmFile.Registers[MinIndex][Next] = self.YmFile.Registers[MinIndex][Current]
			if MinIndex in PeriodLowRegisters:
				self.YmFile.Registers[MinIndex][Current] = 1
			else:
				self.YmFile.Registers[MinIndex][Current] = 0xF4
			return 1
		else:
			return 0

	#
	# Count max register changes for one frame and limit changes to 11.
	#
	def CountAndLimitRegChangesOneFrame(self, Current, Prev, Next):
		Changes = 0
		if self.YmFile.Registers[0][Current] != 1:
			Changes = Changes + 1
		if self.YmFile.Registers[1][Current] != self.YmFile.Registers[1][Prev]:
			Changes = Changes + 2
		if self.YmFile.Registers[2][Current] != 1:
			Changes = Changes + 1
		# Register[3] handled with register 1
		if self.YmFile.Registers[4][Current] != 1:
			Changes = Changes + 1
		if (self.YmFile.Registers[6][Current] & 0x80) == 0: # Register 6
			Changes = Changes + 1
		if (self.YmFile.Registers[6][Current] & 0x40) == 0: # Register 13
			Changes = Changes + 1
		if (self.YmFile.Registers[6][Current] & 0x20) == 0: # Register 5
			Changes = Changes + 1
		if self.YmFile.Registers[7][Current] != 0xF4:
			Changes = Changes + 1
		if self.YmFile.Registers[8][Current] != 0xF4:
			Changes = Changes + 1
		if self.YmFile.Registers[9][Current] != 0xF4:
			Changes = Changes + 1
		if self.YmFile.Registers[10][Current] != 0xF4:
			Changes = Changes + 1
		if self.YmFile.Registers[11][Current] != 1:
			Changes = Changes + 1
		if self.YmFile.Registers[12][Current] != self.YmFile.Registers[12][Prev]:
			Changes = Changes + 1

		if Changes > 12:
			Changes = Changes - self.DelayOneRegister(Current, Next)
 
		if Changes > 11:
			Changes = Changes - self.DelayOneRegister(Current, Next)

		return Changes

	#
	# Count max register changes and limit changes to 11.
	#
	def CountAndLimitRegChanges(self):
		MaxChanges = [0] * 15

		Stats={}
		for i in range(11):
			Stats[i] = WindowStat(220)
		for i in range (0, self.YmFile.NbFrames):
			if i == self.YmFile.NbFrames - 1:
				NextIndex = self.YmFile.LoopFrame
			else:
				NextIndex = i+1
			Changes = self.CountAndLimitRegChangesOneFrame(i, i-1, NextIndex)
			MaxChanges[Changes] = MaxChanges[Changes] + 1
			Stats[i%11].AddValue(Changes)

		if self.YmFile.LoopFrame != 0:
			Changes = self.CountAndLimitRegChangesOneFrame(self.YmFile.LoopFrame, self.YmFile.NbFrames - 1, self.YmFile.LoopFrame + 1)

		MaxChanges[Changes] = MaxChanges[Changes] + 1
		MaxAvg = 0
		for i in range(11):
			MaxAvg = max(MaxAvg, Stats[i].MaxAvg)
		print("  - Worst case average register changes: ", round(MaxAvg, 2))
		print("  - Frames / Number of registers modified")
		for i in range(0, 15):
			print(f"     * {i:2}: {MaxChanges[i]}")
			if MaxChanges[i] != 0:
				self.RegistersToPlay = i

	#
	# Insert markers for repeating value (used to quickly avoid to program a register)
	#
	def PrecaclDeltaPlay(self, RegId, MarkerValue):
		Register = self.YmFile.Registers[RegId]
		InitVal = Register[-1]
		PrevVal = InitVal
		Count = 0
		for f in range(0, len(Register)):
			DeltaPlay = True
			if Register[f] != PrevVal:
				DeltaPlay = False
			# Special case for 1st mixer and volume values. Avoid a delta-play since the mixer and volume are forced to mute in init values.
			if f == 0 and RegId >= 7 and RegId <= 10:
				DeltaPlay = False
			# Special case for a non 0 loop frame. The current value must also be equal to the one in last frame to enable delta-play.
			if self.YmFile.LoopFrame != 0 and f == self.YmFile.LoopFrame and Register[f] != InitVal:
				DeltaPlay = False
			if DeltaPlay:
				Register[f] = MarkerValue
				Count = Count + 1
			else:
				PrevVal = Register[f]
		print(f"     * R{RegId}: {round(100 * Count/len(Register), 1)}%")

	def BackupInitValue(self):
		self.InitVal = {}
		for i in range (NR_YM_REGISTERS):
			self.InitVal[i] = self.YmFile.Registers[i][0]
		self.InitVal[7] = 0x3F
		self.InitVal[8] = 0
		self.InitVal[9] = 0
		self.InitVal[10] = 0

	#
	# Convert the given YM file to the Hicks format
	#
	def Convert(self, YmFile):
		self.YmFile = YmFile
		self.R = {}
		self.RLoop = {}

		print("\nPreprocessing data:")

		self.BackupInitValue()

		print(f"  - Smooth registers R0 to R5")
		self.SmoothRegisters(self.YmFile.Registers[0], self.YmFile.Registers[1], self.YmFile.Registers[8], self.YmFile.Registers[7], 1)
		self.SmoothRegisters(self.YmFile.Registers[2], self.YmFile.Registers[3], self.YmFile.Registers[9], self.YmFile.Registers[7], 2)
		self.SmoothRegisters(self.YmFile.Registers[4], self.YmFile.Registers[5], self.YmFile.Registers[10], self.YmFile.Registers[7], 3)

		self.FixPeriodLow(self.YmFile.Registers[0])
		self.FixPeriodLow(self.YmFile.Registers[2])
		self.FixPeriodLow(self.YmFile.Registers[4])
		self.FixPeriodLow(self.YmFile.Registers[11])

		self.SmoothNoise(self.YmFile.Registers[6], self.YmFile.Registers[7])

		self.CountConstantReg()

		print(f"  - Merge registers 1+3")
		self.MergeRegisters(self.YmFile.Registers[1], self.YmFile.Registers[3])
		print(f"  - Merge registers 5+13")
		self.MergeRegisters(self.YmFile.Registers[5], self.YmFile.Registers[13])
		print(f"  - Preprocess delta-play (delta-play percentage)")
		self.PrecaclDeltaPlay(0, 0x01)
		self.PrecaclDeltaPlay(2, 0x01)
		self.PrecaclDeltaPlay(4, 0x01)
		self.PrecaclDeltaPlay(6, 0x80)
		self.PrecaclDeltaPlay(7, 0xF4)
		self.PrecaclDeltaPlay(8, 0xF4)
		self.PrecaclDeltaPlay(9, 0xF4)
		self.PrecaclDeltaPlay(10, 0xF4)
		self.PrecaclDeltaPlay(11, 0x01)

		print(f"  - Adjust R6 register for R13 no reset case")
		self.AdjustR6ForR5(self.YmFile.Registers[6], self.YmFile.Registers[5])
		self.AdjustR6ForR13(self.YmFile.Registers[6], self.YmFile.Registers[13])

		self.CountAndLimitRegChanges()

		print("\nCrunching:")

		NrRegisters = len(self.RegOrder)
		for r in range(NrRegisters):
			MinAvg = 1000
			MaxAvg = 0
			if self.RegOrder[r] == 1:
				print(f"  - Crunch register 1+3: ", end='', flush=True)
			elif self.RegOrder[r] == 5:
				print(f"  - Crunch register 5+13: ", end='', flush=True)
			else:
				print(f"  - Crunch register {self.RegOrder[r]}: ", end='', flush=True)

			if self.RegOrder[r] == 12 and self.R12IsConst:
				self.R[r] = []
			elif self.YmFile.LoopFrame != 0:
				RegisterData = self.YmFile.Registers[self.RegOrder[r]][0:self.YmFile.LoopFrame]
				self.R[r], Stats = self.Compressor.compress(RegisterData, False)
				MinAvg = Stats.MinAvg
				MaxAvg = Stats.MaxAvg
				self.RLoop[r] = len(self.R[r])
				RegisterData = self.YmFile.Registers[self.RegOrder[r]][self.YmFile.LoopFrame:]
				Remain, Stats = self.Compressor.compress(RegisterData, True)
				self.R[r] = self.R[r] + Remain
			else:
				RegisterData = self.YmFile.Registers[self.RegOrder[r]]
				self.R[r], Stats = self.Compressor.compress(RegisterData, True)
				self.RLoop[r] = 0
			print(f"{len(self.YmFile.Registers[self.RegOrder[r]])} -> {len(self.R[r])} Decrunch ratio (min/max) {min(MinAvg, Stats.MinAvg)} / {max(MaxAvg, Stats.MaxAvg)}")

	#
	# Write the file
	#
	def Write(self):
		with open(self.FileName, "wb") as fd:
			# Write "SkipR12" flag
			fd.write(self.R12IsConst.to_bytes(1,"little"))

			# The player behaves badly if R12 is not constant. Hopefully, this is a very uncommon case.
			# However, in this case, we have to take a large secutiry gap to reach a sufficient decrunch ratio :(
			if not self.R12IsConst:
				self.RegistersToPlay = self.RegistersToPlay + 3

			# Write number of registers to play
			fd.write(self.RegistersToPlay.to_bytes(1,"little"))

			# Write: initial values for each register
			for i in range(NR_YM_REGISTERS):
				fd.write(self.InitVal[i].to_bytes(1,"little"))

			# Write: address of buffers for each register
			BufferOffset = {}
			BufferOffset[0] = 2 + NR_YM_REGISTERS + 2 * len(self.RegOrder)
			for i in range(len(self.RegOrder)):
				fd.write(BufferOffset[i].to_bytes(2,"little"))
				BufferOffset[i+1] = BufferOffset[i] + len(self.R[i]) + 3

			# Write: register data + loop marker + start address of register data in memory
			LoopMarker=0x1F
			for i in range(len(self.RegOrder)):
				RegisterData = self.YmFile.Registers[self.RegOrder[i]]
				if len(self.R[i]) != 0:
					fd.write(self.R[i])
					fd.write(LoopMarker.to_bytes(1,"little"))
					fd.write((BufferOffset[i]+self.RLoop[i]).to_bytes(2,"little"))

				
###################################################################################
#
# Entry point
#
###################################################################################

if __name__ == "__main__":
#	try:
		if len(sys.argv) != 3:
			raise Exception(f"Invalid number of arguments.\nUsage: {os.path.basename(sys.argv[0])} <Source YM file> <Destination Hicks file>")
        	
		Song = YmReader(sys.argv[1])
		Song.Import()

		Convertor = HicksConvertor(sys.argv[2])
		Convertor.Convert(Song)
		Convertor.Write()

#	except Exception as ErrorMsg:
#		sys.exit(f"Error: {ErrorMsg}")
