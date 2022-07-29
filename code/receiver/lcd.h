/*
 * lcd.h
 *
 *  Created on: 2022 July 28
 *      Author: hanji
 */

#ifndef SRC_LCD_H_
#define SRC_LCD_H_

#include "xparameters.h"
#include "xil_io.h"
#include "sleep.h"
#include "fonts.h"
#include "string.h"

// change the following two macro to corresponding
// base address shown in the xparameters.h
#define LCD_BASEADDR XPAR_LCDCTRL_LCDAXIADAPTER_0_BASEADDR
#define PWM_BASEADDR XPAR_LCDCTRL_AXIPWM_0_BASEADDR

int LCD_Init();
void LCD_Reset();
void LCD_ResetHard();
void LCD_Clear(u16 colour);
void LCD_SetBrightness(u32 brightness);
void LCD_SendData(u16 parameter);
void LCD_SendCMD(u16 cmd);
void LCD_SetScanDirecton(u16 direction);
void LCD_SetColourMode();
void LCD_SetStartCursorX(u16 start);
void LCD_SetStopCursorX(u16 stop);
void LCD_SetStartCursorY(u16 start);
void LCD_SetStopCursorY(u16 stop);
void LCD_SelfTest();
void LCD_ClearArea(u16 colour, u16 x, u16 xlen, u16 y, u16 ylen);

u8* findFontByChara(u8 chara);
void LCD_DisplayChar(u8 chara, u16 fontColour, u16 BackgroundColour);
void LCD_DisplayStr(char* str, u16 fontColour, u16 BackgroundColour, u16 xstart, u16 ystart);
void LCD_DisplayNum(u32 num, u16 fontColour, u16 BackgroundColour, u16 xstart, u16 ystart);

// Frequently used command
#define LCD_DrawRect(colour, x, xlen, y, ylen) \
	LCD_ClearArea(colour, x, xlen, y, ylen)
#define LCD_SleepOut(void)  LCD_SendCMD(0x1100)
#define LCD_DisplayOn(void)  LCD_SendCMD(0x2900)
#define LCD_StopTransmit(void) \
	Xil_Out32(LCD_BASEADDR, 0x11110000)

// --------------------------------------------------------------
// Implementation
int LCD_Init(){
	// 50% duty cycle
	LCD_SetBrightness(32768);
	// init
	// cs rs wr rst
	// hardware reset
	LCD_ResetHard();
	usleep(6000);
	// sleep out
	LCD_SleepOut();
	usleep(6000);

	// Display on
	LCD_DisplayOn();
	// set scan direction
	LCD_SetScanDirecton(0);
	// set colour mode, RGB565
	LCD_SetColourMode();
	LCD_StopTransmit();

	return 0;
}

// LCD hardware reset
void LCD_ResetHard(){
	Xil_Out32(LCD_BASEADDR, 0x11100000);
	// 20ms
	usleep(200000);
	Xil_Out32(LCD_BASEADDR, 0x11110000);
}

void LCD_Clear(u16 colour){
	LCD_SetStartCursorX(0x0);
	LCD_SetStopCursorX(0x1e0);

	LCD_SetStartCursorY(0x0);
	LCD_SetStopCursorY(0x360);

	// Display on
	LCD_SetScanDirecton(0);
	LCD_SetColourMode();
	LCD_SendCMD(0x2c00);
	for(int i=0;i<864*480;i++){
		LCD_SendData(colour);
	}
	LCD_StopTransmit();
}

void LCD_ClearArea(u16 colour, u16 x, u16 xlen, u16 y, u16 ylen){
	LCD_SetStartCursorX(x);
	LCD_SetStopCursorX(x+xlen-1);

	LCD_SetStartCursorY(y);
	LCD_SetStopCursorY(y+ylen-1);

	LCD_SendCMD(0x2c00);
	u32 area = xlen*ylen;
	for(int i=0;i<area;i++){
		LCD_SendData(colour);
	}
	LCD_StopTransmit();
}

