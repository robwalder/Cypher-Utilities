#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=2.0
#include ":ClosedLoopMotion"

// New for version 2.0
// Now loading settings wave from a file.
// Also setting a bunch of quick settings for different molecules.

Menu "Search for Molecule"
	"Initialize Search Grid", InitSearch(ShowUserInterface=1)
	"Show Search Grid Panel", Execute "Search_Panel()"
	"Show Search Grid Graph",ShowSearchInfo("SearchGrids")
End


Function InitSearch([ShowUserInterface])
	Variable ShowUserInterface
	If(ParamIsDefault(ShowUserInterface))
		ShowUserInterface=1
	EndIf
	
	NewDataFolder/O root:SearchGrid
	SetDataFolder root:SearchGrid
	// Load External Parm waves
	String PathIn=FunctionPath("")
	NewPath/Q/O SearchGridParms ParseFilePath(1, PathIn, ":", 1, 0) +"Parms"
	LoadWave/H/Q/O/P=SearchGridParms "SearchSettings.ibw"	
	LoadWave/H/Q/O/P=SearchGridParms "SearchQuickSettings.ibw"	
  	
      	Make/N=2/O root:SearchGrid:MoveToSpot
	Wave MoveToSpot=root:SearchGrid:MoveToSpot
 	SetDimLabel 0,0, $"CoarseSpotNumber", MoveToSpot
 	SetDimLabel 0,1, $"FineSpotNumber", MoveToSpot
	MoveToSpot={0,-1}
      	
	Make/T/O/N=2 root:SearchGrid:SearchMode
	Wave/T SearchMode=root:SearchGrid:SearchMode
    	SetDimLabel 0,0, $"CurrentMode", SearchMode
    	SetDimLabel 0,1, $"Callback", SearchMode
    	SearchMode={"Coarse",""}
	
	
      	Make/N=1/O root:SearchGrid:PreviousX
      	Make/N=1/O root:SearchGrid:PreviousY
      	Make/N=1/O root:SearchGrid:CurrentX
      	Make/N=1/O root:SearchGrid:CurrentY

	
	MakeCoarseGrid()    	
    	MakeFineGrid(0,0)
    	GoToLocation(0,0)
    	
    	DoWindow Search_Panel
	Variable UserInterfaceVisible=V_flag
	If(ShowUserInterface&&!UserInterfaceVisible)
	    	Execute "Search_Panel()"
	EndIf

End

Function/S SearchQuickSettingsList()
	Wave SearchQuickSettings=root:SearchGrid:SearchQuickSettings
	Return GetWaveDimNames(SearchQuickSettings,DimNumber=1)
End

Function ShowSearchInfo(SelectedDisplay)
	String SelectedDisplay
	Wave CoarseGridX=root:SearchGrid:CoarseGridX
	Wave CoarseGridY=root:SearchGrid:CoarseGridY
	Wave FineGridX=root:SearchGrid:FineGridX
	Wave FineGridY=root:SearchGrid:FineGridY
	Wave PreviousX=root:SearchGrid:PreviousX
	Wave PreviousY=root:SearchGrid:PreviousY
	Wave CurrentX=root:SearchGrid:CurrentX
	Wave CurrentY=root:SearchGrid:CurrentY
	
	strswitch(SelectedDisplay)
		case "SearchGrids":
			DoWindow SearchGridDisplay
			If(!V_flag)
				Display/K=1/N=SearchGridDisplay FineGridY vs FineGridX 
				AppendToGraph CoarseGridY vs CoarseGridX
				AppendToGraph PreviousY vs PreviousX
				AppendToGraph CurrentY vs CurrentX
				ModifyGraph rgb(FineGridY) = (0,65535,0)
				ModifyGraph rgb(PreviousY) = (0,0,65535)
				ModifyGraph rgb(CurrentY) = (0,0,0)
				ModifyGraph mode= 3
				ModifyGraph marker(CurrentY) = 8 
				ModifyGraph msize(CurrentY) = 4
				ModifyGraph mrkThick(CurrentY) = 1
				Label Left "Y Position (m)"
				Label bottom "X Position (m)"

			EndIf		
		
		break
	Endswitch
