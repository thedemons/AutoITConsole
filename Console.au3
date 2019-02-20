#include-once

#include <WinAPI.au3>
#include <GuiEdit.au3>
#include <GuiRichEdit.au3>
#include <Misc.au3>

#include "AutoItObject_Internal.au3"

Const $c_WhiteMode = 0
Const $c_DarkMode = 1

Const $__cBlack = 0x000000
Const $__cWhite = 0xFFFFFF
Const $__cRed = 0x0000FF
Const $__cBlue = 0xFF0000
Const $__cGreen = 0x00FF00

Const $__ERROR = "ERROR"

Func ConsoleStart()
	$Console = IDispatch()
	$Console.Mode = $c_WhiteMode
	$Console.Draw = False

	Return $Console
EndFunc

Func ConsoleOpen($Console)

	If __CheckConsole($Console) = False Then Return SetError(-1, 0, -1)

	If $Console.Draw = False Then _CS_SetupColor($Console)

	Local $iW = 1000, $iH = 600, $iPadding = 15
	Local	$tLastBreak = TimerInit()
	Local	$isEnter, 	$isHoldEnter, 	$tEnter = TimerInit()
	Local	$isUp, 		$isHoldUp, 		$tUp = TimerInit()
	Local	$isDown, 	$isHoldDown, 	$tDown = TimerInit()

	Local	$dMemory[0], $nMemCount = 0, $iIndexMemory = 0, $tempMemory = False

	$hGUI = GUICreate("Console", $iW, $iH, -1, -1, BitOR(0x00040000,0x00080000))

	$hConsole = _GUICtrlRichEdit_Create($hGUI, "", 0, 0, $iW, $iH-25, $ES_MULTILINE + 0x00200000 + $ES_AUTOVSCROLL , 0x00000200 + 0x00000200)
	_GUICtrlRichEdit_SetBkColor($hConsole, $Console.cBackground)
	_GUICtrlRichEdit_SetCharColor($hConsole, $Console.cText)
	_GUICtrlRichEdit_SetParaSpacing($hConsole, Default, .06)
    _GUICtrlEdit_SetMargins($hConsole, BitOR($EC_LEFTMARGIN, $EC_RIGHTMARGIN), 10, 0)

	GUISetState()
	_CS_Info($Console, $hConsole)

	$iLastSel = _GUICtrlRichEdit_GetSel($hConsole)[0] - 3

	While 1

		; Check for enter key
		$isEnter = _IsPressed("0D")
		$isUp = _IsPressed("26")
		$isDown = _IsPressed("28")
		$isCTRL_A = _IsPressed("11") And _IsPressed("41")

		__RemoveBreak($hConsole)
		__CheckHold($isEnter, $isHoldEnter, $tEnter)
		__CheckHold($isUp, $isHoldUp, $tUp)
		__CheckHold($isDown, $isHoldDown, $tDown)


		$iCurrentSel = _GUICtrlRichEdit_GetSel($hConsole)[0]
		$iCurrentLine = _GUICtrlRichEdit_GetLineCount($hConsole)
		$iMaxSel = _GUICtrlRichEdit_GetFirstCharPosOnLine($hConsole, $iCurrentLine) + _GUICtrlRichEdit_GetLineLength($hConsole, $iCurrentLine)
		$iRead = _GUICtrlRichEdit_GetTextInRange($hConsole, $iLastSel, $iMaxSel)

		If $isCTRL_A Then _GUICtrlRichEdit_SetSel($hConsole, $iLastSel + 3, $iMaxSel, False)

		If $isUp And $nMemCount >= 1 And $iIndexMemory > 0 Then
			_GUICtrlRichEdit_SetSel($hConsole, $iLastSel + 3, $iMaxSel, True)
			_GUICtrlRichEdit_ReplaceText($hConsole, "")
			_GUICtrlRichEdit_AppendText($hConsole, $dMemory[$iIndexMemory - 1])
			If $tempMemory = False Then $tempMemory = StringTrimLeft($iRead, 3)
			$iIndexMemory -= 1
		EndIf

		If $isDown And $nMemCount >= 1 And $iIndexMemory < $nMemCount Then
			_GUICtrlRichEdit_SetSel($hConsole, $iLastSel + 3, $iMaxSel, True)
			_GUICtrlRichEdit_ReplaceText($hConsole, "")
			_GUICtrlRichEdit_AppendText($hConsole, ($iIndexMemory = $nMemCount - 1 ? $tempMemory : $dMemory[$iIndexMemory + 1]))
			$iIndexMemory += 1
		EndIf

		If $iCurrentLine <= 2 Then
			_CS_Info($Console, $hConsole)
			ContinueLoop
		EndIf
		If $iCurrentSel - $iLastSel <= 2 Then _GUICtrlRichEdit_SetSel($hConsole, $iLastSel + 3, $iLastSel + 3)
		If StringLeft($iRead, 3) <> ">_ " Then
			_GUICtrlRichEdit_SetSel($hConsole, $iLastSel, $iCurrentSel, True)
			_GUICtrlRichEdit_ReplaceText($hConsole, ">_ ")
		EndIf

		If $isEnter And TimerDiff($tLastBreak) > 100 Then
			__RemoveBreak($hConsole)
			$dEnter = StringTrimLeft($iRead, 3)

			$tempMemory = False
			If $dEnter Then
				$result = _CS_Execute($dEnter)

				ReDim $dMemory[$nMemCount + 1]
				$dMemory[$nMemCount] = $dEnter
				$nMemCount += 1
				$iIndexMemory = $nMemCount

				If $result Then
					_GUICtrlRichEdit_SetCharColor($hConsole, $result = $__ERROR ? $Console.cErrorText : $Console.cResultText)
					_GUICtrlRichEdit_AppendText($hConsole, (StringLen($result) <= 10 ? "  ----  " : @CRLF ) & "   " & $result)
					_GUICtrlRichEdit_SetCharColor($hConsole, $Console.cText)
				EndIf
			EndIf

			_GUICtrlRichEdit_SetFont($hConsole, 11, "CONSOLAS")
			_GUICtrlEdit_AppendText($hConsole,  @CRLF & ">_ ")

			$iLastSel = _GUICtrlRichEdit_GetSel($hConsole)[0] - 3
			$tLastBreak = TimerInit()
		EndIf


		Switch GUIGetMsg()
			Case -3
				Return
		EndSwitch
	WEnd