// LCD software reset
void LCD_Reset(){
	Xil_Out32(LCD_BASEADDR, 0x00010100);
	Xil_Out32(LCD_BASEADDR, 0x00110100);

	LCD_SleepOut();
	LCD_SetScanDirecton(0);
	LCD_SetColourMode();
	LCD_DisplayOn();

	LCD_Clear(0xffff);
}

void LCD_SetBrightness(u32 brightness){
	Xil_Out32(PWM_BASEADDR, brightness);
}


void LCD_SendCMD(u16 cmd){
	Xil_Out32(LCD_BASEADDR, 0x00010000 + cmd);
	Xil_Out32(LCD_BASEADDR, 0x00110000 + cmd);
}

void LCD_SendData(u16 parameter){
	Xil_Out32(LCD_BASEADDR, 0x01010000 + parameter);
	Xil_Out32(LCD_BASEADDR, 0x01110000 + parameter);
}

void LCD_SetScanDirecton(u16 direction){
	LCD_SendCMD(0x3600);
	LCD_SendData(direction);
}

void LCD_SetColourMode(){
	LCD_SendCMD(0x3a00);
	LCD_SendData(0x0055);
}

void LCD_SetStartCursorX(u16 start){
	LCD_SendCMD(0x2a00);
	LCD_SendData(start>>8);
	LCD_SendCMD(0x2a01);
	LCD_SendData(start);
}
void LCD_SetStopCursorX(u16 stop){
	LCD_SendCMD(0x2a02);
	LCD_SendData(stop>>8);
	LCD_SendCMD(0x2a03);
	LCD_SendData(stop);
}
void LCD_SetStartCursorY(u16 start){
	LCD_SendCMD(0x2b00);
	LCD_SendData(start>>8);
	LCD_SendCMD(0x2b01);
	LCD_SendData(start);
}
void LCD_SetStopCursorY(u16 stop){
	LCD_SendCMD(0x2b02);
	LCD_SendData(stop>>8);
	LCD_SendCMD(0x2b03);
	LCD_SendData(stop);
}

void LCD_SelfTest(){
	// set x cursor
	// max 1E0
	LCD_SetStartCursorX(0x0);
	LCD_SetStopCursorX(0x1e0);

	// set y cursor
	// max 360
	LCD_SetStartCursorY(0x0);
	LCD_SetStopCursorY(0x360);


	// fill the gram
	LCD_SendCMD(0x2c00);

	for(int i=0;i<480*133;i++){
		Xil_Out32(LCD_BASEADDR, 0x0101f800);
		Xil_Out32(LCD_BASEADDR, 0x0111f800);
	}
	for(int i=0;i<480*133;i++){
		Xil_Out32(LCD_BASEADDR, 0x010107e0);
		Xil_Out32(LCD_BASEADDR, 0x011107e0);
	}
	for(int i=0;i<480*134;i++){
		Xil_Out32(LCD_BASEADDR, 0x0101001f);
		Xil_Out32(LCD_BASEADDR, 0x0111001f);
	}

	for(int i=0;i<480*133;i++){
		Xil_Out32(LCD_BASEADDR, 0x0101ffe0);
		Xil_Out32(LCD_BASEADDR, 0x0111ffe0);
	}
	for(int i=0;i<480*133;i++){
		Xil_Out32(LCD_BASEADDR, 0x010107ff);
		Xil_Out32(LCD_BASEADDR, 0x011107ff);
	}
	for(int i=0;i<480*134;i++){
		Xil_Out32(LCD_BASEADDR, 0x0101f81f);
		Xil_Out32(LCD_BASEADDR, 0x0111f81f);
	}
	LCD_StopTransmit();

	usleep(2000000);
	LCD_Clear(0xffff);
}

