#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=1.0

// Still need cross motion (for fine centering) and need to test all of these functions doing actual motion during constant force. 

// Constant Force Circle Part 1 of 2 
// This ramps the molecule to constant force and moves it to the first point on the circle.
// The callback for the ramp then moves in a circle.
// When the "circle" motion stops, Asylum's controller will reset back to the point before the motion.  By moving to the start( and end) point of the circle, it will just hold position after the motion is finished.
function CFCircle(CFCSettings,CFCWaveNamesCallback)
	Wave CFCSettings
	Wave/T CFCWaveNamesCallback
	
	//Setup callback to execute constant circle
	String CFCircleCommand="CFCircle2("+NameOfWave(CFCSettings)+","+NameOfWave(CFCWaveNamesCallback)+")"
	
	// Make a wave for motion settings to get to the starting point of the circle
	MakeMoveToPointCFSettingsWave(OutputWaveName="CircleStartingPoint")
	Wave MoveToPointCFSettings=$"CircleStartingPoint"
	MoveToPointCFSettings[%XPosition_V]=CFCSettings[%CenterX_V]
	MoveToPointCFSettings[%YPosition_V]=CFCSettings[%Radius_m]/GV("YLVDTSens")+CFCSettings[%CenterY_V]
	MoveToPointCFSettings[%Force_N]=CFCSettings[%Force_N]
	MoveToPointCFSettings[%DefVOffset]=CFCSettings[%DefVOffset]
	MoveToPointCFSettings[%RelativeToCurrentDefV]=CFCSettings[%RelativeToCurrentDefV]
	MoveToPointCFSettings[%Time_S]=0.1	
	
	// Convert the force to an absolute value, to prevent compounding errors from offsetting to current deflection (if you are already at constant force, then a relative offset from that will just double the force on the molecule)
	Variable AbsoluteForceN=ForceToDeflection(CFCSettings[%Force_N],Offset=CFCSettings[%DefVOffset],RelativeToCurrentDeflection=CFCSettings[%RelativeToCurrentDefV])*GV("SpringConstant")*GV("INVOLS")*-1
	CFCSettings[%Force_N]=AbsoluteForceN
	CFCSettings[%DefVOffset]=0
	CFCSettings[%RelativeToCurrentDefV]=0
	
	// Copy feedback loop settings to MoveToPointCFSettings from CFCSettings
	CopyPISLoopSettings(CFCSettings,MoveToPointCFSettings)
	
	// Move to the starting point of the circle.  The callback will then execute the circle
	MoveToPointCF(MoveToPointCFSettings,Callback=CFCircleCommand)
End
	
// Actually does the movement of a constant force circle
// part 2 of 2  constant force circle and then execute callback
Function CFCircle2(CFCSettings,CFCWaveNamesCallback)
	Wave CFCSettings
	Wave/T CFCWaveNamesCallback
	
	
	// Now figure out the decimation factor to give the closest sampling rate possible
	Variable DecimationFactor=Round(50000/CFCSettings[%$"SamplingRate_Hz"])
	Variable EffectiveSamplingRate=50000/DecimationFactor
	// How many points should we make these waves
	Variable NumPoints=Floor(CFCSettings[%$"TimeToCircle_s"]*EffectiveSamplingRate)

	// Make all waves and setup the wave references.  
	Make/N=(NumPoints)/O $CFCWaveNamesCallback[%XSensor], $CFCWaveNamesCallback[%YSensor],XCommand, YCommand, $CFCWaveNamesCallback[%ZSensor],$CFCWaveNamesCallback[%DefV]
	Wave XSensor= $CFCWaveNamesCallback[%XSensor]
	Wave YSensor= $CFCWaveNamesCallback[%YSensor]
	Wave ZSensor= $CFCWaveNamesCallback[%ZSensor]
	Wave DefV= $CFCWaveNamesCallback[%DefV]
	
	// Circle motion waves.  Radius in volts * cos or sin(t)+center position
	XCommand = CFCSettings[%Radius_m]/GV("XLVDTSens")*cos(2*pi*p/NumPoints)+CFCSettings[%CenterX_V]
	YCommand = CFCSettings[%Radius_m]/GV("YLVDTSens")*sin(2*pi*p/NumPoints)+CFCSettings[%CenterY_V]

	Variable Error = 0
	Variable Force_Volts = ForceToDeflection(CFCSettings[%Force_N],Offset=CFCSettings[%DefVOffset],RelativeToCurrentDeflection=CFCSettings[%RelativeToCurrentDefV])

	//  Setup feedback loops
	Error +=	ir_SetPISLoop(0,"Always,Never","Cypher.LVDT.X",XCommand[0],CFCSettings[%P_X], CFCSettings[%I_X], CFCSettings[%S_X],"ARC.Output.X",-10,150)
	Error +=	ir_SetPISLoop(1,"Always,Never","Cypher.LVDT.Y",YCommand[0],CFCSettings[%P_Y], CFCSettings[%I_Y], CFCSettings[%S_Y],"ARC.Output.Y",-10,150)

	// Setup motion
	Error += td_xSetOutWavePair(0, "0,0", "PIDSLoop.0.Setpoint", XCommand, "PIDSLoop.1.Setpoint",YCommand,DecimationFactor)
	//Error+= td_xSetOutWave(1, "0,0", "PIDSLoop.2.Setpoint", ForceCommand, 100)
	
	// Setup input waves for x,y,z and deflection.  After the motion is done, callback will execute
	Error += td_xSetInWavePair(0, "0,0", "Cypher.LVDT.Z", ZSensor, "Deflection", DefV,CFCWaveNamesCallback[%Callback], DecimationFactor)
	Error += td_xSetInWavePair(1, "0,0", "Cypher.LVDT.X", XSensor, "Cypher.LVDT.Y", YSensor, "", DecimationFactor)

	// Execute motion
	Error +=td_WriteString("Event.0", "once")

	if (Error>0)
		print "Error in CFCircle2: ", Error
	endif
	
