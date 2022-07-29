#include "xparameters.h"
#include "xuartps.h"
#include "xil_printf.h"
#include "xscugic.h"
#include "stdio.h"
#include "stdlib.h"
#include "sleep.h"
#include "string.h"
#include "ff.h"
#include "xsdps.h"
#include "xil_cache.h"
#include "xscutimer.h"
#include "xtmrctr.h"

#include "vlc.h"

// serial device ID
#define UART_DEVICE_ID      XPAR_PS7_UART_1_DEVICE_ID
// interrupt ID
#define INTC_DEVICE_ID      XPAR_PS7_SCUGIC_0_DEVICE_ID
// serial port interrupt id
#define UART_INT_IRQ_ID     XPAR_XUARTPS_1_INTR

// TIMER
#define TIMER_DEVICE_ID 	XPAR_XSCUTIMER_0_DEVICE_ID
#define TIMER_IRPT_INTR 	XPAR_SCUTIMER_INTR

// TIMING_INTERVAL = (MAX_COUNT - TLRx + 2) * AXI_CLOCK_PERIOD
#define MAX_COUNT 		0xffffffff
#define TLRx 			500000
#define RESET_VALUE 	(MAX_COUNT - TLRx + 0x2)

#define SINGLER 80

// interrupt controller driver instance
XScuGic Intc;
// serial port driver instance
XUartPs Uart_Ps;
// timer
XScuTimer Timer;
XTmrCtr tmr;

// data buffer size
#define MAX_LEN 64
u8 rxbuf[MAX_LEN+1] = {0};
u8 rxbufptr;

static XUartPsFormat UartFormat = {
    115200,
    XUARTPS_FORMAT_8_BITS,
    XUARTPS_FORMAT_NO_PARITY,
    XUARTPS_FORMAT_1_STOP_BIT
};

// function declaration
int UartInit(XUartPs *uart_ps);
// interrupt handler
void UartHandler(void *call_back_ref);
void RxOverrunHandler(void *call_back_ref);
void RxToutHandler(void *call_back_ref);
int IntrInit(XScuGic *intc, XScuTimer *timer);
void IntcTypeSetup(XScuGic *InstancePtr, int intId, int intType);

void TimerHandler(void *call_back_ref);

int SDinit();

static FATFS fatfs;
static FIL fil;
static u8 end = 0;

// file buffer
u8 filebuffer1[SINGLER+1];
UINT filereadByte1 = 0;

UINT flen = 0;
UINT ByteSend = 0;

int sendDone = 0;
int pause = 0;

VlcCommand* vlcCMD;

