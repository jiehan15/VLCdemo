/*
 * axiiic.h
 *
 *  Created on: 2022 July 27
 *      Author: hanji
 */

#ifndef SRC_AXIIIC_H_
#define SRC_AXIIIC_H_

#include <stdio.h>
#include "xil_printf.h"
#include "xparameters.h"
#include "xil_io.h"
#include "sleep.h"

#define GIE 			0x01c
#define ISR 			0x020
#define IER				0x028
#define SOFTR			0x040
#define CR				0x100
#define SR				0x104
#define TX_FIFO			0x108
#define RX_FIFO			0x10c
#define ADR				0x110
#define TX_FIFO_OCY		0x114
#define RX_FIFO_OCY		0x118
#define TEN_ADR			0x11c
#define RX_FIFO_PIRQ	0x120
#define GPO				0x124

#define IIC_Device_ID   0x50
#define SRMASK 			0xc4

#define ADAUADDR 0x38

// change the following two corresponding AXI IIC address
#define ADAUIICADDR XPAR_AXI_IIC_0_BASEADDR
#define TOUCHIICADDR XPAR_LCDCTRL_AXI_IIC_0_BASEADDR

void Initialization_IIC(u32 BASEADDR);
int Single_Byte_Write(u32 BASEADDR, u8 Device_ID, u8 high_8bit_Address,u8 low_8bit_Address,u8 data);
u8 Single_Byte_Read(u32 BASEADDR, u8 Device_ID, u8 high_8bit_Address,u8 low_8bit_Address);

int ADAU1761Init();
int Touch_Init();

// -----------------------------------------------------------------------------
// Implementation
int ADAU1761Init(){
	Initialization_IIC(ADAUIICADDR);

	// write value to regs
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0x00, (u8)0x01);
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0x15, (u8)0x00);
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0x16, (u8)0x00);
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0x1c, (u8)0x21);
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0x1d, (u8)0x41);
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0x23, (u8)((0x36<<2) | 0b11));
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0x24, (u8)((0x36<<2) | 0b11));
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0x2a, (u8)0x03);
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0xf2, (u8)0x01);
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0xf9, (u8)0x7f);
	Single_Byte_Write(ADAUIICADDR, ADAUADDR, (u8)0x40, (u8)0xfa, (u8)0x01);

	return 1;
}

int Touch_Init(){
	Initialization_IIC(TOUCHIICADDR);
	// wait 100ms
	usleep(100000);

	u8 data;
	data = Single_Byte_Read(TOUCHIICADDR, 0x14, 0x81, 0x4e);
	if(data == 0x0){
		data = Single_Byte_Read(TOUCHIICADDR, 0x14, 0x80, 0x44);
		switch(data){
			case 0x0:
				break;
			case 0x1:
				break;
			case 0x3:
				break;
			case 0xff:
				break;
			default:
				break;
		}
	} else {
		Single_Byte_Write(TOUCHIICADDR, 0x14, 0x81, 0x4e, 0x00);
		usleep(100000);
	}

	return 0;
}

/**********************************************************************************************/
//	Initialization
//		1.Set the RX_FIFO depth to maximum by setting RX_FIFO_PIRQ = 0x _ _
//		2.Reset the TX_FIFO with 0x_ _
//		3.Enable the AXI IIC, remove the TX_FIFO reset, and disable the general call
// 100KHz -> 0.1ms for each bytes, 100us
void Initialization_IIC(u32 BASEADDR) {
	// soft reset the AXI IIC ip
	Xil_Out32(BASEADDR + SOFTR, 0xa);

	// Set the RX_FIFO depth to 16 locations
	Xil_Out32(BASEADDR + RX_FIFO_PIRQ, 0x0000000f);
	// Reset the TX_FIFO
	Xil_Out32(BASEADDR + CR, Xil_In32(BASEADDR + CR)|0x00000002);
	// Enable the AXI IIC (hence), reset the tx fifo
	Xil_Out32(BASEADDR + CR, Xil_In32(BASEADDR + CR)|0x00000001);
	// Remove the TX_FIFO reset
	Xil_Out32(BASEADDR + CR, Xil_In32(BASEADDR + CR)&0xfffffffd);
	// Disable the general call
	Xil_Out32(BASEADDR + CR, Xil_In32(BASEADDR + CR)&0xffffffbf);
}

