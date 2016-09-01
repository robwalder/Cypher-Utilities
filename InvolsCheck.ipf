#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "::AR Data:SaveAsAsylumForceRamp" version>=2.0

// Initialize Check Invols
Function InitCheckInvols()
	NewDataFolder/O root:CheckInvols
	MakeCheckInvolsSettingsWave(OutputWaveName="root:CheckInvols:CheckInvolsSettingsWave")
	MakeCheckInvolsCallbackWave(OutputWaveName="root:CheckInvols:CheckInvolsCallbackWave")
	MakeForceRampWave(OutputWaveName="root:CheckInvols:CheckInvolsRampSettings")
	Wave CheckInvolsRampSettings=root:CheckInvols:CheckInvolsRampSettings
	CheckInvolsRampSettings[%$"Surface Trigger"]=300e-12
	CheckInvolsRampSettings[%$"Sampling Rate"]=50e3
	MakeFRWaveNamesCallback(OutputWaveName="root:CheckInvols:CheckInvolsRampWNCallback")
	Wave/T CheckInvolsRampWNCallback=root:CheckInvols:CheckInvolsRampWNCallback
	CheckInvolsRampWNCallback={"root:CheckInvols:DefV","root:CheckInvols:ZSensor","root:CheckInvols:TriggerInfo","CheckInvolsRampCallback()"}
	Execute/Q "CheckInvolsPanel()"
End

Function DoCheckInvols([Callback])
	String Callback
	Wave CheckInvolsSettingsWave=root:CheckInvols:CheckInvolsSettingsWave
	Wave/T CheckInvolsCallbackWave=root:CheckInvols:CheckInvolsCallbackWave
	Wave CheckInvolsRampSettings=root:CheckInvols:CheckInvolsRampSettings
	Wave/T CheckInvolsRampWNCallback=root:CheckInvols:CheckInvolsRampWNCallback

	If(ParamIsDefault(Callback))
		Callback=CheckInvolsCallbackWave[%Callback]
	EndIF
	
	// We will check invols if we have reached the 
	If(CheckInvolsSettingsWave[%NextCheckInvolsIteration]==CheckInvolsSettingsWave[%CurrentIteration])
		CheckInvolsSettingsWave[%NextCheckInvolsIteration]=CheckInvolsSettingsWave[%CurrentIteration]+CheckInvolsSettingsWave[%CheckInvolsEveryXIterations]
		CheckInvolsSettingsWave[%LastCheckInvolsIteration]=CheckInvolsSettingsWave[%CurrentIteration]
		CheckInvolsSettingsWave[%CurrentIteration]+=1
		StopZFeedbackLoopCI()
		DoForceRamp(CheckInvolsRampSettings,CheckInvolsRampWNCallback)
	Else
		// If we don't check the invols, increase the counter by one and then execute the callback
		CheckInvolsSettingsWave[%CurrentIteration]+=1
		Execute Callback
	EndIf
	
End

Function CheckInvolsRampCallback()
	Wave CheckInvolsSettingsWave=root:CheckInvols:CheckInvolsSettingsWave
	Wave/T CheckInvolsCallbackWave=root:CheckInvols:CheckInvolsCallbackWave
	Wave DefVolts=root:CheckInvols:DefV
	Wave ZSensorVolts=root:CheckInvols:ZSensor
	Wave/T TriggerInfo=root:CheckInvols:TriggerInfo
	Wave/T CheckInvolsRampWNCallback=root:CheckInvols:CheckInvolsRampWNCallback

	SaveAsAsylumForceRamp("CheckInvols",CheckInvolsSettingsWave[%CurrentIteration],DefVolts,ZSensorVolts,TriggerInfo=TriggerInfo)
	Execute CheckInvolsCallbackWave[%Callback]
