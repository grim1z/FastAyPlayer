#!/usr/bin/env python3
import io
import os
import sys
import struct
import lhafile

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
	def	LoadSongInfo(self):
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
	def	LoadInterleavedFrames(self):
		RawData = self.fd.read(self.NrRegisters * self.NbFrames)

		Magic = self.fd.read(4)
		Magic = Magic.decode("utf-8")
		
		if	Magic != "End!":
			raise Exception(f"Truncated or malformed file.")

		self.Registers = {}
		
		for r in range(14):
			Frames = b''
			Constant = True
			for f in range(self.NbFrames):
				Frames = Frames + (RawData[r * self.NbFrames + f]).to_bytes(1, "little")
				if Frames[f] != Frames[0]:
					Constant = False
			self.Registers[r] = bytearray(Frames)
			if Constant:
				print(f"Register {r} is constant ({hex(Frames[0])})")

	#
	# Some YM exports can insert zeroes in registers R11/R12/R13 when bit 4 is not set in volume control registers.
	# This could decrease the quality of compression routines.
	#
	def FixHoles(self, R8, R9, R10, R11, R12, R13):
		for i in range (1, len(R8)):
			if ((R8[i] & 0x10) == 0) and ((R9[i] & 0x10) == 0) and ((R10[i] & 0x10) == 0):
				R11[i] = R11[i-1]
				R12[i] = R12[i-1]
				R13[i] = R13[i-1]		# V2 optimisation

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
	def compress(self, Data):
		i = 0
		Literal=b''
		Crunch=b''	
		while i < len(Data):
			Match = self.FindLongestMatch(Data, i)
			if Match:
				MatchDistance, MatchLength = Match
				if Literal:
					Crunch = self.EncodeLiteral(Crunch, Literal)
					Literal = b''

				Crunch = self.EncodeMatch(Crunch, MatchDistance, MatchLength)
				i += MatchLength
			else:
				Literal = Literal + Data[i:i+1]
				if len(Literal) == self.LitMaxSize:
					Crunch = self.EncodeLiteral(Crunch, Literal)
					Literal = b''
				i += 1

		if Literal:
			Crunch = self.EncodeLiteral(Crunch, Literal)

		return Crunch

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
		self.FileName = FileName
		self.Compressor = LzssCompressor(256, 31)
#			         0, 2, (1+3), 4, 6, 8, 9, 10, 11, 12, (5+13), 7]
		self.RegOrder = [0, 2, 1,     4, 6, 8, 9, 10, 11, 12, 5,      7]

	def MergeRegisters(self, R1, R2):
		for i in range (len(R1)):
			R1[i] = (R2[i] & 0x0f) << 4 | (R1[i] & 0x0f)

	def AdjustR7ForR13(self, R7, R13):
		for i in range (len(R7)):
			if R13[i] == 0xFF:
				R7[i] = R7[i] | 0x80
				R13[i] = R13[i-1]				# V2 optimisation

	def SmoothRegisters(self, FreqLow, FreqHigh, Volume, Mixer, Voice):
		VoiceToneMask = 1 << (Voice-1)
		VoiceNoiseMask = VoiceToneMask << 3
		for i in range (1, len(Volume)):
			CurVol = Volume[i] & 0x0F
			PrevVol = Volume[i-1] & 0x0F
			VolMode = Volume[i] & 0x10
			ToneOff = (Mixer[i] & VoiceToneMask) == VoiceToneMask
			NoiseOff = (Mixer[i] & VoiceNoiseMask) == VoiceNoiseMask

#			if CurVol == 0:
#				Mode = 0
#				Tone = 0
#				Noise = 0
#				if VolMode != 0:
#					Mode = 1
#				if not ToneOff:
#					Tone = 1
#				if not NoiseOff:
#					Noise = 1
#				if i < 100:
#					print (f"{Voice}: {i} - Vol {Mode}.{CurVol:02x} - Mix N:{Noise} T:{Tone}")

			# Smooth Frequency if volume is 0 or tone if off.
			if Volume[i] == 0 or ToneOff:
				if FreqLow[i] != FreqLow[i-1]:
					FreqLow[i] = FreqLow[i-1]		# V5 optimisation
				if FreqHigh[i] != FreqHigh[i-1]:
					FreqHigh[i] = FreqHigh[i-1]

