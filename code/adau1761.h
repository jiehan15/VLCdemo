/*
 * adau1761.h
 *
 *  Created on: 2022Äê7ÔÂ6ÈÕ
 *      Author: hanji
 */

#ifndef SRC_ADAU1761_H_
#define SRC_ADAU1761_H_


#include "xparameters.h"
#include "xil_io.h"
#include "sleep.h"

#define DEVICEID (u8)0x38

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

int Initialization_IIC();
void Single_Byte_Write(u8 Device_ID, u8 high_8bit_Address,u8 low_8bit_Address,u8 data);
u8 Single_Byte_Read(u8 Device_ID, u8 high_8bit_Address,u8 low_8bit_Address);

int ADAU1761Init();

// Implementation
int ADAU1761Init(){
	Initialization_IIC();

	// write value to regs
	Single_Byte_Write(DEVICEID, (u8)0x40, (u8)0x00, (u8)0x01);
	Single_Byte_Write(DEVICEID, (u8)0x40, (u8)0x15, (u8)0x00);
	Single_Byte_Write(DEVICEID, (u8)0x40, (u8)0x16, (u8)0x00);
	Single_Byte_Write(DEVICEID, (u8)0x40, (u8)0x1c, (u8)0x21);
	Single_Byte_Write(DEVICEID, (u8)0x40, (u8)0x1d, (u8)0x41);
	Single_Byte_Write(DEVICEID, (u8)0x40, (u8)0x23, (u8)((0x36<<2) | 0b11));
	Single_Byte_Write(DEVICEID, (u8)0x40, (u8)0x24, (u8)((0x36<<2) | 0b11));
	Single_Byte_Write(DEVICEID, (u8)0x40, (u8)0x2a, (u8)0x03);
	Single_Byte_Write(DEVICEID, (u8)0x40, (u8)0xf2, (u8)0x01);
	Single_Byte_Write(DEVICEID, (u8)0x40, (u8)0xf9, (u8)0x7f);
	Single_Byte_Write(DEVICEID, (u8)0x40, (u8)0xfa, (u8)0x01);

	return 1;
}

int Initialization_IIC() {
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + SOFTR, 0x0000000a);// softreset
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + RX_FIFO_PIRQ, 0x0000000f);// Set the RX_FIFO depth
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + CR, Xil_In32(XPAR_AXI_IIC_0_BASEADDR + CR)|0x00000002);//Reset the TX_FIFO
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + CR, Xil_In32(XPAR_AXI_IIC_0_BASEADDR + CR)|0x00000001);//Enable the AXI IIC
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + CR, Xil_In32(XPAR_AXI_IIC_0_BASEADDR + CR)&0xfffffffd);//Remove the TX_FIFO reset
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + CR, Xil_In32(XPAR_AXI_IIC_0_BASEADDR + CR)&0xffffffbf);//Disable the general call
	return 1;
}

/**********************************************************************************************/
//	Write Bytes to an IIC Slave Device Addressed as 0x_ _
//	Place the data at slave device address 0x__:
//		1.Check that all FIFOs are empty and that the bus is not busy by reading the SR
//		2.Write 0x___ to the TX_FIFO (set the start bit, the device address, write access)
//		3.Write 0x__ to the TX_FIFO (slave address for data)
//		4.Write 0x__ to the TX_FIFO (byte 1)
//		5.Write 0x__ to the TX_FIFO (byte 2)
//		6.Write 0x__ to the TX_FIFO (stop bit, byte x)
//  Parameter:
//		Device_ID:0b01110,A2,A1,A0
//		high_8bit_Address:first word address
//		low_8bit_Address:second word address
//		data:8bit send data
//	Return:
//		None.

void Single_Byte_Write(u8 Device_ID, u8 high_8bit_Address,u8 low_8bit_Address,u8 data){
	//Check that all FIFOs are empty and that the bus is not busy by reading the SR
	while((Xil_In32(XPAR_AXI_IIC_0_BASEADDR + SR) & 0x000000C4) != 0x000000c0) {}
	//Write 0x___ to the TX_FIFO (set the start bit, the device address, write access)
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + TX_FIFO, (Device_ID<<1)|0x00000100);
	//Write 0x__ to the TX_FIFO (slave address for data)
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + TX_FIFO, high_8bit_Address);
	//Write 0x__ to the TX_FIFO (slave address for data)
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + TX_FIFO, low_8bit_Address);
	//Write 0x__ to the TX_FIFO (stop bit, byte 1)
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + TX_FIFO, data|0x00000200);
	usleep(10000);
}

/**********************************************************************************************/
//	Read Bytes from an IIC Device Addressed as 0x_ _
//		1.Check that all FIFOs are empty and that the bus is not busy by reading the Status register
//		2.Write 0x___ to the TX_FIFO (set the start bit, the device address, write access)
//		3¡£Write 0x__ to the TX_FIFO (slave address for data)
//		4.Write 0x__ to the TX_FIFO (slave address for data)
//		5.Write 0x___ to the TX_FIFO (set start bit, device address to 0x__, read access)
//		6.Write 0x___ to the TX_FIFO (set stop bit, four bytes to be received by the AXI IIC)
//		7.Wait until the RX_FIFO is not empty.
//	a) Read the RX_FIFO byte.
//		Device_ID:0b0111000,A0
//		high_8bit_Address:first word address
//		low_8bit_Address:second word address
//		data:8bit send data
//	Return:
//		8bit Recevived data.

u8 Single_Byte_Read(u8 Device_ID, u8 high_8bit_Address,u8 low_8bit_Address){
	u8 Received_data;

	// Check that all FIFOs are empty and that the bus is not busy by reading the Status register
	while((Xil_In32(XPAR_AXI_IIC_0_BASEADDR + SR) & 0x000000C4) != 0x000000c0) {}
	// Write 0x___ to the TX_FIFO (set the start bit, the device address, write access)
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + TX_FIFO, (Device_ID<<1)|0x00000100);
	// Write 0x__ to the TX_FIFO (slave address for data)
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + TX_FIFO, high_8bit_Address);
	// Write 0x__ to the TX_FIFO (slave address for data)
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + TX_FIFO, low_8bit_Address);
	// Write 0x___ to the TX_FIFO (set start bit, device address to 0x__, read access)
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + TX_FIFO, (Device_ID<<1)|0x00000101);
	// Write 0x___ to the TX_FIFO (set stop bit, four bytes to be received by the AXI IIC)
	Xil_Out32(XPAR_AXI_IIC_0_BASEADDR + TX_FIFO, 0x00000200);
	usleep(1000);

	// Wait until the RX_FIFO is not empty.
	while((Xil_In32(XPAR_AXI_IIC_0_BASEADDR + SR) & 0x00000040) == 0x00000040) {}

	Received_data = Xil_In32(XPAR_AXI_IIC_0_BASEADDR + RX_FIFO);
	return Received_data;
}

#endif /* SRC_ADAU1761_H_ */