End

Function SearchForMolecule([FoundMolecule,Callback])
	Variable FoundMolecule
	String Callback
	
	Wave SearchSettings=root:SearchGrid:SearchSettings
	Wave/T SearchMode=root:SearchGrid:SearchMode
	If(ParamIsDefault(FoundMolecule))
		FoundMolecule=0
	EndIf
	If(ParamIsDefault(Callback))
		Callback=""
	EndIf
	
	SearchMode[%Callback]=Callback
	
	// Update current location
	Wave CurrentX = root:SearchGrid:CurrentX
      Wave CurrentY= root:SearchGrid:CurrentY
      CurrentX[0]=(td_rv("Cypher.LVDT.X")-GV("XLVDTOffset"))*GV("XLVDTSens")
      CurrentY[0]=(td_rv("Cypher.LVDT.Y")-GV("YLVDTOffset"))*GV("YLVDTSens")

	If(FoundMolecule)
		SearchMode[%CurrentMode]="StayAtThisSpot"
		SearchSettings[%LastGoodIteration]=SearchSettings[%MasterIteration]
	EndIf
	
	String CurrentSearchMode=SearchMode[%CurrentMode]
	If(SearchSettings[%HotSpotManualOverride])
		CurrentSearchMode="HotSpotManualOverride"
	EndIf
	StrSwitch(CurrentSearchMode)
		case "Coarse":
			// If we didn't find anything at this spot, move to the next coarse spot
			If(SearchSettings[%IterationsAtCurrentSpot]>=SearchSettings[%CoarseIterationsPerSpot])
				NextPosition("Coarse")
			Else
				FinishIteration()
			EndIf
		break
		case "Fine":
			// If we didn't find anything at this fine spot, move to the next fine spot
			If(SearchSettings[%IterationsAtCurrentSpot]>=SearchSettings[%FineIterationsPerSpot])
				NextPosition("Fine")
			Else
				FinishIteration()
			EndIf
		break
		case "StayAtThisSpot":
			Variable IterationsSinceHit=SearchSettings[%MasterIteration]-SearchSettings[%LastGoodIteration]
			// If this hotspot is cold then go to another spot.  Use a fine search, if the user wants that.
			If(IterationsSinceHit>SearchSettings[%IterationsAtHotSpot])
				If(SearchSettings[%UseFineSearch])
					Wave CurrentX = root:SearchGrid:CurrentX
				      Wave CurrentY= root:SearchGrid:CurrentY
			          	MakeFineGrid(CurrentX[0],CurrentY[0])

					SearchSettings[%FineSpotNumber]=-1
					SearchSettings[%FineLevel]+=1
					NextPosition("Fine")
				Else
					NextPosition("Coarse")
				EndIf
			Else
				FinishIteration()
			EndIf
		break
		case "HotSpotManualOverride":
			FinishIteration()
		break
	EndSwitch
	
	// Setup for next iteration
End

Function FinishIteration()
	Wave SearchSettings=root:SearchGrid:SearchSettings
	Wave/T SearchMode=root:SearchGrid:SearchMode
	SearchSettings[%IterationsAtCurrentSpot]+=1
	SearchSettings[%MasterIteration]+=1
	
	Execute	SearchMode[%Callback]
End

