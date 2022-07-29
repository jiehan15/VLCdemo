
#ifndef SRC_VLC_H_
#define SRC_VLC_H_

#include "xil_types.h"
#include "axiiic.h"

typedef struct VlcCommand {
	u8 operation;
	u8 FILEid;
	u32 FILEptr;
	u16 Reqlen;
} VlcCommand;

// file operations
#define OPENFILEMUSIC (u8)0x1
#define OPENSUCCMUSIC (u8)0x2
#define OPENFAILMUSIC (u8)0x4

#define PAUSEMUSIC (u8)0x9
#define PLAYMUSIC (u8)0xa
#define STOPMUSIC (u8)0xb

#define CHANGEVOL (u8)0xff

// interrupt
#define FIFO_BASEADDR XPAR_AXI_FIFO_0_BASEADDR
#define RXNOTEMPTY         	61
#define RXOVERRUN         	62
#define RXTOUT            	63
#define TOUCH_INT           	64

#define INT_TYPE_RISING_EDGE    0x03
#define INT_TYPE_HIGHLEVEL      0x01
#define INT_TYPE_MASK           0x03
#define INT_CFG0_OFFSET 0x00000C00

#define FIFO_WriteReg(BaseAddr, offset, value) \
	Xil_Out32(BaseAddr+offset, value)

#define FIFO_ReadReg(BaseAddr, offset) \
	Xil_In32(BaseAddr+offset)

int convertCMD(u8* receivedStream, VlcCommand* vcmd);
u8 checksumCal(u8 op, u8 FileID, u32 FilePtr, u16 ReqLen);
char* findFilenameByID(u8 FileID);
void sendCMD(u8 op, u8 FileID, u32 FilePtr, u16 ReqLen);
void changeVolume(u8 vol);

static char* FILENAME1 = "Hello\0";
static char* FILENAME2 = "LoveInTheDark\0";
static char* FILENAME3 = "EasyOnMe\0";
static char* FILENAME4 = "Teeth\0";
static char* FILENAME5 = "PlasticLove\0";

// implementation

// ---------------------------------------------------
// This function take the received bit stream and convert
// it to the vlc system command;
// @param:
// u8* receivedStream: 9 Byte received command,
//  MSB {0xff, (u8)FILEid, (u32)FILEptr, (u16)Reqlen, (u8), checksum} LSB
// @return:
// VlcCommand* vcmd: pointer to vlc command
// 1: if the data is valid;
// 0: if the data failed check;
int convertCMD(u8* receivedStream, VlcCommand* vcmd){

	// received results
	u8 Operation = receivedStream[1];
	u8 FildId = receivedStream[2];
	u32 FilePtr = (receivedStream[6]<<24) + (receivedStream[5]<<16) +
			(receivedStream[4]<<8) + receivedStream[3];
	u16 ReqLen = (receivedStream[8]<<8) + receivedStream[7];
	u8 Checksum = receivedStream[9];

	// calculate checksum
	if(checksumCal(Operation, FildId, FilePtr, ReqLen) == Checksum){
		vcmd->operation = Operation;
		vcmd->FILEid = FildId;
		vcmd->FILEptr = FilePtr;
		vcmd->Reqlen = ReqLen;
		return 1;
	}

	return 0;
}

// calculate checkcum
// @return:
// u8 checksum
u8 checksumCal(u8 op, u8 FileID, u32 FilePtr, u16 ReqLen){
	u32 checksum = 0x0;

	checksum += op;
	checksum += FileID;
	checksum += FilePtr;
	checksum += ReqLen;

	checksum = (checksum>>24) ^ (checksum>>16) ^
			(checksum>>8) ^ (checksum);

	return ((u8)checksum);
}

char* findFilenameByID(u8 FileID){
	switch(FileID){
		case 0x0:
			return FILENAME1;
			break;
		case 0x1:
			return FILENAME2;
			break;
		case 0x2:
			return FILENAME3;
			break;
		case 0x3:
			return FILENAME4;
			break;
		case 0x4:
			return FILENAME5;
			break;
		default:
			return NULL;
	}
}

// send the specified data to the RX side
void sendCMD(u8 op, u8 FileID, u32 FilePtr, u16 ReqLen){
	u8 checksum = checksumCal(op, FileID, FilePtr, ReqLen);

	// start byte
	FIFO_WriteReg(FIFO_BASEADDR, 0x0, 0xff);
	// opreation
	FIFO_WriteReg(FIFO_BASEADDR, 0x0, op);
	// file id
	FIFO_WriteReg(FIFO_BASEADDR, 0x0, FileID);
	// file ptr or File length
	FIFO_WriteReg(FIFO_BASEADDR, 0x0, FilePtr);
	FIFO_WriteReg(FIFO_BASEADDR, 0x0, (FilePtr>>8));
	FIFO_WriteReg(FIFO_BASEADDR, 0x0, (FilePtr>>16));
	FIFO_WriteReg(FIFO_BASEADDR, 0x0, (FilePtr>>24));
	// request len
	FIFO_WriteReg(FIFO_BASEADDR, 0x0, ReqLen);
	FIFO_WriteReg(FIFO_BASEADDR, 0x0, (ReqLen>>8));
	// checksum
	FIFO_WriteReg(FIFO_BASEADDR, 0x0, checksum);
}

void changeVolume(u8 vol){
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0x23, (u8)((vol<<2) | 0b11));
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0x24, (u8)((vol<<2) | 0b11));
}

#endif /* SRC_VLC_H_ */
