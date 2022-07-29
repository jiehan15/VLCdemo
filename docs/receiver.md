# Rebuild for Receiver

- [Rebuild for Receiver](#rebuild-for-receiver)
  - [Create A Vivado Project](#create-a-vivado-project)
  - [Add IP to Vivado IP list](#add-ip-to-vivado-ip-list)
  - [Create Block Diagram](#create-block-diagram)

## Create A Vivado Project 

Firstly, we need to create a Vivado project.  
**1)** Launch Vivado, and create a new project.  
**2)** click create a new project and select the location you want to save your project, click next. Then select RTL Project and tick the box `Do not specify sources at this time`, click next.  
**3)** Now we need to select the parts we used fo our project. In this case, we are using PYNQ-Z2 and we have installed the board file, click the `Boards` from the tool bar, and select `PYNQ-Z2` as shown below. 

![Figure 1. Select Boards](./pics/receiver/selectboards.jpg)  

*The Board file can be downloaded via TUL website: https://www.tulembedded.com/FPGA/ProductsPYNQ-Z2.html*   
*The Tutorial of installing board file can be found here (the step 3): https://digilent.com/reference/programmable-logic/guides/installing-vivado-and-sdk*

**4)** Then click finished. Now we should have an empty project. 

## Add IP to Vivado IP list

*In this tutorial, we will use pre-packaged IP to recreate the hardware for the receiver. If you want to package IP yourself, please see this [tutorial](./packageyoourip.md).*  

**1)** Click the `Settings` in the `PROJECT MANAGER` below the `Flow Navigator`  
**2)** Click `IP` -> `Repository`, and then click `+` as shown below 
![Figure 2. Add IP to IP Repo](./pics/receiver/addpathtoiprepo.jpg)  

**3)** Then select the directory stored the folder `packagedip` in this repository, then click `OK`. A window should pop up with all the prepackaged IPs as shown below. Then click `OK` to close the settings. 
![Figure 3. All the prepackaged IP](./pics/receiver/prepackagedip.jpg)  

## Create Block Diagram 
Once we have all the components we needed, the next job is to connected them together.  

**1)** Click `Create Block Design` under the `IP INTEGRATOR` in the `Flow Navigator`. Then give the block diagram the name you like. Then we need to click `+` to add IPs we want. 

**2)** The First IP we need is named `ZYNQ7 Processing System` (using **PS** to represent the IP in the following section). Firstly, Click `+`. Then Find IP named `ZYNQ7 Processing System` and double click it to add it to our block diagram. As we are using boards with board file, this IP can be configured automatically. 
![Figure 4. Run Block automation](./pics/receiver/blockautomation.jpg)   
Click the `Run Block Automation` and select `All Automation` at left side of the menu. Then click `OK`. 

*For more information, please see the ZYNQ mannual: https://docs.xilinx.com/v/u/en-US/ug585-Zynq-7000-TRM* 

After that, we still need to modified the IP some functions are not enbaled in the automation process. Double clock the IP `ZYNQ7 Processing System`, Click `Interrupt` in the `Page Navigator`. Then tick and expand the option `Fabric Interrupts`. Next, expand the tab `PL-PS Interrupt Ports` and tick `IRQ_F2P[15:0]` to allow the PS to respond to the interrupts from PL. 
![Figure 4. Enable PL to PS Interrupts](./pics/receiver/enableps2plinterrupts.jpg)  

**3)** Now, lets add the core module for the VLC system - the tx fifo, rx fifo, and the control unit. The fifos is packaged with the AXI interface and the control unit is packaged as an IP as well.  

Simliar, click `+`, then find and add IP `axi_fifo_v1_0` and `control_v1_0` to the block diagram.   

Next, we need to connect the fifos to the PS via the AXI interface by click the `Run Connection Automation` below the toolbar. 
![Figure 5. Fifo connection automation](./pics/receiver/fifoconnectionautomation.jpg)  

Once finished, two extra IPs will shown at the block diagram, named `AXI interconnect` and `Processor System Reset`. They are used to generate essential signals and extend the system connectivity.  

*For more information, please see*  
*AXI Interconnect: https://docs.xilinx.com/r/en-US/pg059-axi-interconnect*  
*Processor System Reset: https://docs.xilinx.com/v/u/en-US/pg164-proc-sys-reset*   

---
Then, we can see that the IPs `axi_fifo_v1_0` and `control_v1_0` share many pins with the same name. We need to connect the pins with the same name except for the clock and resetn signals. 

Now, focus on the `control_v1_0` first, there are four pins left unconnected. Among those pins, the `rx` and `tx` are external pins. Right click at the blank area of the block diagram, then click `create port` or using shortcut `Ctrl+K`. 