end
 
 
 Function MakeCFCSettingsWave([OutputWaveName])
	String OutputWaveName
	
	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="CFCSettings"
	EndIf

	Make/O/N=17 $OutputWaveName
	Wave CFCSettings=$OutputWaveName
	
	SetDimLabel 0,0, $"CenterX_V", CFCSettings
 	SetDimLabel 0,1, $"CenterY_V", CFCSettings
 	SetDimLabel 0,2, $"Radius_m", CFCSettings
 	SetDimLabel 0,3, $"TimeToCircle_s", CFCSettings
 	SetDimLabel 0,4, $"SamplingRate_Hz", CFCSettings
  	SetDimLabel 0,5, $"Force_N", CFCSettings
   	SetDimLabel 0,6, $"DefVOffset", CFCSettings
   	SetDimLabel 0,7, $"P_x", CFCSettings
   	SetDimLabel 0,8, $"I_x", CFCSettings
   	SetDimLabel 0,9, $"S_x", CFCSettings
   	SetDimLabel 0,10, $"P_y", CFCSettings
   	SetDimLabel 0,11, $"I_y", CFCSettings
   	SetDimLabel 0,12, $"S_y", CFCSettings
   	SetDimLabel 0,13, $"P_Deflection", CFCSettings
   	SetDimLabel 0,14, $"I_Deflection", CFCSettings
   	SetDimLabel 0,15, $"S_Deflection", CFCSettings
   	SetDimLabel 0,16, $"RelativeToCurrentDefV", CFCSettings

	CFCSettings={0,0,100e-9,1,1000,30e-9,0,0, -5.616e4, 0,0, 5.768e4, 0,0, 2999.999, 0,0}
End

Function MakeCFCWaveNamesCallback([OutputWaveName])
	String OutputWaveName
	
	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="CFCWaveNamesCallback"
	EndIf

	Make/O/T/N=5 $OutputWaveName
	Wave/T CFCWaveNamesCallback=$OutputWaveName
	
	SetDimLabel 0,0, $"XSensor", CFCWaveNamesCallback
 	SetDimLabel 0,1, $"YSensor", CFCWaveNamesCallback
 	SetDimLabel 0,2, $"ZSensor", CFCWaveNamesCallback
 	SetDimLabel 0,3, $"DefV", CFCWaveNamesCallback
 	SetDimLabel 0,4, $"Callback", CFCWaveNamesCallback

	CFCWaveNamesCallback={"XSensor","YSensor","ZSensor","DefV",""}
End

