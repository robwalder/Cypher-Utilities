#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=1.0

Function MoveToPointClosedLoop(MoveToPointCFSettings,[Callback])
	Wave MoveToPointCFSettings
	String Callback
	
	If(ParamIsDefault(Callback))
		Callback=""
	EndIf
	
	Variable XCurrentPosition_Volts = td_rv("Cypher.LVDT.X")
	Variable YCurrentPosition_Volts = td_rv("Cypher.LVDT.Y")
	Variable Error
	// Stop everything and setup feedback loops for ramp
	Error += td_stop()
	Error +=	ir_SetPISLoop(0,"Always,Never","Cypher.LVDT.X",XCurrentPosition_Volts,MoveToPointCFSettings[%P_X], MoveToPointCFSettings[%I_X], MoveToPointCFSettings[%S_X],"ARC.Output.X",-10,150)
	Error +=	ir_SetPISLoop(1,"Always,Never","Cypher.LVDT.Y",YCurrentPosition_Volts,MoveToPointCFSettings[%P_Y], MoveToPointCFSettings[%I_Y], MoveToPointCFSettings[%S_Y],"ARC.Output.Y",-10,150)
	
 	// Ramp to position at constant force within the amount of time allotted
 	Error += td_SetRamp(MoveToPointCFSettings[%Time_s], "PIDSLoop.0.Setpoint", 0, MoveToPointCFSettings[%XPosition_V], "PIDSLoop.1.Setpoint", 0, MoveToPointCFSettings[%YPosition_V], "", 0, 0, Callback)
 	
	if (Error>0)
		print "Error in MoveToPointCF: ", Error
	endif

End  // Function RampToPointAtConstantForce_nm

 Function MakeMoveToPointCLSettingsWave([OutputWaveName])
	String OutputWaveName
	
	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="MoveToPointCLSettings"
	EndIf

	Make/O/N=16 $OutputWaveName
	Wave MoveToPointCLSettings=$OutputWaveName
	
	SetDimLabel 0,0, $"XPosition_V", MoveToPointCLSettings
 	SetDimLabel 0,1, $"YPosition_V", MoveToPointCLSettings
 	SetDimLabel 0,2, $"SamplingRate_Hz", MoveToPointCLSettings
  	SetDimLabel 0,3, $"Time_s", MoveToPointCLSettings
   	SetDimLabel 0,4, $"P_x", MoveToPointCLSettings
   	SetDimLabel 0,5, $"I_x", MoveToPointCLSettings
   	SetDimLabel 0,6, $"S_x", MoveToPointCLSettings
   	SetDimLabel 0,7, $"P_y", MoveToPointCLSettings
   	SetDimLabel 0,8, $"I_y", MoveToPointCLSettings
   	SetDimLabel 0,9, $"S_y", MoveToPointCLSettings
   	SetDimLabel 0,10, $"P_Deflection", MoveToPointCLSettings
   	SetDimLabel 0,11, $"I_Deflection", MoveToPointCLSettings
   	SetDimLabel 0,12, $"S_Deflection", MoveToPointCLSettings

	MoveToPointCLSettings={0,0,1000,0.25,0, -5.616e4, 0,0, 5.768e4, 0,0, 2999.999, 0}
End