We need to create one **input** `RX` and another **output** `TX`.  
![Figure 6. Example of Create RX port](./pics/receiver/createportrs.jpg)   
Once completed creating **BOTH rx and tx**, connect them to the `control_v1_0` with the pin having the same name.  

Now, only the clock signals and the resetn signal from both two IPs are left unconnected. Both the two IP are designed to be driven by $16MHz$ clock while the `ZYNQ7 Processing System` output $100MHz$ clock. Therefore, we need add another IP named `Clocking Wizard`. Once added, double clock the IP. Change the parameters as shown below and leave other seeting as default. 
![Figure 7. clkwiz board parameters](./pics/receiver/clkwizboard.jpg)  
![Figure 8. cikwiz output clk](./pics/receiver/clkwizoutputclk.jpg)  

*Note that the $12.288MHz$ clock is for the ADAU1761 codec which will be mentioned later*  

Then, connect the the pins as shown at the below table. 
|Source|to| Destnation|
|-|-|-|
| `ZYNQ7 Processing System.FCLK_CLK0`| -> |`Clocking Wizard.clk_in1` |
| `Processor System Reset.peripheral_reset[0:0]` | -> |`Clocking Wizard.reset`|
| `Clocking Wizard.clk_out2` | -> | `control_v1_0.pclk`|
| `Clocking Wizard.clk_out2` | -> | `axi_fifo_v1_0.pclk`| 
| `Processor System Reset.peripheral_aresetn[0:0]` | -> |`control_v1_0.resetn`|
| `Processor System Reset.peripheral_aresetn[0:0]` | -> |`Clocking Wizard.fifo_resetn`|

---
Now, lets created the circuit for the ADAU1761 Codec.  
*The connection and configuration method can be founded in below links*  
*PYNQ-Z2 Schematics: https://dpoauwgwqsy2x.cloudfront.net/Download/TUL_PYNQ_Schematic_R12.pdf*   
*ADAU Datasheet: https://www.analog.com/media/en/technical-documentation/data-sheets/ADAU1761.pdf*  

The Codec is connected to the PL and using IIC to configure. Therefore, we need an IP named `AXI IIC` to set the internal registers in the codec and another prepackage ID to transfer audio stream to the codec. 

First, right click at any blank area in the block diagram and then click `Create Hierarchy...`. Then give the subblock a name, e.g., `ADAU1761Ctrl`. Once finished, double click the deep blue subblok to enter it. 

then simliar, click `+`, then find and add IPs `AXI IIC`, `serialWrapper_v1_0`, and `AXI Interconnect` to the block diagram.   

Clock the `Run Connection Automation` at the above and select the same option as shown below. Click `OK` once finished. 
![Figure 9. ADAU1761 AXI IIC](./pics/receiver/adau1761iic.jpg)  

After that, we need create input and output pins for this sub block. Similarly, press `Ctrl+K` to create **input** ports `aclk`, `aresetn`, and `mclk` and **output** ports `lrclk`, `bclk`, and `dout`. 

Then press `Ctrl+L` to create an **slave** AXI interface named `saxi` which is belongs to `aximm_rtl`. 

Then, connect the the pins **within this subblock** as shown at the below table.   
**input**
|Source|to| Destnation|
|-|-|-|
| `aclk`| -> |`AXI Interconnect.ACLK` |
| `aclk` | -> |`AXI Interconnect.S00_ACLK`|
| `aclk` | -> |`AXI Interconnect.M00_ACLK`|
| `aclk` | -> |`AXI Interconnect.M01_ACLK`|
| `aclk` | -> |`AXI IIC.s_axi_aclk`|
| `aclk` | -> |`serialWrapper_v1_0.aclk`|
| `aresetn` | -> | `AXI Interconnect.ARESETN`| 
| `aresetn` | -> | `AXI Interconnect.S00_ARESETN`| 
| `aresetn` | -> | `AXI Interconnect.M00_ARESETN`| 
| `aresetn` | -> | `AXI Interconnect.M01_ARESETN`| 
| `aresetn` | -> | `AXI IIC.s_axi_aresetn`| 
| `aresetn` | -> |`serialWrapper_v1_0.aresetn`|
| `mclk` | -> |`serialWrapper_v1_0.mclk`|

**output**
|Source|to| Destnation|
|-|-|-|
| `serialWrapper_v1_0.lrclk` | -> |`lrclk`|
| `serialWrapper_v1_0.bclk` | -> |`bclk`|
| `serialWrapper_v1_0.dout` | -> |`dout`|

Once finished, it should look like this. 
![Figure 10. ADAU1761 AXI Driver](./pics/receiver/adau1761driver.jpg)  


