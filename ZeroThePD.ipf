#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=1.0

// This is Rob Walder's zero the pd proc
// This hacks the zeropd user callback that asylum has built into to the cypher software.
// I also run a background process to engage the callback when zeropd hangs
// the callback then deactivates the background process and executes the user callback.

Menu "Zero the PD"
	"Initialize Zero the PD", InitZeroThePD()
	"Show Zero the PD Panel", Execute "ZeroThePDPanel()"
End



// Initialize Zero the PD
Function InitZeroThePD()
	NewDataFolder/O root:ZeroThePD
	MakeZeroPDSettingsWave(OutputWaveName="root:ZeroThePD:ZeroThePDSettingsWave")
	MakeZeroPDCallbackWave(OutputWaveName="root:ZeroThePD:ZeroThePDCallbackWave")
	Execute/Q "ZeroThePDPanel()"
End

// Main function for zero the pd.  use this for the most part.
Function DoZeroPD([ManualOverride,Callback])
	Variable ManualOverride
	String Callback
	Wave ZeroThePDSettingsWave=root:ZeroThePD:ZeroThePDSettingsWave
	Wave/T ZeroThePDCallbackWave=root:ZeroThePD:ZeroThePDCallbackWave

	If(ParamIsDefault(ManualOverride))
		ManualOverride=0
	EndIF
	If(ParamIsDefault(Callback))
		Callback=ZeroThePDCallbackWave[%Callback]
	EndIF
	
	// See if the deflection is in our user determined range.
	Variable CurrentDefVolts=td_rv("Deflection")
	Variable InRange=(CurrentDefVolts>ZeroThePDSettingsWave[%LowDefV])&&(CurrentDefVolts<ZeroThePDSettingsWave[%HighDefV])
	// We will zero the pd if it is outside our deflection range, if we manually override the counters, or if the we have reached the iteration to zero the p
	If(!InRange||ManualOverride||ZeroThePDSettingsWave[%CurrentIteration]==ZeroThePDSettingsWave[%NextZeroPDIteration])
		ZeroThePDSettingsWave[%NextZeroPDIteration]=ZeroThePDSettingsWave[%CurrentIteration]+ZeroThePDSettingsWave[%ZeroEveryXIterations]
		ZeroThePDSettingsWave[%LastZeroPDIteration]=ZeroThePDSettingsWave[%CurrentIteration]
		ZeroThePDSettingsWave[%CurrentIteration]+=1
		ZeroThePDSettingsWave[%MonitorCount]=0
		// Activates background monitor.  Prevents the program from getting stuck when ZeroPD hangs
		ARBackground("MonitorZeroPD",2,"")
		// Zero the pd
		ZeroThePD(Callback)
	Else
		// If we don't zero the pd, increase the counter by one and then execute the callback
		ZeroThePDSettingsWave[%CurrentIteration]+=1
		Execute Callback
	EndIf
	
End

// Zero the pd function.  Hacks the AR user callback system to execute our callback when zeropd is done
Function ZeroThePD(Callback)
	String Callback
	ARCheckFunc("ARUserCallbackMasterCheck_1",1)
	ARCheckFunc("ARUserCallbackPDMotorCheck_1",1)
	Wave/T GVD=root:Packages:MFP3D:Main:Variables:GeneralVariablesDescription
	String RealCallback="ZeroThePDCallback(\""+Callback+"\")"
	GVD[%ARUserCallbackPDMotor][%Description]=RealCallback
	//ZeroPD()
End
// callback for zero the pd.  
Function ZeroThePDCallback(Callback)
	String Callback
	// Deactivate the background monitor
	ARBackground("MonitorZeroPD",0,"")
	// Deactivate user callbacks.  This ensures that when we click zero pd on the sum and deflection meter, it operates normally.
	ARCheckFunc("ARUserCallbackMasterCheck_1",0)
	ARCheckFunc("ARUserCallbackPDMotorCheck_1",0)
	Wave/T GVD=root:Packages:MFP3D:Main:Variables:GeneralVariablesDescription
	GVD[%ARUserCallbackPDMotor][%Description]=""
	// execute the callback
	Execute Callback