Function NextPosition(NewSearchMode)
	String NewSearchMode
	
	Wave SearchSettings=root:SearchGrid:SearchSettings
	Wave/T SearchMode=root:SearchGrid:SearchMode
	
	SearchSettings[%IterationsAtCurrentSpot]=0
	SearchSettings[%SpotNumber]+=1
	SearchMode[%CurrentMode]=NewSearchMode
	
	strswitch(NewSearchMode)
		case "Coarse":
			Wave CoarseGridX=root:SearchGrid:CoarseGridX
			Wave CoarseGridY=root:SearchGrid:CoarseGridY
			
			// Move to next coarse spot
			SearchSettings[%CoarseSpotNumber]+=1
			// If we've exceeded the number of coarse spots in the grid, go back to coarse spot 0
			Variable TotalCoarseSpots=SearchSettings[%CoarseNumX]*SearchSettings[%CoarseNumY]
			If(SearchSettings[%CoarseSpotNumber]>=TotalCoarseSpots)
				SearchSettings[%CoarseSpotNumber]=0
			EndIf
			// Reset all the fine search settings to -1
			SearchSettings[%FineSpotNumber]=-1
			SearchSettings[%FineLevel]=-1
			Variable CoarseSpotNumber=SearchSettings[%CoarseSpotNumber]
			MakeFineGrid(CoarseGridX[CoarseSpotNumber],CoarseGridY[CoarseSpotNumber])
			GoToLocation(CoarseGridX[CoarseSpotNumber],CoarseGridY[CoarseSpotNumber])
		break
		case "Fine":
			Wave FineGridX=root:SearchGrid:FineGridX
			Wave FineGridY=root:SearchGrid:FineGridY

			SearchSettings[%FineSpotNumber]+=1
			Variable FineSpotNumber=SearchSettings[%FineSpotNumber]
			Variable TotalFineSpots=SearchSettings[%FineNumX]*SearchSettings[%FineNumY]
			// If we've exceeded the number of fine spots in the grid, go to the next coarse spot
			If(SearchSettings[%FineSpotNumber]>=TotalFineSpots)
				NextPosition("Coarse")
			Else 
			// If not, go to the next fine spot
				GoToLocation(FineGridX[FineSpotNumber],FineGridY[FineSpotNumber])
			EndIf

		break
	Endswitch
	
End

Function MakeCoarseGrid()
	Wave SearchSettings=root:SearchGrid:SearchSettings
    	MakeGrid(SearchSettings[%CoarseNumX],SearchSettings[%CoarseNumY],SearchSettings[%CoarseDistX],SearchSettings[%CoarseDistY],XPosWaveName="root:SearchGrid:CoarseGridX",YPosWaveName="root:SearchGrid:CoarseGridY")
End

Function MakeFineGrid(CoarseX,CoarseY,[XPosWaveName,YPosWaveName])
	Variable CoarseX,CoarseY
	String XPosWaveName,YPosWaveName
	If(ParamIsDefault(XPosWaveName))
		XPosWaveName="root:SearchGrid:FineGridX"
	EndIf
	If(ParamIsDefault(YPosWaveName))
		YPosWaveName="root:SearchGrid:FineGridY"
	EndIf
	Wave SearchSettings=root:SearchGrid:SearchSettings
	
	Variable FineGridDistanceX=(SearchSettings[%FineNumX]-1)*SearchSettings[%FineDistX]
	Variable FineGridDistanceY=(SearchSettings[%FineNumY]-1)*SearchSettings[%FineDistY]

	Variable FineXOffset=-FineGridDistanceX/2 +CoarseX
	Variable FineYOffset=-FineGridDistanceY/2+CoarseY
	
	MakeGrid(SearchSettings[%FineNumX],SearchSettings[%FineNumY],SearchSettings[%FineDistX],SearchSettings[%FineDistY],XPosWaveName=XPosWaveName,YPosWaveName=YPosWaveName,XOffset=FineXOffset,YOffset=FineYOffset)

End
	
Function MakeGrid(NumX,NumY,XStepSize,YStepSize, [XPosWaveName,YPosWaveName,XOffset,YOffset])
	Variable NumX,NumY,XStepSize,YStepSize,XOffset,YOffset
	String XPosWaveName,YPosWaveName
	
	If(ParamIsDefault(XPosWaveName))
		XPosWaveName="XPos"
	EndIf
	If(ParamIsDefault(YPosWaveName))
		YPosWaveName="YPos"
	EndIf
	If(ParamIsDefault(XOffset))
		XOffset=0
	EndIf
	If(ParamIsDefault(YOffset))
		YOffset=0
	EndIf
	
	Variable TotalNum=NumX*NumY
	Make/O/N=(TotalNum) $XPosWaveName
	Make/O/N=(TotalNum) $YPosWaveName

	
	Wave XPos=$XPosWaveName
	Wave YPos=$YPosWaveName
	
	XPos=Mod(p,NumX)*XStepSize+XOffset
	YPos=Mod(Floor(p/NumX),NumY)*YStepSize+YOffset
	
