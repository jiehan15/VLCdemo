/*
 * main.c
 *
 *  Created on: 2022 July 7
 *      Author: hanji
 */
#include "xparameters.h"
#include "xuartps.h"
#include "xil_printf.h"
#include "xscugic.h"
#include "xscutimer.h"
#include "stdio.h"
#include "stdlib.h"
#include "sleep.h"
#include "string.h"
#include "xil_cache.h"

#include "axiiic.h"
#include "vlc.h"

#include "fonts.h"
#include "lcd.h"

// mp3 decoder lib
#define MINIMP3_IMPLEMENTATION
#include "minimp3.h"

// serial device ID
#define UART_DEVICE_ID      XPAR_PS7_UART_0_DEVICE_ID
// interrupt ID
#define INTC_DEVICE_ID      XPAR_PS7_SCUGIC_0_DEVICE_ID
// serial port interrupt id
#define UART_INT_IRQ_ID     XPAR_XUARTPS_0_INTR

// TIMER
#define TIMER_DEVICE_ID 	XPAR_XSCUTIMER_0_DEVICE_ID
#define TIMER_IRPT_INTR 	XPAR_SCUTIMER_INTR
// the frequency of the timer is half the CPU freq
#define TIMER_LOAD_VALUE	(XPAR_CPU_CORTEXA9_0_CPU_CLK_FREQ_HZ/2000)/5

#define ADAU1761SERIAL_BASEADDR XPAR_ADAU1761CTRL_SERIALWRAPPER_0_BASEADDR

// interrupt controller driver instance
XScuGic Intc;
// serial port driver instance
XUartPs Uart_Ps;
// timer
XScuTimer Timer;

// data buffer size
#define MAX_LEN 8192
u8 rxdatabuf[MAX_LEN+1] = {0};
u32 rxdatabufptr_abs_prev;
u32 rxdatabufptr_abs;
u32 rxdatabufptr;

u8 rxcmdbuf[65] = {0};
u8 rxcmdptr;

u8 rxbufselect = 0;

u8 uartrxbuf[65];
u8 uartrxptr = 0;

// serial port driver instance
XUartPs Uart_Ps;

XUartPsFormat UartFormat = {
    115200,
    XUARTPS_FORMAT_8_BITS,
    XUARTPS_FORMAT_NO_PARITY,
    XUARTPS_FORMAT_1_STOP_BIT
};

// function declaration
int UartInit(XUartPs *uart_ps);
int TimerInit(XScuTimer *timer);
// interrupt handler
void UartHandler(void *call_back_ref);
void TimerHandler(void *call_back_ref);
void RxOverrunHandler(void *call_back_ref);
void RxToutHandler(void *call_back_ref);
void Touch_Handler(void *call_back_ref);
int IntrInit(XScuGic *intc, XUartPs *uart_ps, XScuTimer *timer);
void IntcTypeSetup(XScuGic *InstancePtr, int intId, int intType);

VlcCommand* vlcCMD;

static unsigned int filelen;
static unsigned int fileptr;
static unsigned int counter;
static unsigned int recvlen;

// mp3 decoder instance
#define MP3BUFFERLEN 4096
static mp3dec_t mp3d;
static unsigned int mp3ptr;
static unsigned int mp3frames;
static unsigned int mp3toutcounter = 0;
static u8 vol = 0x36;
static u16 relativeVol = 0x36 * 100 / 0x3f;

// state machine
#define DEFAULTSTATE 0x5
static int curState = DEFAULTSTATE;
static int nxtState = DEFAULTSTATE;

// touch screen
int touched = 0;
int released = 0;
u8 xlow = 0;
u8 xhigh = 0;
u8 ylow = 0;
u8 yhigh = 0;
u16 x;
u16 y;

