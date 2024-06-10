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
	def compress(self, Data, LoopStart):
		i = 0
		Literal=b''
		Crunch=b''
		if LoopStart:
			PrevLen1 = PrevLen2 = 1
		else:
			PrevLen1 = PrevLen2 = -1

		while i < len(Data):
			Match = self.FindLongestMatch(Data, i)

			if Match:
				#
				# This is a pure heuristic optimization which limits the bad impact of the "4 tokens constaint"
				#
				MatchDistance, MatchLength = Match
				if Literal and len(Literal) + MatchLength < 6:
					Match = False
				elif PrevLen2 + MatchLength < 6:
					Match = False

			if Match:
				#
				# Here is the "4 tokens constaint": we make sure that we can always decrunch enough bytes with 4 tokens.
				# We assume the worth case scenario where the 1st token is a decrunch restart producing only 1 byte.
				MatchDistance, MatchLength = Match
				Remain = len(Data) - i - MatchLength

				if Literal and (PrevLen2 >= 0) and (1 + PrevLen2 + len(Literal) + MatchLength < self.SlotLength):
					Match = False
				if Literal and (PrevLen1 >= 0) and (1 + PrevLen1 + PrevLen2 + len(Literal) < self.SlotLength):
					Match = False
				if not Literal and (PrevLen1 >= 0) and (1 + PrevLen1 + PrevLen2 + MatchLength < self.SlotLength):
					Match = False

				# Special case for ending bytes
				# We can face an even worth case scenario:
				#   Token 1: Decrunch restart producing 1 byte
				#   Token 4: A frame loop producing 1 byte
				# Scenario #2
				#   Token 1: Decrunch restart producing 1 byte
				#   Token 3: A frame loop producing 1 byte
				if Match and Remain != 0 and Remain < self.SlotLength - 2:
					MissingBytes = self.SlotLength - 2 - Remain
					MatchLength = MatchLength - MissingBytes
					if (MatchLength < 3):
						Match = False
					else:
						Match = MatchDistance, MatchLength

			if Match:
				MatchDistance, MatchLength = Match
				if Literal:
					PrevLen1 = PrevLen2
					PrevLen2 = len(Literal)
					Crunch = self.EncodeLiteral(Crunch, Literal)
					Literal = b''

				Crunch = self.EncodeMatch(Crunch, MatchDistance, MatchLength)

				PrevLen1 = PrevLen2
				PrevLen2 = MatchLength

				i += MatchLength
			else:
				Literal = Literal + Data[i:i+1]
				if len(Literal) == self.LitMaxSize:
					Crunch = self.EncodeLiteral(Crunch, Literal)
					Literal = b''
					PrevLen1 = -1
					PrevLen2 = -1
				i += 1

		if Literal:
			Crunch = self.EncodeLiteral(Crunch, Literal)
			PrevLen1 = PrevLen2
			PrevLen2 = len(Literal)

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
#			         0, 2, (1+3), 4, (5+13), 6, 8, 9, 10, 11, 12, 7]
		self.RegOrder = [0, 2, 1,     4, 5,      6, 7, 8, 9, 10, 11, 12]

	def MergeRegisters(self, R1, R2):
		for i in range (len(R1)):
			R1[i] = (R2[i] & 0x0f) << 4 | (R1[i] & 0x0f)

	def AdjustR6ForR13(self, R7, R13):
		for i in range (len(R7)):
			if R13[i] == 0xFF:
				R7[i] = R7[i] | 0x80
				R13[i] = R13[i-1]				# V2 optimisation

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
				if PeriodLow[i] != PeriodLow[i-1]:
					PeriodLow[i] = PeriodLow[i-1]		# V5 optimisation
				if PeriodHigh[i] != PeriodHigh[i-1]:
					PeriodHigh[i] = PeriodHigh[i-1]

			# Smooth volume if tone is off
			# In this case, volume is not used by the PSG.
			if ToneOff and Volume[i] != Volume[i-1]:
				Volume[i] = VolMode | PrevVol			# V4 optimization

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
				Noise[i] = Noise[i-1]				# V3 optimization

	#
	# Count the number of constant registers
	#
	def CountConstantReg(self):
		ConstRegTxt = ""
		for r in range(14):
			Constant = True
			for f in range(len(self.YmFile.Registers[r])):
				if self.YmFile.Registers[r][f] != self.YmFile.Registers[r][0]:
					Constant = False
			if Constant:
				if ConstRegTxt == "":
					ConstRegTxt = ConstRegTxt + f"R{r}"
				else:
					ConstRegTxt = ConstRegTxt + f", R{r}"

		if ConstRegTxt == "":
			ConstRegTxt = "None"

		print(f"  - Constant registers:", ConstRegTxt)

	#
	# Insert markers for repeating value (used to quickly avoid to program a register)
	#
	def PrecaclNoReprog(self, RegId, MarkerValue):
		Register = self.YmFile.Registers[RegId]
		PrevVal = Register[0] 
		Count = 0
		for r in range(1, len(Register)):
			if (Register[r] == PrevVal):
				Register[r] = MarkerValue
				Count = Count + 1
			else:
				PrevVal = Register[r] 
		print(f"  - Pre-calc delta-play for register {RegId}: {round(100 * Count/len(Register), 1)}%")

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
		print(f"  - Adjust R6 register for R13 no reset case")
		self.AdjustR6ForR13(self.YmFile.Registers[6], self.YmFile.Registers[13])

		self.PrecaclNoReprog(0, 0x01)
		self.PrecaclNoReprog(2, 0x01)
		self.PrecaclNoReprog(4, 0x01)
		self.PrecaclNoReprog(6, 0xF4)
		self.PrecaclNoReprog(7, 0xF4)
		self.PrecaclNoReprog(8, 0xF4)
		self.PrecaclNoReprog(9, 0xF4)
		self.PrecaclNoReprog(10, 0xF4)
		self.PrecaclNoReprog(11, 0x01)

		NrRegisters = len(self.RegOrder)
		self.Compressor.SlotLength = NrRegisters
		for r in range(NrRegisters):
			if self.RegOrder[r] == 1:
				print(f"  - Crunch register 1+3: ", end='', flush=True)
			elif self.RegOrder[r] == 5:
				print(f"  - Crunch register 5+13: ", end='', flush=True)
			else:
				print(f"  - Crunch register {self.RegOrder[r]}: ", end='', flush=True)
			if self.YmFile.LoopFrame != 0:
				RegisterData = self.YmFile.Registers[self.RegOrder[r]][0:self.YmFile.LoopFrame]
				self.R[r] = self.Compressor.compress(RegisterData, False)
				self.RLoop[r] = len(self.R[r])

				RegisterData = self.YmFile.Registers[self.RegOrder[r]][self.YmFile.LoopFrame:-1]
				self.R[r] = self.R[r] + self.Compressor.compress(RegisterData, True)

			else:
				RegisterData = self.YmFile.Registers[self.RegOrder[r]][0:-1]
				self.R[r] = self.Compressor.compress(RegisterData, True)
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
				BufferAddr[i+1] = BufferAddr[i] + len(self.R[i]) + 4
			
			LoopMarker=0x1F
			for i in range(len(self.RegOrder)):
				RegisterData = self.YmFile.Registers[self.RegOrder[i]]
				fd.write(self.R[i])
				fd.write(LoopMarker.to_bytes(1,"little"))
				fd.write(RegisterData[-1].to_bytes(1,"little"))
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
		Convertor.Write(0x3800)

#	except Exception as ErrorMsg:
#		sys.exit(f"Error: {ErrorMsg}")
