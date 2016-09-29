#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=2.0

// For version 2
// Added Move to ZPosition and DoClosedLoopZMotion

Function MoveToZPositionClosedLoop(TargetZPosition,[Callback,TimeToRamp])
	Variable TargetZPosition
	String Callback
	Variable TimeToRamp
	
	If(ParamIsDefault(Callback))
		Callback=""
	EndIf
	If(ParamIsDefault(TimeToRamp))
		TimeToRamp=0.1
	EndIf
	
	Variable Error=0
	
	// Stop anything on the controller
	Error += td_stop()
	Error +=td_WriteString("Event.0", "Clear")

	//  Setup z feedback loop, put in correct I value for PID loop.  
	Error +=	ir_SetPISLoop(2,"Always,Never","ZSensor",NaN,0,10^GV("ZIGain"),0,"Height",-inf,inf)

 	// Ramp to z position the amount of time allotted
 	Error += td_SetRamp(TimeToRamp, "PIDSLoop.2.Setpoint", 0, TargetZPosition, "", 0, 0, "", 0, 0, Callback)
 	
	if (Error>0)
		print "Error in MoveToZPositionClosedLoop: ", Error
	endif

End  // Function RampToPointAtConstantForce_nm

// For doing closed loop motion in the Z Direction
Function DoClosedLoopZMotion(ZSensorSetPoint,Deflection,ZSensor,[ZSetPointDecimation,DecimationFactor,Callback])
	Wave ZSensorSetPoint,Deflection,ZSensor
	Variable DecimationFactor,ZSetPointDecimation
	String Callback
	Variable Error	
	If(ParamIsDefault(ZSetPointDecimation))
		ZSetPointDecimation=100
	EndIf
	
	// Stop anything on the controller
	Error += td_stop()
	Error +=td_WriteString("Event.0", "Clear")

	//  Setup z feedback loop, put in correct I value for PID loop.  
	Error +=	ir_SetPISLoop(2,"Always,Never","ZSensor",NaN,0,10^GV("ZIGain"),0,"Height",-inf,inf)

	// Setup motion.  Decimate this wave for longer time traces.
	Error += td_xSetOutWave(0, "0,0", "PIDSLoop.2.Setpoint", ZSensorSetPoint,ZSetPointDecimation)
 
 	// Setup input waves for x,y,z and deflection.  After the motion is done, callback will execute.  Decimation set to 1 so that we always get 50KHz sample rate
	Error += td_xSetInWavePair(0, "0,0", "Cypher.LVDT.Z", ZSensor, "Deflection", Deflection,Callback, DecimationFactor)

	// Do the motion
	Error +=td_WriteString("Event.0", "once")

	if (Error>0)
		print "Error in Closed Loop Z Sensor Motion ", Error
	endif
	
End


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