function CFCross(CFCrossSettings,CFCrossWaveNamesCallback)
	Wave CFCrossSettings
	Wave/T CFCrossWaveNamesCallback
	
	
	// Now figure out the decimation factor to give the closest sampling rate possible
	Variable DecimationFactor=Round(50000/CFCrossSettings[%$"SamplingRate_Hz"])
	Variable EffectiveSamplingRate=50000/DecimationFactor
	// How many points should we make these waves
	Variable NumPoints=Floor(CFCrossSettings[%$"TimeToCircle_s"]*EffectiveSamplingRate)
	Variable Increment=Floor(NumPoints/8)

	// Make all waves and setup the wave references.  
	Make/N=(NumPoints)/O $CFCrossWaveNamesCallback[%XSensor], $CFCrossWaveNamesCallback[%YSensor],XCommand, YCommand, $CFCrossWaveNamesCallback[%ZSensor],$CFCrossWaveNamesCallback[%DefV]
	Wave XSensor= $CFCrossWaveNamesCallback[%XSensor]
	Wave YSensor= $CFCrossWaveNamesCallback[%YSensor]
	Wave ZSensor= $CFCrossWaveNamesCallback[%ZSensor]
	Wave DefV= $CFCrossWaveNamesCallback[%DefV]
	
	
	variable MaxXDistance_Volts = CFCrossSettings[%DistanceFromCenter_m] / GV("XLVDTSens")
	variable MaxYDistance_Volts = CFCrossSettings[%DistanceFromCenter_m]  / GV("YLVDTSens")
	
	// Calculate slope for triangle wave, in terms of volts for piezo stage
	Variable TriangleSlope_X = MaxXDistance_Volts/Increment
	Variable TriangleSlope_Y = MaxYDistance_Volts/Increment
	
	// Make XVoltage Triangle Wave with second sitting at origin
	XCommand[0,Increment]= TriangleSlope_X*x
	XCommand[Increment+1,3*Increment] = MaxXDistance_Volts - TriangleSlope_X*(x-Increment)
	XCommand[3*Increment+1,4*Increment] = -MaxXDistance_Volts+TriangleSlope_X*(x-(3*Increment+1))
	XCommand[4*Increment,NumPoints-1] = 0

	// Make YVoltage Triangle Wave with first half sitting at origin
	YCommand[0,4*Increment] = 0
	YCommand[4*Increment+1,5*Increment]= TriangleSlope_Y*(x-4*Increment)
	YCommand[5*Increment,7*Increment] = MaxYDistance_Volts - TriangleSlope_Y*(x-5*Increment)
	YCommand[7*Increment+1,NumPoints-1] = -MaxYDistance_Volts+TriangleSlope_Y*(x-(7*Increment+1))

	// Now offset to center position
	XCommand+=CFCrossSettings[%CenterX_V]
	YCommand+=CFCrossSettings[%CenterY_V]

	Variable Error = 0
	// Deflection in volts.  May not need this.  I think the constant force mode is already engaged from the ramp.
	Variable Force_Volts = ForceToDeflection(CFCrossSettings[%Force_N],RelativeToCurrentDeflection=CFCrossSettings[%RelativeToCurrentDefV],Offset=CFCrossSettings[%DefVOffset])
	//ForceCommand = Force_Volts
	Error += td_stop()
	//  Setup feedback loops
	Error +=	ir_SetPISLoop(0,"Always,Never","Cypher.LVDT.X",XCommand[0],CFCrossSettings[%P_X], CFCrossSettings[%I_X], CFCrossSettings[%S_X],"ARC.Output.X",-10,150)
	Error +=	ir_SetPISLoop(1,"Always,Never","Cypher.LVDT.Y",YCommand[0],CFCrossSettings[%P_Y], CFCrossSettings[%I_Y], CFCrossSettings[%S_Y],"ARC.Output.Y",-10,150)
	Error +=	ir_SetPISLoop(2,"Always,Never","Deflection",Force_Volts,0, 2999.999, 0,"Output.Z",-10,150)	

	// Setup motion
	Error += td_xSetOutWavePair(0, "0,0", "PIDSLoop.0.Setpoint", XCommand, "PIDSLoop.1.Setpoint",YCommand,DecimationFactor)
	
	// Setup input waves for x,y,z and deflection.  After the motion is done, callback will execute
	Error += td_xSetInWavePair(0, "0,0", "Cypher.LVDT.Z", ZSensor, "Deflection", DefV,CFCrossWaveNamesCallback[%Callback], DecimationFactor)
	Error += td_xSetInWavePair(1, "0,0", "Cypher.LVDT.X", XSensor, "Cypher.LVDT.Y", YSensor, "", DecimationFactor)

	// Execute motion
	Error +=td_WriteString("Event.0", "once")

	if (Error>0)
		print "Error in CFCross: ", Error
	endif