End
// Background process
Function MonitorZeroPD()
	Wave ZeroThePDSettingsWave=root:ZeroThePD:ZeroThePDSettingsWave
	// Increases monitor count by one.  
	ZeroThePDSettingsWave[%MonitorCount]+=1
	// If monitor counter is above the max allowed, zeropd is hanging.  time to fix it.
	If (ZeroThePDSettingsWave[%MonitorCount]>ZeroThePDSettingsWave[%MaxMonitorCount]) 
		// stop everything, including zeropd.
		td_Stop()
		Wave/T ZeroThePDCallbackWave=root:ZeroThePD:ZeroThePDCallbackWave
		// engage the zerothepd callback.
		ZeroThePDCallback(ZeroThePDCallbackWave[%Callback])
		Return 1  // Forces this background process to stop
	EndIf
	
	Return 0 // Must return 0 to keep background process repeating.

End




 Function MakeZeroPDSettingsWave([OutputWaveName])
	String OutputWaveName
	
	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="ZeroThePDSettings"
	EndIf

	Make/O/N=8 $OutputWaveName
	Wave ZeroThePDSettings=$OutputWaveName
	
	SetDimLabel 0,0, $"CurrentIteration", ZeroThePDSettings
 	SetDimLabel 0,1, $"LowDefV", ZeroThePDSettings
  	SetDimLabel 0,2, $"HighDefV", ZeroThePDSettings
	SetDimLabel 0,3, $"ZeroEveryXIterations", ZeroThePDSettings
	SetDimLabel 0,4, $"LastZeroPDIteration", ZeroThePDSettings
	SetDimLabel 0,5, $"NextZeroPDIteration", ZeroThePDSettings
	SetDimLabel 0,6, $"MonitorCount", ZeroThePDSettings
	SetDimLabel 0,7, $"MaxMonitorCount", ZeroThePDSettings

	ZeroThePDSettings={0,-0.2,0.2,10,0,10,0,12}
End

 Function MakeZeroPDCallbackWave([OutputWaveName])
	String OutputWaveName
	
	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="ZeroThePDCallback"
	EndIf

	Make/O/T/N=1 $OutputWaveName
	Wave/T ZeroThePDCallback=$OutputWaveName
	
	SetDimLabel 0,0, $"Callback", ZeroThePDCallback

	ZeroThePDCallback={""}
End

Window ZeroThePDPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(1508,57,1664,286) as "ZeroThePD"
	Button ZeroThePD_Button,pos={3,151},size={144,22},proc=ZeroThePDButtonProc,title="Zero PD"
	SetVariable CurrentIterationSV,pos={6,36},size={140,16},title="Current Iteration"
	SetVariable CurrentIterationSV,limits={0,inf,1},value= root:ZeroThePD:ZeroThePDSettingsWave[%CurrentIteration]
	SetVariable LowDeflectionSV,pos={7,59},size={140,16},title="Low Deflection"
	SetVariable LowDeflectionSV,format="%.0W1PV"
	SetVariable LowDeflectionSV,value= root:ZeroThePD:ZeroThePDSettingsWave[%LowDefV]
	SetVariable ZeroEveryXIterationSV,pos={6,102},size={141,16},title="Zero every x iterations"
	SetVariable ZeroEveryXIterationSV,value= root:ZeroThePD:ZeroThePDSettingsWave[%ZeroEveryXIterations],noedit= 1
	TitleBox ForceClamp_TB,pos={9,7},size={111,21},title="Zero The PD Settings"
	SetVariable CallbackSV,pos={5,122},size={140,16},title="Callback"
	SetVariable CallbackSV,value= root:ZeroThePD:ZeroThePDCallbackWave[%Callback]
	SetVariable HighDeflectionSV,pos={9,79},size={140,16},title="High Deflection"
	SetVariable HighDeflectionSV,format="%.0W1PV"
	SetVariable HighDeflectionSV,value= root:ZeroThePD:ZeroThePDSettingsWave[%HighDefV]
	SetVariable LastZeroSV,pos={5,182},size={141,16},title="Last Zero Iteration"
	SetVariable LastZeroSV,value= root:ZeroThePD:ZeroThePDSettingsWave[%LastZeroPDIteration],noedit= 1
	SetVariable NextZeroSV1,pos={6,203},size={141,16},title="Next Zero Iteration"
	SetVariable NextZeroSV1,value= root:ZeroThePD:ZeroThePDSettingsWave[%NextZeroPDIteration],noedit= 1
EndMacro


Function ZeroThePDButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			
			DoZeroPD(ManualOverride=1)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