// main function
int main(void){
    int status;

    // initialize the serial port
    status = UartInit(&Uart_Ps);
    if(status == XST_FAILURE){
//        xil_printf("Uart Initialization Failed\r\n");
        return XST_FAILURE;
    }

    // -------------------------------------------------------
    // axi timer
	status = XTmrCtr_Initialize(&tmr, XPAR_AXI_TIMER_0_DEVICE_ID);
	if (status != XST_SUCCESS)
	{
//		xil_printf("AXI TIMER Initialization Failed\r\n");
		return XST_FAILURE;
	}
	status = XTmrCtr_SelfTest(&tmr, 0x0);
	if (status != XST_SUCCESS) {
//		xil_printf("AXI TIMER self-test Initialization Failed\r\n");
		return XST_FAILURE;
	}
	XTmrCtr_SetOptions(&tmr, 0x0,
					XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION);
	XTmrCtr_SetResetValue(&tmr, 0x0, RESET_VALUE);

	// ---------------------------------------------------------
    // interrupt initialization
    status = IntrInit(&Intc, &Timer);
    if(status == XST_FAILURE){
//        xil_printf("Interrupt Initialization Failed\r\n");
        return XST_FAILURE;
    }

    SDinit();
    vlcCMD = (VlcCommand*) malloc(sizeof(VlcCommand));

//    xil_printf("System Initialization Successful!\r\n");

    // main loop
    unsigned int curState = 0x0;
	unsigned int nxtState = curState;

    while (1) {
    	switch(curState){
    		case 0x0:
    			if(rxbufptr >= 10){
    				// if the received word is no error
    				if(convertCMD(rxbuf, vlcCMD)) {
    					if(vlcCMD->operation == OPENFILEMUSIC){
    						char* filename = findFilenameByID(vlcCMD->FILEid);
    						status = f_open(&fil, filename, FA_READ | FA_OPEN_EXISTING);
//    						xil_printf("Open file: %s, Status: %d\r\n", filename, status);
    						flen = fil.obj.objsize;

    						// to next state
    						nxtState = 0x1;
    					}
    				}

    				// reset rx buffer pointer
					rxbufptr = 0;
					ByteSend = 0;
					end = 0;
					pause = 0;
    			}
    			break;

    		// open response to the rx device
    		case 0x1:
    			// send OK to rx device
    			if(status == FR_OK){
    				sendCMD(OPENSUCCMUSIC, vlcCMD->FILEid, fil.obj.objsize, 0x00);
    				nxtState = 0x2;
    			} else {
    				sendCMD(OPENFAILMUSIC, 0x0, 0x0, 0x0);
    				nxtState = 0x0;
    			}
    			usleep(1000);
    			break;

    		// first send
    		case 0x2:
    			nxtState = 0x3;
    			// all the bitrate of the music is 128kbits, therefore,

    			// read file
    			f_read(&fil, filebuffer1, SINGLER, &filereadByte1);

    			sendDone = 0;
    			XTmrCtr_Start(&tmr, 0x0);
    			break;

			// read the next block of data as soon as current frame is send out
			case 0x3:
				// if reach the end of the file
				if(end){
					nxtState = 0x4;
					break;
				}

				if(rxbufptr >= 10){
					// if the received word is no error
					if(convertCMD(rxbuf, vlcCMD)) {
						if(vlcCMD->operation == PAUSEMUSIC){
							XTmrCtr_Stop(&tmr, 0x0);
							pause = 1;
							// to next state
							nxtState = 0x5;
//							xil_printf("PAUSED\r\n");
						}
						else if(vlcCMD->operation == STOPMUSIC){
							XTmrCtr_Stop(&tmr, 0x0);
							// to next state
							nxtState = 0x4;
//							xil_printf("STOP\r\n");
						}
					}
    				// reset rx buffer pointer
					rxbufptr = 0;
				}

				// all the bitrate of the music is 128kbits, therefore,
				// each time, read 60 Bytes every 1/250s
				// read file if current send is done
				if(sendDone && pause==0){
					f_read(&fil, filebuffer1, SINGLER, &filereadByte1);
					sendDone = 0;
				}
				break;

			case 0x5: {
				if(rxbufptr >= 10){
    				// reset rx buffer pointer
					rxbufptr = 0;
					// if the received word is no error
					if(convertCMD(rxbuf, vlcCMD)) {
						if(vlcCMD->operation == PLAYMUSIC){
							pause = 0;
							// to next state
							nxtState = 0x3;
//							xil_printf("PLAY\r\n");
							XTmrCtr_Start(&tmr, 0x0);
						}
						else if(vlcCMD->operation == STOPMUSIC){
							// to next state
							nxtState = 0x4;
//							xil_printf("STOP\r\n");
						}
					}
				}
				break;
			}

    		// wait for the datastream reach the end of the file
    		case 0x4:
//				xil_printf("File length: %u, Byte Send:%u\r\n", flen, ByteSend);
				f_close(&fil);
//				xil_printf("STOP\r\n");
				nxtState = 0x0;
    			break;

    		case 0x8:
    			break;

    		case 0x10:
    			break;

    		default:
    			nxtState = 0x0;
    			break;
    	}

    	curState = nxtState;
    }
    return status;
}

int UartInit(XUartPs *uart_ps){
    int status;
    XUartPs_Config *uart_cfg;

    uart_cfg = XUartPs_LookupConfig(UART_DEVICE_ID);
    if(NULL == uart_cfg) return XST_FAILURE;

    status = XUartPs_CfgInitialize(uart_ps, uart_cfg, uart_cfg->BaseAddress);
    if(status != XST_SUCCESS) return XST_FAILURE;

    // UART self test
    status = XUartPs_SelfTest(uart_ps);
    if(status != XST_SUCCESS) return XST_FAILURE;

    XUartPs_SetOperMode(uart_ps, XUARTPS_OPER_MODE_NORMAL);
    XUartPs_SetDataFormat(uart_ps, &UartFormat);

    return XST_SUCCESS;
};