End

Function GoToLocation(XPos,YPos)
	Variable XPos,YPos
	Wave/T SearchMode=root:SearchGrid:SearchMode
	
	Variable XPos_V=XPos/GV("XLVDTSens")+GV("XLVDTOffset")
	Variable YPos_V=YPos/GV("YLVDTSens")+GV("YLVDTOffset")
	MakeMoveToPointCLSettingsWave(OutputWaveName="root:SearchGrid:MoveSettings")
	
	Wave MoveSettings=root:SearchGrid:MoveSettings
	MoveSettings[%XPosition_V]=XPos_V
	MoveSettings[%YPosition_V]=YPos_V
	
      Wave PreviousX= root:SearchGrid:PreviousX
      Wave PreviousY= root:SearchGrid:PreviousY
	Variable NumPreviousLocations=DimSize(PreviousX,0)
	InsertPoints NumPreviousLocations,1,PreviousX,PreviousY
	PreviousX[NumPreviousLocations]=XPos
	PreviousY[NumPreviousLocations]=YPos
	
	Wave CurrentX = root:SearchGrid:CurrentX
      Wave CurrentY= root:SearchGrid:CurrentY
      CurrentX[0]=XPos
      CurrentY[0]=YPos

	MoveToPointClosedLoop(MoveSettings,Callback="FinishIteration()")
	
End