#			# Smooth volume if tone is off
#			# In this case, volume is not used by the PSG.
			if ToneOff and Volume[i] != Volume[i-1]:
				Volume[i] = VolMode | PrevVol			# V4 optimization


	#
	# Smooth noise register when noise is off on every channels
	#
	def SmoothNoise(self, Noise, Mixer):

		for i in range (1, len(Noise)):
			NoiseOff = (Mixer[i] & 0b00111000) == 0b00111000
			if NoiseOff:
				Noise[i] = Noise[i-1]				# V3 optimization

	#
	# Convert the given YM file to the Hicks format
	#
	def Convert(self, YmFile):
		self.YmFile = YmFile
		self.ConstantRegisters = 0
		self.R = {}
		self.RLoop = {}
		
		print("\nCrunching:")

		print(f"  - Smooth registers R0 to R5")
		self.SmoothRegisters(self.YmFile.Registers[0], self.YmFile.Registers[1], self.YmFile.Registers[8], self.YmFile.Registers[7], 1)
		self.SmoothRegisters(self.YmFile.Registers[2], self.YmFile.Registers[3], self.YmFile.Registers[9], self.YmFile.Registers[7], 2)
		self.SmoothRegisters(self.YmFile.Registers[4], self.YmFile.Registers[5], self.YmFile.Registers[10], self.YmFile.Registers[7], 3)

#		for i in range(len(self.YmFile.Registers[8])):
#			self.YmFile.Registers[8][i] = 0
#
#		for i in range(len(self.YmFile.Registers[9])):
#			self.YmFile.Registers[9][i] = 0
#
#		for i in range(len(self.YmFile.Registers[10])):
#			self.YmFile.Registers[10][i] = 0

		self.SmoothNoise(self.YmFile.Registers[6], self.YmFile.Registers[7])

		print(f"  - Merge registers 1+3")
		self.MergeRegisters(self.YmFile.Registers[1], self.YmFile.Registers[3])
		print(f"  - Merge registers 5+13")
		self.MergeRegisters(self.YmFile.Registers[5], self.YmFile.Registers[13])
		print(f"  - Adjust R7 register for R13 no reset case")
		self.AdjustR7ForR13(self.YmFile.Registers[7], self.YmFile.Registers[13])

#		for r in range(12):
#			Constant = True
#			for f in range(len(self.YmFile.Registers[r])):
#				if self.YmFile.Registers[r][f] != self.YmFile.Registers[r][0]:
#					Constant = False
#			if Constant:
#				print(f"Register {r} is constant ({hex(self.YmFile.Registers[r][0])})")

		for r in range(len(self.RegOrder)):
			if self.RegOrder[r] == 1:
				print(f"  - Crunch register 1+3: ", end='', flush=True)
			elif self.RegOrder[r] == 5:
				print(f"  - Crunch register 5+13: ", end='', flush=True)
			else:
				print(f"  - Crunch register {self.RegOrder[r]}: ", end='', flush=True)
			if self.YmFile.LoopFrame != 0:
				self.R[r] = self.Compressor.compress(self.YmFile.Registers[self.RegOrder[r]][0:self.YmFile.LoopFrame])
				self.RLoop[r] = len(self.R[r])

				self.R[r] = self.R[r] + self.Compressor.compress(self.YmFile.Registers[self.RegOrder[r]][self.YmFile.LoopFrame:])

			else:
				self.R[r] = self.Compressor.compress(self.YmFile.Registers[self.RegOrder[r]])
				self.RLoop[r] = 0
			print(f"{len(self.YmFile.Registers[self.RegOrder[r]])} -> {len(self.R[r])}")

	#
	# Write the file
	#
	def Write(self, StartAddr):
		
		with open(self.FileName, "wb") as fd:
			fd.write(self.YmFile.NbFrames.to_bytes(2,"little"))
			fd.write(self.ConstantRegisters.to_bytes(1,"little"))

			BufferAddr = {}
			BufferAddr[0] = StartAddr + 3 + 2 * len(self.RegOrder)
			for i in range(len(self.RegOrder)):
				fd.write(BufferAddr[i].to_bytes(2,"little"))
				BufferAddr[i+1] = BufferAddr[i] + len(self.R[i]) + 3
			
			LoopMarker=0x1F
			for i in range(len(self.RegOrder)):
				fd.write(self.R[i])
				fd.write(LoopMarker.to_bytes(1,"little"))
				fd.write((BufferAddr[i]+self.RLoop[i]).to_bytes(2,"little"))

				
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
		Convertor.Write(0x5000)
		
#	except Exception as ErrorMsg:
#		sys.exit(f"Error: {ErrorMsg}")