End


Function MakeCFCrossSettingsWave([OutputWaveName])
	String OutputWaveName
	
	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="CFCrossSettings"
	EndIf

	Make/O/N=17 $OutputWaveName
	Wave CFCrossSettings=$OutputWaveName
	
	SetDimLabel 0,0, $"CenterX_V", CFCrossSettings
 	SetDimLabel 0,1, $"CenterY_V", CFCrossSettings
 	SetDimLabel 0,2, $"DistanceFromCenter_m", CFCrossSettings
 	SetDimLabel 0,3, $"TimeToCircle_s", CFCrossSettings
 	SetDimLabel 0,4, $"SamplingRate_Hz", CFCrossSettings
  	SetDimLabel 0,5, $"Force_N", CFCrossSettings
   	SetDimLabel 0,6, $"DefVOffset", CFCrossSettings
   	SetDimLabel 0,7, $"P_x", CFCrossSettings
   	SetDimLabel 0,8, $"I_x", CFCrossSettings
   	SetDimLabel 0,9, $"S_x", CFCrossSettings
   	SetDimLabel 0,10, $"P_y", CFCrossSettings
   	SetDimLabel 0,11, $"I_y", CFCrossSettings
   	SetDimLabel 0,12, $"S_y", CFCrossSettings
   	SetDimLabel 0,13, $"P_Deflection", CFCrossSettings
   	SetDimLabel 0,14, $"I_Deflection", CFCrossSettings
   	SetDimLabel 0,15, $"S_Deflection", CFCrossSettings
   	SetDimLabel 0,16, $"RelativeToCurrentDefV", CFCrossSettings

	CFCrossSettings={0,0,100e-9,1,1000,30e-9,0,0, -5.616e4, 0,0, 5.768e4, 0,0, 2999.999, 0,0}
End

Function MakeCFCrossWaveNamesCallback([OutputWaveName])
	String OutputWaveName
	
	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="CFCrossWaveNamesCallback"
	EndIf

	Make/O/T/N=5 $OutputWaveName
	Wave/T CFCrossWaveNamesCallback=$OutputWaveName
	
	SetDimLabel 0,0, $"XSensor", CFCrossWaveNamesCallback
 	SetDimLabel 0,1, $"YSensor", CFCrossWaveNamesCallback
 	SetDimLabel 0,2, $"ZSensor", CFCrossWaveNamesCallback
 	SetDimLabel 0,3, $"DefV", CFCrossWaveNamesCallback
 	SetDimLabel 0,4, $"Callback", CFCrossWaveNamesCallback

	CFCrossWaveNamesCallback={"XSensor","YSensor","ZSensor","DefV",""}
End

Function MoveToPointCF(MoveToPointCFSettings,[Callback])
	Wave MoveToPointCFSettings
	String Callback
	
	If(ParamIsDefault(Callback))
		Callback=""
	EndIf
	
	Variable XCurrentPosition_Volts = td_rv("Cypher.LVDT.X")
	Variable YCurrentPosition_Volts = td_rv("Cypher.LVDT.Y")
	Variable Error=0
	Variable Force_Volts = ForceToDeflection(MoveToPointCFSettings[%Force_N],RelativeToCurrentDeflection=MoveToPointCFSettings[%RelativeToCurrentDefV],Offset=MoveToPointCFSettings[%DefVOffset])
	
	// Stop everything and setup feedback loops for ramp
	Error += td_stop()
	Error +=	ir_SetPISLoop(2,"Always,Never","Deflection",Force_Volts,MoveToPointCFSettings[%P_Deflection], MoveToPointCFSettings[%I_Deflection], MoveToPointCFSettings[%S_Deflection],"Output.Z",-10,150)	
	Error +=	ir_SetPISLoop(0,"Always,Never","Cypher.LVDT.X",XCurrentPosition_Volts,MoveToPointCFSettings[%P_X], MoveToPointCFSettings[%I_X], MoveToPointCFSettings[%S_X],"ARC.Output.X",-10,150)
	Error +=	ir_SetPISLoop(1,"Always,Never","Cypher.LVDT.Y",YCurrentPosition_Volts,MoveToPointCFSettings[%P_Y], MoveToPointCFSettings[%I_Y], MoveToPointCFSettings[%S_Y],"ARC.Output.Y",-10,150)
	
 	// Ramp to position at constant force within the amount of time allotted
 	Error += td_SetRamp(MoveToPointCFSettings[%Time_s], "PIDSLoop.0.Setpoint", 0, MoveToPointCFSettings[%XPosition_V], "PIDSLoop.1.Setpoint", 0, MoveToPointCFSettings[%YPosition_V], "", 0, 0, Callback)
 	
	if (Error>0)
		print "Error in MoveToPointCF: ", Error
	endif