void IntcTypeSetup(XScuGic *InstancePtr, int intId, int intType)
{
    int mask;
    intType &= INT_TYPE_MASK;
    mask = XScuGic_DistReadReg(InstancePtr, INT_CFG0_OFFSET + (intId/16)*4);
    mask &= ~(INT_TYPE_MASK << (intId%16)*2);
    mask |= intType << ((intId%16)*2);
    XScuGic_DistWriteReg(InstancePtr, INT_CFG0_OFFSET + (intId/16)*4, mask);
}

// UART Interrupt init
int IntrInit(XScuGic *intc, XScuTimer *timer){
    int status;

    // initialize the interrupt controller
    XScuGic_Config *intc_cfg;
    intc_cfg = XScuGic_LookupConfig(INTC_DEVICE_ID);
    if(NULL == intc_cfg) return XST_FAILURE;

    status = XScuGic_CfgInitialize(intc, intc_cfg, intc_cfg->CpuBaseAddress);
    if(status != XST_SUCCESS) return XST_FAILURE;

    // set and enable interrupt exception handle function
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
        (Xil_ExceptionHandler) XScuGic_InterruptHandler, (void *) intc);

    // set interrupt handler for interrupt
//    XScuGic_Connect(intc, UART_INT_IRQ_ID, (Xil_ExceptionHandler) UartHandler, (void *) uart_ps);
    XScuGic_Connect(intc,RXOVERRUN,(Xil_ExceptionHandler)RxOverrunHandler,(void *)2);
    XScuGic_Connect(intc,RXTOUT,(Xil_ExceptionHandler)RxToutHandler,(void *)3);
    XScuGic_Connect(intc,AXITIMER,(Xil_ExceptionHandler)TimerHandler,(void *)1);

    IntcTypeSetup(intc, RXOVERRUN, INT_TYPE_RISING_EDGE);
    IntcTypeSetup(intc, RXTOUT, INT_TYPE_RISING_EDGE);
    XScuGic_SetPriorityTriggerType(intc, AXITIMER, 0x98, INT_TYPE_RISING_EDGE);

    Xil_ExceptionEnable();
    XScuGic_Enable(intc, RXOVERRUN);
	XScuGic_Enable(intc, RXTOUT);
    XScuGic_Enable(intc, AXITIMER);

    XScuTimer_EnableInterrupt(timer);

    return XST_SUCCESS;
}

void TimerHandler(void *call_back_ref){
//	XScuTimer *timer = (XScuTimer*) call_back_ref;
	XScuGic_Disable(&Intc, AXITIMER);

	for(int i=0;i<filereadByte1;i++){
		FIFO_WriteReg(FIFO_BASEADDR, (u32)0x0, filebuffer1[i]);
		ByteSend++;
	}
	sendDone = 1;
	if(f_eof(&fil)){
		end = 1;
		XTmrCtr_Stop(&tmr, 0x0);
	}
//	XScuTimer_ClearInterruptStatus(timer);
	XTmrCtr_InterruptHandler(&tmr);
	XScuGic_Enable(&Intc, AXITIMER);
}

void RxOverrunHandler(void *call_back_ref){
	XScuGic_Disable(&Intc, RXOVERRUN);

	u8 tmp;
	while((u8) FIFO_ReadReg(FIFO_BASEADDR, (u32)8) != (u8)0xff){
		tmp = FIFO_ReadReg(FIFO_BASEADDR, (u32)4);
		rxbuf[rxbufptr++] = tmp;
	}
	XScuGic_Enable(&Intc, RXOVERRUN);
}

void RxToutHandler(void *call_back_ref){
	XScuGic_Disable(&Intc, RXTOUT);

	u8 tmp;
	while((u8) FIFO_ReadReg(FIFO_BASEADDR, (u32)8) != (u8)0xff){
		tmp = FIFO_ReadReg(FIFO_BASEADDR, (u32)4);
		rxbuf[rxbufptr++] = tmp;
	}
	XScuGic_Enable(&Intc, RXTOUT);
}

int SDinit(){
	FRESULT res;
	res = f_mount(&fatfs, "0:/", 1);
	if( res != FR_OK) return XST_FAILURE;
	else return XST_SUCCESS;
}
