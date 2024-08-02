#include <cstring>
#include <algorithm>

#include "Lzss.h"

Lzss::Lzss(int _windowSize, int _litMaxSize)
{
	windowSize = _windowSize;
	litMaxSize = _litMaxSize;
	matchMaxSize = 256 - _litMaxSize + 1;
	offsetLen = 2;

	srcData = nullptr;
	dstData = nullptr;
	srcLen = 0;
	dstLen = 0;
}

void Lzss::PushData(uint8_t data)
{
	dstData[dstLen++] = data;
}

void Lzss::PushData(uint8_t* data, int len)
{
	memcpy(&dstData[dstLen], data, len);
	dstLen += len;
}

//
// Encode a Literal to the crunch Buffer
//
void Lzss::EncodeLiteral(int start, int len)
{
	printf("L: %d\n", len);
	// Write Literal length
	PushData(len - 1);

	// Write Literals
	PushData(&srcData[start], len);
}

//
// Encode a match to the crunch Buffer
//
void Lzss::EncodeMatch(int distance, int len)
{
	printf("L: %d %d\n", distance, len);

	// Write copy Length
	PushData(len + 0x1D);

	// Write offset
	PushData(distance - 1);
}

bool Lzss::GetWrappedSlice(int windowStart, int windowEnd, int candidateStart, int candidateEnd)
{
	int candidateLen = candidateEnd - candidateStart;
	int windowLen = windowEnd - windowStart;
	int Repetitions = candidateLen / windowLen;
	int Remainder = candidateLen % windowLen;
	uint8_t* candidate = &srcData[candidateStart];

	for (int r = 0; r < Repetitions; r++)
	{
		uint8_t* window = &srcData[windowStart];

		for (int i = 0; i < windowLen; i++)
		{
			if (*candidate != *window)
				return false;
			candidate++;
			window++;
		}
	}

	uint8_t* window = &srcData[windowStart];

	for (int i = 0; i < Remainder; i++)
	{
		if (*candidate != *window)
			return false;
		candidate++;
		window++;
	}

	return true;
}

bool Lzss::FindLongestMatch(int& matchDistance, int& matchLen, int curPos)
{
	int endOfBuffer = std::min(curPos + matchMaxSize, srcLen);
	int searchStart = std::max(0, curPos - windowSize);

	int matchCandidateStart = curPos;

	for (int matchCandidateEnd = endOfBuffer; matchCandidateEnd > curPos + offsetLen; matchCandidateEnd--)
	{
		for (int searchPos = searchStart; searchPos < curPos; searchPos++)
		{
			if (GetWrappedSlice(searchPos, curPos, matchCandidateStart, matchCandidateEnd))
			{
				matchDistance = curPos - searchPos;
				matchLen = matchCandidateEnd - matchCandidateStart;
				return true;
			}
		}
	}

	return false;
}

void Lzss::LoadData(uint8_t* inData, int dataLen)
{
	if (dstData)
	{
		delete[] dstData;
	}

	srcData = inData;
	srcLen = dataLen;
	dstLen = 0;
	dstData = new uint8_t[dataLen];
}

void Lzss::ReloadData(uint8_t* inData, int dataLen)
{
	srcData = inData;
	srcLen = dataLen;
}

int Lzss::Crunch(bool loopStart)
{
	int pos = 0;
	int literalLen = 0;
	int crunchLen = 0;
	int minDecrunchRatio = 2;
	int prevLen1, prevLen2;
	int matchDistance, matchLen;

	if (srcData == nullptr)
	{
		return 0;
	}

	if (loopStart)
		prevLen1 = prevLen2 = 1;
	else
		prevLen1 = prevLen2 = srcLen - 1;

	while (pos + literalLen < srcLen)
	{
		bool match = FindLongestMatch(matchDistance, matchLen, pos + literalLen);
		//		if (match)
		//			printf("%d: %d:%d\n", pos + literalLen, matchDistance, matchLen);
		//		else
		//			printf("%d: -\n", pos + literalLen);

		//
		// Make sure that 2 following tokens decrunch at least X values
		//
		if (match)
		{
			if ((literalLen > 0) && (literalLen + matchLen < minDecrunchRatio))
				match = false;
			else if (prevLen2 + matchLen < minDecrunchRatio)
				match = false;
		}

		if (match)
		{
			if (literalLen > 0)
			{
				prevLen1 = prevLen2;
				prevLen2 = literalLen;
				EncodeLiteral(pos, literalLen);
			}

			EncodeMatch(matchDistance, matchLen);

			prevLen1 = prevLen2;
			prevLen2 = matchLen;
			pos += literalLen + matchLen;
			literalLen = 0;
		}
		else
		{
			literalLen++;
			if (literalLen == litMaxSize)
			{
				EncodeLiteral(pos, literalLen);
				pos += literalLen;
				literalLen = 0;
				prevLen1 = -1;
				prevLen2 = -1;
			}
		}
	}

	if (literalLen > 0)
	{
		EncodeLiteral(pos, literalLen);
	}

	printf("\nCrunch: ");
	for (int i = 0; i < 10; i++)
		printf("%02x ", dstData[i]);
	printf("\n");

	return dstLen;
}