End  // Function RampToPointAtConstantForce_nm

 Function MakeMoveToPointCFSettingsWave([OutputWaveName])
	String OutputWaveName
	
	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="MoveToPointCFSettings"
	EndIf

	Make/O/N=16 $OutputWaveName
	Wave MoveToPointCFSettings=$OutputWaveName
	
	SetDimLabel 0,0, $"XPosition_V", MoveToPointCFSettings
 	SetDimLabel 0,1, $"YPosition_V", MoveToPointCFSettings
 	SetDimLabel 0,2, $"Force_N", MoveToPointCFSettings
 	SetDimLabel 0,3, $"DefVOffset", MoveToPointCFSettings
 	SetDimLabel 0,4, $"SamplingRate_Hz", MoveToPointCFSettings
  	SetDimLabel 0,5, $"Time_s", MoveToPointCFSettings
   	SetDimLabel 0,6, $"P_x", MoveToPointCFSettings
   	SetDimLabel 0,7, $"I_x", MoveToPointCFSettings
   	SetDimLabel 0,8, $"S_x", MoveToPointCFSettings
   	SetDimLabel 0,9, $"P_y", MoveToPointCFSettings
   	SetDimLabel 0,10, $"I_y", MoveToPointCFSettings
   	SetDimLabel 0,11, $"S_y", MoveToPointCFSettings
   	SetDimLabel 0,12, $"P_Deflection", MoveToPointCFSettings
   	SetDimLabel 0,13, $"I_Deflection", MoveToPointCFSettings
   	SetDimLabel 0,14, $"S_Deflection", MoveToPointCFSettings
   	SetDimLabel 0,15, $"RelativeToCurrentDefV", MoveToPointCFSettings

	MoveToPointCFSettings={0,0,30e-12,0,1000,0.25,0, -5.616e4, 0,0, 5.768e4, 0,0, 2999.999, 0,0}
End

Function ForceToDeflection(Force,[RelativeToCurrentDeflection,Offset])
	Variable Force,RelativeToCurrentDeflection,Offset
		
	If(ParamIsDefault(RelativeToCurrentDeflection))
		RelativeToCurrentDeflection=0
	EndIf
	If(ParamIsDefault(Offset))
		Offset=0
	EndIf
	
	// Asylum has a negative cantilever deflection equaling a positive force on the molecule.
	// Here, I put a negative sign to match that convention.  
	Variable Force_V=-Force/GV("SpringConstant")/GV("INVOLS")
	If(RelativeToCurrentDeflection)
		Offset=td_rv("Deflection")
	EndIf
	Force_V+=Offset
	
	Return Force_V
End

Function CopyPISLoopSettings(SourceWave,TargetWave)
	Wave SourceWave,TargetWave
	
	TargetWave[%P_x]=SourceWave[%P_x]
	TargetWave[%I_x]=SourceWave[%I_x]
	TargetWave[%S_x]=SourceWave[%S_x]
	TargetWave[%P_y]=SourceWave[%P_y]
	TargetWave[%P_y]=SourceWave[%P_y]
	TargetWave[%P_y]=SourceWave[%P_y]
	TargetWave[%P_Deflection]=SourceWave[%P_Deflection]
	TargetWave[%I_Deflection]=SourceWave[%I_Deflection]
	TargetWave[%S_Deflection]=SourceWave[%S_Deflection]
End