EndFunc

Func _CS_Execute($String, $isResult = False)
	If Not $String Then Return False

	Local $result
	$String = __RemoveBlank($String)

	If StringInStr($String, "=") Then

		If StringLeft($string, 1) = "$" Then

			$strSplit = StringSplit($String, "=", 1)
			$strVariable = StringReplace( StringTrimLeft($strSplit[1], 1), " ", "")
			$strExecute = $strSplit[2]

			$result = _CS_Execute($strExecute, True)
			Assign($strVariable, $result, 2)
			If UBound($result) > 0 Then $result = _CS_Table($result)
		Else
			$result = $__ERROR
		EndIf

	ElseIf StringRegExp($String, "[\+\-\*\/](?![^\(]*\))") Then

		$strExecute = StringRegExp($String, "[\+\-\*\/](?![^\(]*\))", 3)
		$SplitExecute = StringSplit(StringRegExpReplace($String, "[\+\-\*\/](?![^\(]*\))", @LF), @LF, 1)

		For $i = 1 To $SplitExecute[0]
			$result &= _CS_Execute($SplitExecute[$i], True) & ($i < $SplitExecute[0] ? $strExecute[$i - 1] : "")
		Next

		$result = Execute($result)

	ElseIf StringRegExp($String, "[\(\)]") Then

		$strFunc = StringRegExp($string, "(.*?)(\()", 1)[0]
		$strExecute = StringTrimRight(StringRegExp($string, "(\()(.*)", 3)[1], 1)
		$strParams = StringSplit(StringRegExpReplace($strExecute, ",(?![^\(]*\))", @LF), @LF, 1)

		For $i = 1 To $strParams[0]
			$strParams[$i] = _CS_Execute($strParams[$i], True)
		Next

		$result = _CS_CallFunc($strFunc, $strParams)

	ElseIf StringLeft($String, 1) = '"' Then

		$result = StringTrimLeft($String, 1)
		$result = StringTrimRight($result, 1)

	ElseIf StringLeft($String, 1) = "$" Then

		$result = Execute($String)

		If (Not $result) And (Not IsArray($result)) And (Not IsObj($result)) Then Return False
		$result = $isResult ? $result : _CS_Table($result)

	Else
		$result = $String
		If Not StringIsDigit($result) Then $result = $__ERROR

	EndIf

