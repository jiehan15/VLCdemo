# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "BaseAddr" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FIFO_OVERRUN" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FIFO_PTR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FIFO_TIMEOUT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FIFO_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "RxBaseAddr" -parent ${Page_0}
  ipgui::add_param $IPINST -name "TxBaseAddr" -parent ${Page_0}


}

proc update_PARAM_VALUE.BaseAddr { PARAM_VALUE.BaseAddr } {
	# Procedure called to update BaseAddr when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BaseAddr { PARAM_VALUE.BaseAddr } {
	# Procedure called to validate BaseAddr
	return true
}

proc update_PARAM_VALUE.FIFO_OVERRUN { PARAM_VALUE.FIFO_OVERRUN } {
	# Procedure called to update FIFO_OVERRUN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FIFO_OVERRUN { PARAM_VALUE.FIFO_OVERRUN } {
	# Procedure called to validate FIFO_OVERRUN
	return true
}

proc update_PARAM_VALUE.FIFO_PTR { PARAM_VALUE.FIFO_PTR } {
	# Procedure called to update FIFO_PTR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FIFO_PTR { PARAM_VALUE.FIFO_PTR } {
	# Procedure called to validate FIFO_PTR
	return true
}

proc update_PARAM_VALUE.FIFO_TIMEOUT { PARAM_VALUE.FIFO_TIMEOUT } {
	# Procedure called to update FIFO_TIMEOUT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FIFO_TIMEOUT { PARAM_VALUE.FIFO_TIMEOUT } {
	# Procedure called to validate FIFO_TIMEOUT
	return true
}

proc update_PARAM_VALUE.FIFO_WIDTH { PARAM_VALUE.FIFO_WIDTH } {
	# Procedure called to update FIFO_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FIFO_WIDTH { PARAM_VALUE.FIFO_WIDTH } {
	# Procedure called to validate FIFO_WIDTH
	return true
}

proc update_PARAM_VALUE.RxBaseAddr { PARAM_VALUE.RxBaseAddr } {
	# Procedure called to update RxBaseAddr when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RxBaseAddr { PARAM_VALUE.RxBaseAddr } {
	# Procedure called to validate RxBaseAddr
	return true
}

proc update_PARAM_VALUE.TxBaseAddr { PARAM_VALUE.TxBaseAddr } {
	# Procedure called to update TxBaseAddr when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TxBaseAddr { PARAM_VALUE.TxBaseAddr } {
	# Procedure called to validate TxBaseAddr
	return true
}


proc update_MODELPARAM_VALUE.BaseAddr { MODELPARAM_VALUE.BaseAddr PARAM_VALUE.BaseAddr } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BaseAddr}] ${MODELPARAM_VALUE.BaseAddr}
}

proc update_MODELPARAM_VALUE.TxBaseAddr { MODELPARAM_VALUE.TxBaseAddr PARAM_VALUE.TxBaseAddr } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TxBaseAddr}] ${MODELPARAM_VALUE.TxBaseAddr}
}

proc update_MODELPARAM_VALUE.RxBaseAddr { MODELPARAM_VALUE.RxBaseAddr PARAM_VALUE.RxBaseAddr } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RxBaseAddr}] ${MODELPARAM_VALUE.RxBaseAddr}
}

proc update_MODELPARAM_VALUE.FIFO_PTR { MODELPARAM_VALUE.FIFO_PTR PARAM_VALUE.FIFO_PTR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FIFO_PTR}] ${MODELPARAM_VALUE.FIFO_PTR}
}

proc update_MODELPARAM_VALUE.FIFO_WIDTH { MODELPARAM_VALUE.FIFO_WIDTH PARAM_VALUE.FIFO_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FIFO_WIDTH}] ${MODELPARAM_VALUE.FIFO_WIDTH}
}

proc update_MODELPARAM_VALUE.FIFO_TIMEOUT { MODELPARAM_VALUE.FIFO_TIMEOUT PARAM_VALUE.FIFO_TIMEOUT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FIFO_TIMEOUT}] ${MODELPARAM_VALUE.FIFO_TIMEOUT}
}

proc update_MODELPARAM_VALUE.FIFO_OVERRUN { MODELPARAM_VALUE.FIFO_OVERRUN PARAM_VALUE.FIFO_OVERRUN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FIFO_OVERRUN}] ${MODELPARAM_VALUE.FIFO_OVERRUN}
}