void LCD_DisplayStr(char* str, u16 fontColour, u16 BackgroundColour, u16 xstart, u16 ystart){
	u16 xc = xstart;
	u16 yc = ystart;
	u16 fontFrameZise = 34;
	u16 fontSize = 32;

	u16 strLength = (u16) strlen(str);

	for(int i=0;i<strLength;i++){
		LCD_SetStartCursorX(xc);
		LCD_SetStopCursorX(xc+fontSize-1);

		LCD_SetStartCursorY(yc);
		LCD_SetStopCursorY(yc+fontSize+fontSize-1);

		LCD_DisplayChar(str[i], 0x0, 0xffff);

		if(xc < 410) {
			xc = xc + fontFrameZise;
		} else {
			xc = xstart;
			yc = yc + 32 + fontFrameZise;
		}
	}
}

void LCD_DisplayNum(u32 num, u16 fontColour, u16 BackgroundColour, u16 xstart, u16 ystart){
		u32 numin = num;
		char tmp[10] = {'\0'};
		u8 tmpindex = 8;

		while(numin){
			tmp[tmpindex--] = numin % 10 + 48;
			numin = numin / 10;
		}
		tmpindex++;
		LCD_DisplayStr(&(tmp[tmpindex]), fontColour, BackgroundColour, xstart, ystart);
}

void LCD_DisplayChar(u8 chara, u16 fontColour, u16 BackgroundColour){
	u8* fontAddr;
	fontAddr = findFontByChara(chara);

	LCD_SendCMD(0x2c00);
	for(int i=0;i<256;i++){
		u8 tmp = fontAddr[i];
		if(tmp == 0x00){
			LCD_SendData(BackgroundColour);
			LCD_SendData(BackgroundColour);
			LCD_SendData(BackgroundColour);
			LCD_SendData(BackgroundColour);
			LCD_SendData(BackgroundColour);
			LCD_SendData(BackgroundColour);
			LCD_SendData(BackgroundColour);
			LCD_SendData(BackgroundColour);
			continue;
		}


		for(int j=0;j<8;j++){
			if(tmp&0x80) LCD_SendData(fontColour);
			else LCD_SendData(BackgroundColour);
			tmp = tmp << 1;
		}
	}
	LCD_StopTransmit();
}

u8* findFontByChara(u8 chara){
	switch(chara){
		case 'a': return a_64;
		case 'b': return b_64;
		case 'c': return c_64;
		case 'd': return d_64;
		case 'e': return e_64;
		case 'f': return f_64;
		case 'g': return g_64;
		case 'h': return h_64;
		case 'i': return i_64;
		case 'j': return j_64;
		case 'k': return k_64;
		case 'l': return l_64;
		case 'm': return m_64;
		case 'n': return n_64;
		case 'o': return o_64;
		case 'p': return p_64;
		case 'q': return q_64;
		case 'r': return r_64;
		case 's': return s_64;
		case 't': return t_64;
		case 'u': return u_64;
		case 'v': return v_64;
		case 'w': return w_64;
		case 'x': return x_64;
		case 'y': return y_64;
		case 'z': return z_64;
		case 'A': return A_64;
		case 'B': return B_64;
		case 'C': return C_64;
		case 'D': return D_64;
		case 'E': return E_64;
		case 'F': return F_64;
		case 'G': return G_64;
		case 'H': return H_64;
		case 'I': return I_64;
		case 'J': return J_64;
		case 'K': return K_64;
		case 'L': return L_64;
		case 'M': return M_64;
		case 'N': return N_64;
		case 'O': return O_64;
		case 'P': return P_64;
		case 'Q': return Q_64;
		case 'R': return R_64;
		case 'S': return S_64;
		case 'T': return T_64;
		case 'U': return U_64;
		case 'V': return V_64;
		case 'W': return W_64;
		case 'X': return X_64;
		case 'Y': return Y_64;
		case 'Z': return Z_64;
		case ' ': return SPACE_64;
		case '.': return dot_64;
		case '0': return zero_64;
		case '1': return one_64;
		case '2': return two_64;
		case '3': return three_64;
		case '4': return four_64;
		case '5': return five_64;
		case '6': return six_64;
		case '7': return seven_64;
		case '8': return eight_64;
		case '9': return nine_64;
		default:
			return NULL;
	}
}

#endif /* SRC_LCD_H_ */