End


 Function MakeCheckInvolsSettingsWave([OutputWaveName])
	String OutputWaveName
	
	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="CheckInvolsSettings"
	EndIf

	Make/O/N=4 $OutputWaveName
	Wave CheckInvolsSettings=$OutputWaveName
	
	SetDimLabel 0,0, $"CurrentIteration", CheckInvolsSettings
	SetDimLabel 0,1, $"CheckInvolsEveryXIterations", CheckInvolsSettings
	SetDimLabel 0,2, $"LastCheckInvolsIteration", CheckInvolsSettings
	SetDimLabel 0,3, $"NextCheckInvolsIteration", CheckInvolsSettings

	CheckInvolsSettings={0,50,0,10}
End

Function StopZFeedbackLoopCI()
	// Here we stop the z feedback loop and reset it.  Without this code, our next force ramp will just be stuck.  
	td_stop()
	ir_StopPISLoop(-2)
	Struct ARFeedbackStruct FB
	ARGetFeedbackParms(FB,"outputZ")
	FB.StartEvent = "2"
	FB.StopEvent = "3"
	String ErrorStr
	ErrorStr += ir_writePIDSloop(FB)

End



 Function MakeCheckInvolsCallbackWave([OutputWaveName])
	String OutputWaveName
	
	If(ParamIsDefault(OutputWaveName))
		OutputWaveName="CheckInvolsCallback"
	EndIf

	Make/O/T/N=1 $OutputWaveName
	Wave/T CheckInvolsCallback=$OutputWaveName
	
	SetDimLabel 0,0, $"Callback", CheckInvolsCallback

	CheckInvolsCallback={""}
End


Window CheckInvolsPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(1681,57,1874,245) as "CheckInvols"
	Button DoCheckInvolsRamp_button,pos={4,112},size={88,24},proc=CheckInvolsButtonProc,title="Do Ramp"
	SetVariable CurrentIterationSV,pos={6,36},size={181,16},title="Current Iteration"
	SetVariable CurrentIterationSV,limits={0,inf,1},value= root:CheckInvols:CheckInvolsSettingsWave[%CurrentIteration]
	SetVariable ZeroEveryXIterationSV,pos={6,57},size={181,16},title="Check invols every x iterations"
	SetVariable ZeroEveryXIterationSV,value= root:CheckInvols:CheckInvolsSettingsWave[%CheckInvolsEveryXIterations],noedit= 1
	TitleBox ForceClamp_TB,pos={9,7},size={111,21},title="Check Invols Settings"
	SetVariable CallbackSV,pos={5,82},size={181,16},title="Callback"
	SetVariable CallbackSV,value= root:CheckInvols:CheckInvolsCallbackWave[%Callback]
	SetVariable LastZeroSV,pos={5,142},size={180,16},title="Last Check Invols Iteration"
	SetVariable LastZeroSV,value= root:CheckInvols:CheckInvolsSettingsWave[%LastCheckInvolsIteration],noedit= 1
	SetVariable NextZeroSV1,pos={6,163},size={178,16},title="Next Check Invols Iteration"
	SetVariable NextZeroSV1,value= root:CheckInvols:CheckInvolsSettingsWave[%NextCheckInvolsIteration]
	Button CheckInvolsRampSettings_Button,pos={98,112},size={88,24},proc=CheckInvolsButtonProc,title="Ramp Settings"
EndMacro

Function CheckInvolsButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String ButtonName=ba.ctrlName
	Wave CheckInvolsRampSettings=root:CheckInvols:CheckInvolsRampSettings
	Wave/T CheckInvolsRampWNCallback=root:CheckInvols:CheckInvolsRampWNCallback

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			StrSwitch(ButtonName)
			case "DoCheckInvolsRamp_button": 
				DoForceRamp(CheckInvolsRampSettings,CheckInvolsRampWNCallback)		
			break
			case "CheckInvolsRampSettings_Button":
				MakeForceRampPanel(CheckInvolsRampSettings,CheckInvolsRampWNCallback,PanelName="CheckInvolsRamp",WindowName="CheckInvolsRamp")
			break
			EndSwitch
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