Window Search_Panel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(1214,56,1497,689) as "SearchForMolecule"
	ModifyPanel cbRGB=(52224,52224,52224)
	SetDrawLayer UserBack
	DrawLine 50,50,60,60
	DrawLine 19,207,253,207
	DrawLine 19,320,253,320
	SetDrawEnv fstyle= 1
	DrawText 19,225,"Spot Numbers"
	SetDrawEnv fstyle= 1
	DrawText 19,338,"Iteration Info"
	DrawLine 19,434,253,434
	SetDrawEnv fstyle= 1
	DrawText 19,455,"Operation Status"
	SetDrawEnv fstyle= 1
	DrawText 19,518,"Move To Spot"
	DrawLine 19,500,253,500
	SetVariable CoarseNumX,pos={24,46},size={207,16},proc=SearchSetVarProc,title="Number of X Spots"
	SetVariable CoarseNumX,limits={2,inf,1},value= root:SearchGrid:SearchSettings[%CoarseNumX]
	SetVariable CoarseNumY,pos={24,88},size={210,16},proc=SearchSetVarProc,title="Number of Y Spots"
	SetVariable CoarseNumY,limits={2,inf,1},value= root:SearchGrid:SearchSettings[%CoarseNumY]
	SetVariable CoarseDistX,pos={24,67},size={210,16},proc=SearchSetVarProc,title="Distance Between X Spots"
	SetVariable CoarseDistX,format="%.1W1Pm"
	SetVariable CoarseDistX,limits={1e-09,2e-05,1e-08},value= root:SearchGrid:SearchSettings[%CoarseDistX]
	SetVariable CoarseDistY,pos={24,111},size={209,16},proc=SearchSetVarProc,title="Distance Between Y Spots"
	SetVariable CoarseDistY,format="%.1W1Pm"
	SetVariable CoarseDistY,limits={1e-09,2e-05,1e-08},value= root:SearchGrid:SearchSettings[%CoarseDistY]
	SetVariable FineNumX,pos={28,43},size={207,16},disable=1,proc=SearchSetVarProc,title="Number of X Spots"
	SetVariable FineNumX,limits={2,inf,1},value= root:SearchGrid:SearchSettings[%FineNumX]
	SetVariable FineDistX,pos={28,64},size={210,16},disable=1,proc=SearchSetVarProc,title="Distance Between X Spots"
	SetVariable FineDistX,format="%.1W1Pm"
	SetVariable FineDistX,limits={1e-09,2e-05,1e-08},value= root:SearchGrid:SearchSettings[%FineDistX]
	SetVariable FineNumY,pos={28,85},size={210,16},disable=1,proc=SearchSetVarProc,title="Number of Y Spots"
	SetVariable FineNumY,limits={2,inf,1},value= root:SearchGrid:SearchSettings[%FineNumY]
	SetVariable FineDistY,pos={28,108},size={209,16},disable=1,proc=SearchSetVarProc,title="Distance Between Y Spots"
	SetVariable FineDistY,format="%.1W1Pm"
	SetVariable FineDistY,limits={1e-09,2e-05,1e-08},value= root:SearchGrid:SearchSettings[%FineDistY]
	SetVariable CoarseIterationsPerSpot,pos={24,135},size={209,16},proc=SearchSetVarProc,title="Iterations Per Spot"
	SetVariable CoarseIterationsPerSpot,limits={1,1000,1},value= root:SearchGrid:SearchSettings[%CoarseIterationsPerSpot]
	SetVariable FineIterationsPerspot,pos={28,134},size={209,16},disable=1,title="Iterations Per Spot"
	SetVariable FineIterationsPerspot,limits={1,1000,1},value= root:SearchGrid:SearchSettings[%FineIterationsPerSpot]
	TabControl tab0,pos={19,14},size={235,157},proc=SearchTabProc
	TabControl tab0,labelBack=(47872,47872,47872),tabLabel(0)="Coarse Grid Settings"
	TabControl tab0,tabLabel(1)="Fine Grid Settings",value= 0
	CheckBox UseFineSearch,pos={19,182},size={97,14},proc=SearchCheckProc,title="Use Fine Search"
	CheckBox UseFineSearch,value= 1
	SetVariable SpotNumber,pos={19,226},size={209,16},title="SpotNumber"
	SetVariable SpotNumber,limits={1,1e+06,1},value= root:SearchGrid:SearchSettings[%SpotNumber]
	SetVariable CoarseSpotNumber,pos={19,246},size={209,16},title="Coarse Spot Number"
	SetVariable CoarseSpotNumber,limits={0,100000,1},value= root:SearchGrid:SearchSettings[%CoarseSpotNumber]
	SetVariable FineSpotNumber,pos={19,267},size={209,16},title="Fine Spot Number"
	SetVariable FineSpotNumber,limits={-1,100000,1},value= root:SearchGrid:SearchSettings[%FineSpotNumber]
	SetVariable FineLevel,pos={19,288},size={209,16},title="Fine Level"
	SetVariable FineLevel,limits={-1,100000,1},value= root:SearchGrid:SearchSettings[%FineLevel]
	SetVariable MasterIteration,pos={19,341},size={209,16},title="Master Iteration"
	SetVariable MasterIteration,limits={0,100000,1},value= root:SearchGrid:SearchSettings[%MasterIteration],noedit= 1
	SetVariable IterationsCurrentSpot,pos={19,363},size={209,16},title="Iterations at Current Spot"
	SetVariable IterationsCurrentSpot,limits={1,100000,1},value= root:SearchGrid:SearchSettings[%IterationsAtCurrentSpot],noedit= 1
	SetVariable LastGoodIteration,pos={19,386},size={209,16},title="Last Good Iteration"
	SetVariable LastGoodIteration,limits={1,100000,1},value= root:SearchGrid:SearchSettings[%LastGoodIteration],noedit= 1
	SetVariable CurrentMode,pos={19,458},size={200,16},title="Current Mode"
	SetVariable CurrentMode,value= root:SearchGrid:SearchMode[%CurrentMode]
	SetVariable Callback,pos={19,477},size={200,16},title="Callback"
	SetVariable Callback,help={"Executes this function after moving to the next spot"}
	SetVariable Callback,value= root:SearchGrid:SearchMode[%Callback]
	SetVariable CoarseSpotNumber1,pos={19,519},size={209,16},title="Coarse Spot Number"
	SetVariable CoarseSpotNumber1,limits={1,100000,1},value= root:SearchGrid:MoveToSpot[%CoarseSpotNumber]
	SetVariable FineSpotNumber1,pos={19,540},size={209,16},title="Fine Spot Number"
	SetVariable FineSpotNumber1,help={"Put -1 to not use a fine position"}
	SetVariable FineSpotNumber1,limits={-1,100000,1},value= root:SearchGrid:MoveToSpot[%FineSpotNumber]
	Button MoveToSpot,pos={19,563},size={79,27},proc=SearchButtonProc,title="Move To Spot"
	Button NextIteration,pos={103,563},size={79,27},proc=SearchButtonProc,title="Next Iteration"
	CheckBox HotSpotManualOverride,pos={129,183},size={68,14},proc=SearchCheckProc,title="Stay Here!"
	CheckBox HotSpotManualOverride,help={"This will prevent the algorithm from moving the stage from this spot.  Good if you want to keep hitting this spot."}
	CheckBox HotSpotManualOverride,value= 0
	SetVariable IterationsPerHotSpot,pos={20,407},size={209,16},title="Iterations Per Hot Spot"
	SetVariable IterationsPerHotSpot,limits={1,100000,1},value= root:SearchGrid:SearchSettings[%IterationsAtHotSpot]
	Button ShowSearchGrids,pos={184,563},size={79,27},proc=SearchButtonProc,title="Show Search"
	PopupMenu SearchGridQuckSettingsPM,pos={22,595},size={141,22},proc=SearchGridQSPopMenuProc,title="Quick Settings"
	PopupMenu SearchGridQuckSettingsPM,mode=1,popvalue="Default",value= #"SearchQuickSettingsList()"