;~ 		MsgBox(0,"",$result)
	Return $result
EndFunc

Func _CS_Table($result)

	Local $strResult

	If UBound($result) > 0 Then
		If UBound($result, 2) > 0 Then

			Local $iSpace[UBound($result, 2)], $iSpaceIndex = 7
			; calculate the space
			For $iRow = 0 To UBound($result) - 1
				For $iCol = 0 To UBound($result, 2) - 1
					$len = StringLen($result[$iRow][$iCol])
					$lenCol = StringLen($iCol)
					If $len + 2 > $iSpace[$iCol] Then $iSpace[$iCol] = $len + 2
					If $iCol + 2 > $iSpace[$iCol] Then $iSpace[$iCol] = $iCol + 2
				Next
				If StringLen($iRow) + 2 > $iSpaceIndex Then $iSpaceIndex = StringLen($iRow) + 2
			Next

			; header
			$strResult = "|  index" & __Space($iSpaceIndex - 5) & "|"
			For $iCol = 0 To UBound($result, 2) - 1
				$strResult &= "  " & $iCol & __Space($iSpace[$iCol] - StringLen($iCol)) & "|"
			Next
			$strResult &= @CRLF & @CRLF

			; data
			For $iRow = 0 To UBound($result) - 1
				$strResult &= "   |  " & $iRow & __Space($iSpaceIndex - StringLen($iRow)) & "|"
				For $iCol = 0 To UBound($result, 2) - 1
					$strResult &= "  " & $result[$iRow][$iCol] & __Space($iSpace[$iCol] - StringLen($result[$iRow][$iCol])) & "|"
				Next
				If $iRow <> UBound($result) - 1 Then $strResult &= @CRLF
			Next

		Else

			$strResult = "["
			For $i = 0 To UBound($result) - 1
				If IsString($result[$i]) Then $result[$i] = '"' & $result[$i] & '"'
				$strResult &= $result[$i]
				If $i <> UBound($result) - 1 Then $strResult &= ", "
			Next
			$strResult &= "]"

		EndIf
	EndIf
	If $strResult Then Return $strResult
	Return $result
EndFunc