int main(){
	int status;
	vlcCMD = (VlcCommand*) malloc(sizeof(VlcCommand));

	// initialize the serial port
	status = UartInit(&Uart_Ps);
	if(status == XST_FAILURE){
		xil_printf("Uart Initialization Failed\r\n");
		return XST_FAILURE;
	}
	xil_printf("UART Init Successes!\r\n");

	// ----------------------------------------------------
	// ADAU1761 INIT
	status = ADAU1761Init();
	if(status != 1) {
		xil_printf("ADAU1761 Initialization Failed\r\n");
		return XST_FAILURE;
	}
	xil_printf("ADAU1761 Codec Init Successes!\r\n");

	// --------------------------------------------------
	// LCD init
	if(LCD_Init() != 0){
			xil_printf("LCD Init Failed!\r\n");
		}
	// software reset
	LCD_Reset();
	xil_printf("LCD Init Successes!\r\n");

	// -------------------------------------------------
	// touch controller init
	if(Touch_Init() != 0){
			xil_printf("Touch Init Failed!\r\n");
		}
	xil_printf("Touch Init Successes!\r\n");

	// -------------------------------------------------
	// interrupt initialization
	status = IntrInit(&Intc, &Uart_Ps, &Timer);
	if(status == XST_FAILURE){
		xil_printf("Interrupt Initialization Failed\r\n");
		return XST_FAILURE;
	}
	xil_printf("Interrupt controller Init Successes!\r\n");

	// --------------------------------------------------
	// mp3 decoder init
	mp3dec_init(&mp3d);
	xil_printf("MP3 decoder Init Successes!\r\n");

	/*typedef struct
		{
			int frame_bytes;
			int channels;
			int hz;
			int layer;
			int bitrate_kbps;
		} mp3dec_frame_info_t;*/
	mp3dec_frame_info_t info;
	short pcm[MINIMP3_MAX_SAMPLES_PER_FRAME];
	int samples;
	/*unsigned char *input_buf; - input byte stream*/
	// samples = mp3dec_decode_frame(&mp3d, input_buf, buf_size, pcm, &info);

    xil_printf("System Init Success\r\n");
    LCD_SelfTest();

    LCD_DisplayStr(FILENAME1, 0x0, 0xffff, 10, 10);
    LCD_DisplayStr(FILENAME2, 0x0, 0xffff, 10, 80);
    LCD_DisplayStr(FILENAME3, 0x0, 0xffff, 10, 160);
    LCD_DisplayStr(FILENAME4, 0x0, 0xffff, 10, 240);
    LCD_DisplayStr(FILENAME5, 0x0, 0xffff, 10, 320);

    LCD_DrawRect(0x0, 10, 460, 384, 4);

    static char* PLAY = "PLAY\0";
    static char* PAUSE = "PAUSE\0";
    static char* STOP = "STOP\0";
    LCD_DisplayStr(PLAY, 0x0, 0xffff, 10, 720);
    LCD_DisplayStr(PAUSE, 0x0, 0xffff, 150, 720);
    LCD_DisplayStr(STOP, 0x0, 0xffff, 330, 720);
    LCD_DrawRect(0x0, 10, 460, 720, 4);

    static char* PLAYI = "PLAYING\0";
	static char* PAUSEI = "PAUSING\0";
	static char* STOPI = "STOPPING\0";
	LCD_DisplayStr(STOPI, 0x0, 0xffff, 10, 390);
	LCD_DrawRect(0x0, 10, 460, 454, 4);

	static char* REQLEN = "ReqLen\0";
	static char* REVLEN = "RevLen\0";
	static char* VUP = "VUP\0";
	static char* Vdown = "VDown\0";

	LCD_DisplayStr(REQLEN, 0x0, 0xffff, 10, 460);
	LCD_DisplayStr(VUP, 0x0, 0xffff, 240, 460);
	LCD_DisplayStr(REVLEN, 0x0, 0xffff, 10, 588);
	LCD_DisplayStr(Vdown, 0x0, 0xffff, 240, 588);
	LCD_DisplayNum(relativeVol, 0x0, 0xffff, 368, 460);

	while(1){
		// state machine
		switch(curState){
			case 0x5:
				// touch screen
				if(released){
					released = 0x0;
					xil_printf("x:%d, y:%d\r\n", x, y);
					// determine which song to play
					if(y<80 && y > 10){
						sendCMD(0x1, 0x0, 0x0, 0x0);
						nxtState = 0x0;
					} else if(y < 160 && y > 80){
						sendCMD(0x1, 0x1, 0x0, 0x0);
						nxtState = 0x0;
					} else if(y < 240 && y > 160){
						sendCMD(0x1, 0x2, 0x0, 0x0);
						nxtState = 0x0;
					} else if(y < 320 && y > 240){
						sendCMD(0x1, 0x3, 0x0, 0x0);
						nxtState = 0x0;
					} else if(y < 400 && y > 320){
						sendCMD(0x1, 0x4, 0x0, 0x0);
						nxtState = 0x0;
					}
				}
				break;

			// ------------------------------------------------------
			// wait for the feedback from the transmitter
			case 0x0:
				if(rxcmdptr >= 10){
					// if the received word is no error
					if(convertCMD(rxcmdbuf, vlcCMD)) {
						if(vlcCMD->operation == OPENSUCCMUSIC){
							// set default value
							filelen = vlcCMD->FILEptr;
							fileptr = 0;
							counter = 0;

							// to next state
							vlcCMD->FILEptr = 0;
							nxtState = 0x1;
							rxbufselect = 1;

							LCD_ClearArea(0xffff, 10, 280, 400, 45);
							LCD_DisplayStr(PLAYI, 0x0, 0xffff, 10, 390);

							LCD_ClearArea(0xffff, 10, 280, 534, 45);
							LCD_DisplayNum(filelen, 0x0, 0xffff, 10, 524);

						} else if(vlcCMD->operation == OPENFAILMUSIC){
							xil_printf("File open failed\r\n");
							sendCMD(0xb, 0x0, 0x0, 0x0);
							nxtState = 0x5;
						}
					}

					rxcmdptr = 0;
					rxdatabufptr_abs = 0;
					mp3ptr = 0;
					recvlen = 0;
					mp3frames = 0;
				}
				break;

			// read datastream
			case 0x1:
				// ----------------------------------------
				// touch screen
				if(released){
					// determine which operation to do
					// if STOP or pause are pressed
					if(x > 150 && y > 720){
						nxtState = 0x4;
						break;
					} else if(x > 240 && y > 460 && y < 524) {
						released = 0;
						// volume control
						// volume up
						vol = (vol <= 61) ? vol + 2 : vol;
						changeVolume(vol);
						relativeVol = vol*100 / 0x3f;
						LCD_ClearArea(0xffff, 368, 96, 470, 45);
						LCD_DisplayNum(relativeVol, 0x0, 0xffff, 368, 460);

					} else if(x > 240 && y > 588 && y < 654) {
						released = 0;
						// volume down
						vol = (vol >= 2) ? vol - 2 : vol;
						changeVolume(vol);
						relativeVol = vol*100 / 0x3f;
						LCD_ClearArea(0xffff, 368, 96, 470, 45);
						LCD_DisplayNum(relativeVol, 0x0, 0xffff, 368, 460);
					}
				}

				// -----------------------------------------------
				// time out counter
				if(rxdatabufptr_abs_prev == rxdatabufptr_abs){
					counter++;
					// if timeout, go to idle state
					if(counter > 0x3ffffff){
						counter = 0;
						nxtState = 0x2;
						break;
					}
				} else {
					counter = 0;
					// enough data send to decoder
					if(rxdatabufptr > MP3BUFFERLEN){
						nxtState = 0x3;
					}
				}
				rxdatabufptr_abs_prev = rxdatabufptr_abs;

				break;

			case 0x3:
				// printf current received bytes
				LCD_ClearArea(0xffff, 10, 280, 662, 45);
				LCD_DisplayNum(recvlen, 0x0, 0xffff, 10, 652);
				// -----------------------------------------------
				// if the left length is not long enough,
				// move the unused data to the beginning of the buffer
				// and set the rxbuffer ptr to that new location and reset
				// the mp3ptr as no data is used in terms of this new buffer
				mp3ptr = 0;
				while(mp3ptr < MP3BUFFERLEN-384){
					samples = mp3dec_decode_frame(&mp3d, &(rxdatabuf[mp3ptr]), MP3BUFFERLEN, pcm, &info);
					// update mp3ptr according to the consumed data
					mp3ptr += info.frame_bytes;
					if(samples>0){
						// reset
						mp3toutcounter = 0;
						mp3frames++;
						// write pcm values to ADAU1761 Rx FIFO
						int i=0;
						while(i<MINIMP3_MAX_SAMPLES_PER_FRAME){
							if(Xil_In32(ADAU1761SERIAL_BASEADDR + 0x4) != 0xffffffff){
								// switch byte sequence
								Xil_Out32(ADAU1761SERIAL_BASEADDR + 0x4, pcm[i]);
								i++;
							}
						}
					}
				}

				// move unused data to new location
				// log current ptr
				unsigned int currentrxbufptr = rxdatabufptr;
				// new ptr for receive
				// these bytes will be moved to the beginning of the
				// rx buffer
				unsigned int unusedBytes = currentrxbufptr - mp3ptr;
				rxdatabufptr_abs = (unusedBytes+1);
				rxdatabufptr = rxdatabufptr_abs % MAX_LEN;

				for(int i=mp3ptr;i<=currentrxbufptr;i++){
					rxdatabuf[i-mp3ptr] = rxdatabuf[i];
				}

				nxtState = 0x1;
				break;

			case 0x2:
				usleep(1000);
				xil_printf("Recv Finished\r\nRequest File Len: %u, Recv len: %u\r\nValid MP3 Frames: %u\r\n",
						filelen, recvlen, mp3frames);
				nxtState = 0x5;
				sendCMD(0xb, 0x0, 0x0, 0x0);

				// print to LCD
				LCD_DrawRect(0xffff, 10, 280, 400, 45);
				LCD_DisplayStr(STOPI, 0x0, 0xffff, 10, 390);

				LCD_ClearArea(0xffff, 10, 280, 662, 45);
				LCD_DisplayNum(recvlen, 0x0, 0xffff, 10, 652);

				// reset to CMD buffer
				rxbufselect = 0;
				rxcmdptr = 0;
				for(int i=0;i<64;i++){
					rxcmdbuf[i] = 0;
				}
				break;

			// pause or stop
			case 0x4:
				// ----------------------------------------
				// touch screen
				if(released){
					released = 0x0;
					xil_printf("x:%d, y:%d\r\n", x, y);

					// -----------------------------------------
					// play
					if(y > 720){
						if(x < 150) {
							sendCMD(0xa, 0x0, 0x0, 0x0);
							nxtState = 0x1;
							LCD_DrawRect(0xffff, 10, 280, 400, 45);
							LCD_DisplayStr(PLAYI, 0x0, 0xffff, 10, 390);
						} else if( x < 330 && x > 150){
							// PAUSE
							// send out command
							sendCMD(0x9, 0x0, 0x0, 0x0);
							LCD_DrawRect(0xffff, 10, 280, 400, 45);
							LCD_DisplayStr(PAUSEI, 0x0, 0xffff, 10, 390);
						} else if( x < 460 && x > 330){
							// STOP
							sendCMD(0xb, 0x0, 0x0, 0x0);
							nxtState = 0x2;
							LCD_DrawRect(0xffff, 10, 280, 400, 45);
							LCD_DisplayStr(STOPI, 0x0, 0xffff, 10, 390);
						}
					}
				}
				break;
		}
		curState = nxtState;
	}

	return 0;
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
int IntrInit(XScuGic *intc, XUartPs *uart_ps, XScuTimer *timer){
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
    XScuGic_Connect(intc, RXOVERRUN, (Xil_ExceptionHandler) RxOverrunHandler, (void *)2);
    XScuGic_Connect(intc, RXTOUT, (Xil_ExceptionHandler) RxToutHandler, (void *)3);
    XScuGic_Connect(intc, TOUCH_INT, (Xil_ExceptionHandler) Touch_Handler, (void *)4);

    // set interrupt trigger mode
    XScuGic_SetPriorityTriggerType(intc, RXOVERRUN, 0x98, INT_TYPE_RISING_EDGE);
    XScuGic_SetPriorityTriggerType(intc, RXTOUT, 0x90, INT_TYPE_RISING_EDGE);
    XScuGic_SetPriorityTriggerType(intc, TOUCH_INT, 0xa0, INT_TYPE_RISING_EDGE);


    Xil_ExceptionEnable();
    XScuGic_Enable(intc, RXOVERRUN);
	XScuGic_Enable(intc, RXTOUT);
	XScuGic_Enable(intc, TOUCH_INT);

    return XST_SUCCESS;
}

void RxOverrunHandler(void *call_back_ref){
	XScuGic_Disable(&Intc, RXOVERRUN);
	u8 tmp;
	while((u8) FIFO_ReadReg(FIFO_BASEADDR, (u32)8) != (u8)0xff){
		tmp = FIFO_ReadReg(FIFO_BASEADDR, (u32)4);
		if(rxbufselect == 0){
			if(rxcmdptr > 64) rxcmdptr = 0;
			rxcmdbuf[rxcmdptr++] = tmp;
		} else if(rxbufselect == 1){
			rxdatabufptr = rxdatabufptr_abs % MAX_LEN;
			rxdatabuf[rxdatabufptr] = tmp;
			rxdatabufptr_abs++;
			recvlen++;
		}
	}
	XScuGic_Enable(&Intc, RXOVERRUN);
}

void RxToutHandler(void *call_back_ref){
	XScuGic_Disable(&Intc, RXTOUT);
	u8 tmp;
	while((u8) FIFO_ReadReg(FIFO_BASEADDR, (u32)8) != (u8)0xff){
		tmp = FIFO_ReadReg(FIFO_BASEADDR, (u32)4);
		if(rxbufselect == 0){
			if(rxcmdptr > 64) rxcmdptr = 0;
			rxcmdbuf[rxcmdptr++] = tmp;
		} else if(rxbufselect == 1){
			rxdatabufptr = rxdatabufptr_abs % MAX_LEN;
			rxdatabuf[rxdatabufptr] = tmp;
			rxdatabufptr_abs++;
			recvlen++;
		}
	}
	XScuGic_Enable(&Intc, RXTOUT);
}

void Touch_Handler(void *call_back_ref){
	u8 statusReg;
	XScuGic_Disable(&Intc, TOUCH_INT);
	statusReg = Single_Byte_Read(TOUCHIICADDR, 0x14, 0x81, 0x4e);
	Single_Byte_Write(TOUCHIICADDR, 0x14, 0x81, 0x4e, 0x00);

	switch(touched){
		case 0x0:
			if(statusReg&0xf){
				touched = 0x1;
			}
			break;
		case 0x1:
			if(statusReg == 0x80){
				touched = 0x2;
			} else {
				touched = 0x0;
			}
			break;
		case 0x2:
			if(statusReg == 0x0){
				xlow = Single_Byte_Read(TOUCHIICADDR, 0x14, 0x81, 0x50);
				xhigh = Single_Byte_Read(TOUCHIICADDR, 0x14, 0x81, 0x51);
				ylow = Single_Byte_Read(TOUCHIICADDR, 0x14, 0x81, 0x52);
				yhigh = Single_Byte_Read(TOUCHIICADDR, 0x14, 0x81, 0x53);
				x = xlow + (xhigh<<8);
				y = ylow + (yhigh<<8);
				released = 0x1;
				touched = 0x0;
			}
			break;
		default:
			touched = 0x0;
	}

	XScuGic_Enable(&Intc, TOUCH_INT);
}