EndMacro

Function SearchTabProc(tca) : TabControl
	STRUCT WMTabControlAction &tca

	switch( tca.eventCode )
		case 2: // mouse up
			Variable tab = tca.tab
			
			SetVariable CoarseNumX,disable= (tab!=0)
			SetVariable CoarseNumY,disable= (tab!=0)
			SetVariable CoarseDistX,disable= (tab!=0)
			SetVariable CoarseDistY,disable= (tab!=0)
			SetVariable CoarseIterationsPerSpot,disable= (tab!=0)
			
			SetVariable FineNumX,disable= (tab!=1)
			SetVariable FineNumY,disable= (tab!=1)
			SetVariable FineDistX,disable= (tab!=1)
			SetVariable FineDistY,disable= (tab!=1)
			SetVariable FineIterationsPerspot,disable= (tab!=1)

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SearchCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba
	String CheckBoxName=cba.CtrlName

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			Wave SearchSettings=root:SearchGrid:SearchSettings

			strswitch(CheckBoxName)
				case "UseFineSearch":
					SearchSettings[%UseFineSearch]=checked
				break
				case "HotSpotManualOverride":
					SearchSettings[%HotSpotManualOverride]=checked
				break
			Endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SearchButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	String ButtonName=ba.CtrlName

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			strswitch(ButtonName)
			
				case "MoveToSpot":
					Wave MoveToSpot=root:SearchGrid:MoveToSpot
					Wave SearchSettings=root:SearchGrid:SearchSettings
					SearchSettings[%CoarseSpotNumber]=MoveToSpot[%CoarseSpotNumber]-1
					SearchSettings[%FineSpotNumber]=MoveToSpot[%FineSpotNumber]-1

					If(MoveToSpot[%FineSpotNumber]==-1)
						SearchSettings[%FineSpotNumber]=-1
						NextPosition("Coarse")
					Else
						NextPosition("Fine")
					EndIf
				break // MoveToSpot
				case "NextIteration":
					SearchForMolecule()
				break			
				case "ShowSearchGrids":
					ShowSearchInfo("SearchGrids")
				break			
				
					
			Endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SearchSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
				MakeCoarseGrid()    	
				Wave CurrentX = root:SearchGrid:CurrentX
 				Wave CurrentY= root:SearchGrid:CurrentY
				MakeFineGrid(CurrentX[0],CurrentY[0])

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SearchGridQSPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	Wave SearchQuickSettings=root:SearchGrid:SearchQuickSettings
	SetDataFolder root:SearchGrid

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			
			Duplicate/O/R=[0,*][popNum-1] SearchQuickSettings,SearchSettings
			Redimension/N=-1 SearchSettings
			// Build new grid when you select a quick setting.
			MakeCoarseGrid()    	
			Wave CurrentX = root:SearchGrid:CurrentX
 			Wave CurrentY= root:SearchGrid:CurrentY
			MakeFineGrid(CurrentX[0],CurrentY[0])

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