// 100KHz -> 0.1ms for each bytes, 100us
int Single_Byte_Write(u32 BASEADDR, u8 Device_ID, u8 high_8bit_Address,u8 low_8bit_Address,u8 data){
	// wait both fifo to be empty
	while( (Xil_In32(BASEADDR + SR) & SRMASK) != 0xc0) {}

	// Write 0x___ to the TX_FIFO (set the start bit, the device address, write access)
	// and enable the dynamic logic
	Xil_Out32(BASEADDR + TX_FIFO, (Device_ID<<1)|0x100);
	// Write 0x__ to the TX_FIFO (slave address for data)
	Xil_Out32(BASEADDR + TX_FIFO, high_8bit_Address);
	// Write 0x__ to the TX_FIFO (slave address for data)
	Xil_Out32(BASEADDR + TX_FIFO, low_8bit_Address);
	// Write 0x__ to the TX_FIFO (stop bit, byte 1)
	// and disable the dynamic logic
	Xil_Out32(BASEADDR + TX_FIFO, data|0x200);
	usleep(500);
	// return the number of bytes write to the AXI IIC Tx FIFO
	return 4;
}

/**********************************************************************************************/
//	Read Bytes from an IIC Device Addressed as 0x_ _
//		1.Check that all FIFOs are empty and that the bus is not busy by reading the Status register
//		2.Write 0x___ to the TX_FIFO (set the start bit, the device address, write access)
//		3.Write 0x__ to the TX_FIFO (slave address for data)
//		4.Write 0x__ to the TX_FIFO (slave address for data)
//		5.Write 0x___ to the TX_FIFO (set start bit, device address to 0x__, read access)
//		6.Write 0x___ to the TX_FIFO (set stop bit, four bytes to be received by the AXI IIC)
//		7.Wait until the RX_FIFO is not empty.
//	a) Read the RX_FIFO byte.
//	b) If the last byte is read, then exit; otherwise, continue checking while RX_FIFO is not empty.
//  Parameter:
//		Device_ID:0x01010,A2,A1,A0
//		high_8bit_Address:first word address
//		low_8bit_Address:second word address
//		data:8bit send data
//	Return:
//		8bit Recevived data.
u8 Single_Byte_Read(u32 BASEADDR, u8 Device_ID, u8 high_8bit_Address,u8 low_8bit_Address){
	u8 readbyte;
	//Check that all FIFOs are empty and that the bus is not busy by reading the Status register
	while( (Xil_In32(BASEADDR + SR) & SRMASK) != 0xc0) {}

	// Write 0x___ to the TX_FIFO (set the start bit, the device address, write access)
	Xil_Out32(BASEADDR + TX_FIFO, (Device_ID<<1) | 0x100);
	// Write 0x__ to the TX_FIFO (slave address for data)
	Xil_Out32(BASEADDR + TX_FIFO, high_8bit_Address);
	// Write 0x__ to the TX_FIFO (stop bit, slave address for data)
	Xil_Out32(BASEADDR + TX_FIFO, low_8bit_Address | 0x200);
	usleep(400);
	//Write 0x___ to the TX_FIFO (set start bit, device address to 0x__, read access)
	Xil_Out32(BASEADDR + TX_FIFO, (Device_ID<<1) | 0x101);
	//Write 0x___ to the TX_FIFO (set stop bit, the bytes count needed to read from the bus)
	Xil_Out32(BASEADDR + TX_FIFO, 0x1 | 0x200);

	// Wait until the RX_FIFO is not empty.
	while((Xil_In32(BASEADDR + SR) & 0x00000040) == 0x00000040) {}

	readbyte = Xil_In32(BASEADDR + RX_FIFO);
	return readbyte;
}

#endif /* SRC_AXIIIC_H_ */