// Sample Position and Deflection
Function SampleZSensorCF(SampleZSettings,SampleZWavesCallback)
	Wave SampleZSettings
	Wave/T SampleZWavesCallback

	// Now figure out the decimation factor to give the closest sampling rate possible
	Variable DecimationFactor=Round(50000/SampleZSettings[%$"SamplingRate_Hz"])
	Variable EffectiveSamplingRate=50000/DecimationFactor
	// How many points should we make these waves
	Variable NumPoints=Floor(SampleZSettings[%$"Time_s"]*EffectiveSamplingRate)

	// Make all waves and setup the wave references.  
	Make/N=(NumPoints)/O $SampleZWavesCallback[%XSensor], $SampleZWavesCallback[%YSensor],XCommand, YCommand, $SampleZWavesCallback[%ZSensor],$SampleZWavesCallback[%DefV]
	Wave XSensor= $SampleZWavesCallback[%XSensor]
	Wave YSensor= $SampleZWavesCallback[%YSensor]
	Wave ZSensor= $SampleZWavesCallback[%ZSensor]
	Wave DefV= $SampleZWavesCallback[%DefV]
	
	// Circle motion waves.  Radius in volts * cos or sin(t)+center position
	XCommand = td_rv("Cypher.LVDT.X")
	YCommand = td_rv("Cypher.LVDT.Y")

	Variable Error = 0
	// Deflection in volts.  May not need this.  I think the constant force mode is already engaged from the ramp.
	Variable Force_Volts = ForceToDeflection(SampleZSettings[%Force_N],RelativeToCurrentDeflection=SampleZSettings[%RelativeToCurrentDefV],Offset=SampleZSettings[%DefVOffset])
	//ForceCommand = Force_Volts

	//  Setup feedback loops
	Error += td_stop()
	Error +=	ir_SetPISLoop(2,"Always,Never","Deflection",Force_Volts,SampleZSettings[%P_Deflection], SampleZSettings[%I_Deflection], SampleZSettings[%S_Deflection],"Output.Z",-10,150)	
	Error +=	ir_SetPISLoop(0,"Always,Never","Cypher.LVDT.X",XCommand[0],SampleZSettings[%P_X], SampleZSettings[%I_X], SampleZSettings[%S_X],"ARC.Output.X",-10,150)
	Error +=	ir_SetPISLoop(1,"Always,Never","Cypher.LVDT.Y",YCommand[0],SampleZSettings[%P_Y], SampleZSettings[%I_Y], SampleZSettings[%S_Y],"ARC.Output.Y",-10,150)

	// Setup motion
	Error += td_xSetOutWavePair(0, "0,0", "PIDSLoop.0.Setpoint", XCommand, "PIDSLoop.1.Setpoint",YCommand,DecimationFactor)
	//Error+= td_xSetOutWave(1, "0,0", "PIDSLoop.2.Setpoint", ForceCommand, 100)
	
	// Setup input waves for x,y,z and deflection.  After the motion is done, callback will execute
	Error += td_xSetInWavePair(0, "0,0", "Cypher.LVDT.Z", ZSensor, "Deflection", DefV,SampleZWavesCallback[%Callback], DecimationFactor)
	Error += td_xSetInWavePair(1, "0,0", "Cypher.LVDT.X", XSensor, "Cypher.LVDT.Y", YSensor, "", DecimationFactor)

	// Execute motion
	Error +=td_WriteString("Event.0", "once")

End // SamplePosAndDef

Function MakeSampleZWavesCallback([OutputWaveName])
	String OutputWaveName
	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="SampleZCFWaveNamesCallback"
	EndIf
	
	MakeCFCWaveNamesCallback(OutputWaveName=OutputWaveName)
End

 Function MakeSampleZSettingsWave([OutputWaveName])
	String OutputWaveName
	
	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="SampleZSettings"
	EndIf

	Make/O/N=14 $OutputWaveName
	Wave SampleZSettings=$OutputWaveName
	
 	SetDimLabel 0,0, $"Force_N", SampleZSettings
 	SetDimLabel 0,1, $"DefVOffset", SampleZSettings
 	SetDimLabel 0,2, $"SamplingRate_Hz", SampleZSettings
  	SetDimLabel 0,3, $"Time_s", SampleZSettings
   	SetDimLabel 0,4, $"P_x", SampleZSettings
   	SetDimLabel 0,5, $"I_x", SampleZSettings
   	SetDimLabel 0,6, $"S_x", SampleZSettings
   	SetDimLabel 0,7, $"P_y", SampleZSettings
   	SetDimLabel 0,8, $"I_y", SampleZSettings
   	SetDimLabel 0,9, $"S_y", SampleZSettings
   	SetDimLabel 0,10, $"P_Deflection", SampleZSettings
   	SetDimLabel 0,11, $"I_Deflection", SampleZSettings
   	SetDimLabel 0,12, $"S_Deflection", SampleZSettings
   	SetDimLabel 0,13, $"RelativeToCurrentDefV", SampleZSettings

	SampleZSettings={30e-12,0,1000,0.25,0, -5.616e4, 0,0, 5.768e4, 0,0, 2999.999, 0,0}
End