Func _CS_CallFunc($Func, $Params = False)
	$Func = StringReplace($Func, " ", "")

	If $Params[0] = 1 And $Params[1] = "" Then Return Call($Func)
	If $Params[0] = 1 Then Return Call($Func, $Params[1])
	If $Params[0] = 2 Then Return Call($Func, $Params[1], $Params[2])
	If $Params[0] = 3 Then Return Call($Func, $Params[1], $Params[2], $Params[3])
	If $Params[0] = 4 Then Return Call($Func, $Params[1], $Params[2], $Params[3], $Params[4])
	If $Params[0] = 5 Then Return Call($Func, $Params[1], $Params[2], $Params[3], $Params[4], $Params[5])
	If $Params[0] = 6 Then Return Call($Func, $Params[1], $Params[2], $Params[3], $Params[4], $Params[5], $Params[6])
	If $Params[0] = 7 Then Return Call($Func, $Params[1], $Params[2], $Params[3], $Params[4], $Params[5], $Params[6], $Params[7])
	If $Params[0] = 8 Then Return Call($Func, $Params[1], $Params[2], $Params[3], $Params[4], $Params[5], $Params[6], $Params[7], $Params[8])
	If $Params[0] = 9 Then Return Call($Func, $Params[1], $Params[2], $Params[3], $Params[4], $Params[5], $Params[6], $Params[7], $Params[8], $Params[9])
	If $Params[0] = 10 Then Return Call($Func, $Params[1], $Params[2], $Params[3], $Params[4], $Params[5], $Params[6], $Params[7], $Params[8], $Params[9], $Params[10])

EndFunc

Func __Space($value)
	Local $space
	For $i = 1 To $value
		$space &= " "
	Next
	Return $space
EndFunc


Func __RemoveBlank($String)
	While StringLeft($String, 1) = " "
		$String = StringTrimLeft($String, 1)
	WEnd
	While StringRight($String, 1) = " "
		$String = StringTrimRight($String, 1)
	WEnd
	Return $String
EndFunc

Func __RemoveBreak($hConsole)
	$line = _GUICtrlRichEdit_GetLineCount($hConsole)
	$readLine = _GUICtrlRichEdit_GetTextInLine($hConsole, $line)
	While $readLine = "" Or StringLeft($readLine, 1) <> ">"
		If $line <= 2 Then Return
		$_sel = _GUICtrlRichEdit_GetFirstCharPosOnLine($hConsole, $line)
		_GUICtrlRichEdit_SetSel($hConsole, $_sel - 1, $_sel, True)
		_GUICtrlRichEdit_ReplaceText($hConsole, "")

		$line = _GUICtrlRichEdit_GetLineCount($hConsole)
		$readLine = _GUICtrlRichEdit_GetTextInLine($hConsole, $line)
	WEnd
EndFunc

Func _CS_Info($Console, $hConsole)
	_GUICtrlRichEdit_SetText($hConsole, "")
	_GUICtrlRichEdit_SetCharColor($hConsole, $Console.cText)
	_GUICtrlRichEdit_SetFont($hConsole, 11, "CONSOLAS")
	_GUICtrlRichEdit_InsertText($hConsole, "AutoIT Console - created by Ho Hai Dang" & @CRLF & @CRLF)
	_GUICtrlRichEdit_SetCharColor($hConsole, $Console.cText)
	_GUICtrlRichEdit_SetFont($hConsole, 11, "CONSOLAS")
	_GUICtrlRichEdit_InsertText($hConsole,">_ ")
EndFunc

Func _CS_SetupColor($Console)

	If __CheckConsole($Console) = False Then Return SetError(-1, 0, -1)
	Switch $Console.Mode
		Case $c_WhiteMode
			$Console.cBackground = $__cWhite
			$Console.cText = $__cBlack
			$Console.cErrorText = $__cRed
			$Console.cResultText = $__cBlue

		Case $c_DarkMode
			$Console.cBackground = $__cBlack
			$Console.cText = $__cWhite
			$Console.cErrorText = $__cRed
			$Console.cResultText = $__cGreen
	EndSwitch
EndFunc


Func __CheckConsole($Console)
	If Not IsObj($Console) Then Return False
	Return True
EndFunc

Func __CheckHold(ByRef $isKey, ByRef $isHold, ByRef $tKey)

	If $isKey And Not $isHold Then
		$tKey = TimerInit()
		$isHold = True
		$isKey = True
	ElseIf Not $isKey And $isHold Then
		$isHold = False
	Else
		$isKey = $isKey And TimerDiff($tKey) > 500 ? True : False
	EndIf

EndFunc