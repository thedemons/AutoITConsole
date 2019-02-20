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

;~ $c = ConsoleStart()
;~ $c.Mode = 0;$c_DarkMode
;~ ConsoleOpen($c)

Func ConsoleStart()
	$Console = IDispatch()
	$Console.Mode = $c_WhiteMode
	$Console.Draw = False

	Return $Console
EndFunc

Func ConsoleOpen($Console)

	If __CheckConsole($Console) = False Then Return SetError(-1, 0, -1)

	If $Console.Draw = False Then _CS_SetupColor($Console)

	Local $iW = 1000, $iH = 500, $iPadding = 15
	Local	$tLastBreak = TimerInit(), $tEnter = TimerInit()
	Local	$isEnter, $isHold

	$hGUI = GUICreate("Console", $iW, $iH, -1, -1, BitOR(0x00040000,0x00080000))

	$hConsole = _GUICtrlRichEdit_Create($hGUI, "", 0, 0, $iW, $iH-25, $ES_MULTILINE + 0x00200000 + $ES_AUTOVSCROLL , 0x00000200 + 0x00000200)
	_GUICtrlRichEdit_SetBkColor($hConsole, $Console.cBackground)
	_GUICtrlRichEdit_SetCharColor($hConsole, $Console.cText)
    _GUICtrlEdit_SetMargins($hConsole, BitOR($EC_LEFTMARGIN, $EC_RIGHTMARGIN), 10, 0)

	GUISetState()
	_CS_Info($hConsole)

	$iLastSel = _GUICtrlRichEdit_GetSel($hConsole)[0] - 3

	While 1

		; Check for enter key
		$isEnter = _IsPressed("0D")
		$isCTRL_A = _IsPressed("11") And _IsPressed("41")

		__RemoveBreak($hConsole)
		If $isEnter And Not $isHold Then
			$tEnter = TimerInit()
			$isHold = True
			$isEnter = True
		ElseIf Not $isEnter And $isHold Then
			$isHold = False
		Else
			$isEnter = $isEnter And TimerDiff($tEnter) > 500 ? True : False
		EndIf

		If $isCTRL_A Then

		EndIf

		$iCurrentSel = _GUICtrlRichEdit_GetSel($hConsole)[0]
		$iCurrentLine = _GUICtrlRichEdit_GetLineCount($hConsole)
		$iMaxSel = _GUICtrlRichEdit_GetFirstCharPosOnLine($hConsole, $iCurrentLine) + _GUICtrlRichEdit_GetLineLength($hConsole, $iCurrentLine)
		$iRead = _GUICtrlRichEdit_GetTextInRange($hConsole, $iLastSel, $iMaxSel)

		If $iCurrentLine <= 2 Then
			_CS_Info($hConsole)
			ContinueLoop
		EndIf
		If $iCurrentSel - $iLastSel <= 2 Then _GUICtrlRichEdit_SetSel($hConsole, $iLastSel + 3, $iLastSel + 3)
		If StringLeft($iRead, 3) <> ">_ " Then
			_GUICtrlRichEdit_SetSel($hConsole, $iLastSel, $iCurrentSel, True)
			_GUICtrlRichEdit_ReplaceText($hConsole, ">_ ")
		EndIf

		If $isEnter And TimerDiff($tLastBreak) > 100 Then
			__RemoveBreak($hConsole)
			$result = _CS_Execute($Console, $hConsole, StringTrimLeft($iRead, 3))
			_GUICtrlRichEdit_SetFont($hConsole, 11, "CONSOLAS")
			_GUICtrlEdit_AppendText($hConsole,  @CRLF & ">_ ")
			$iLastSel = _GUICtrlRichEdit_GetSel($hConsole)[0] - 3
			$iCurrentSel = $iLastSel + 3
			$iCurrentLine += 1
			$iMaxSel = _GUICtrlRichEdit_GetFirstCharPosOnLine($hConsole, $iCurrentLine) + _GUICtrlRichEdit_GetLineLength($hConsole, $iCurrentLine)
			$iRead = _GUICtrlRichEdit_GetTextInRange($hConsole, $iLastSel, $iMaxSel)
			$tLastBreak = TimerInit()
		EndIf


		Switch GUIGetMsg()
			Case -3
				Exit
		EndSwitch
	WEnd
EndFunc

Func _CS_Execute($Console, $hConsole, $String)
	Local $result
	If Not $String Then Return False


	If StringInStr($String, "=") Then
		$strSplit = StringSplit($String, "=", 1)
		$strSplit[1] = StringReplace( StringTrimLeft($strSplit[1], 1), " ", "")
		$strSplit[2] = $strSplit[2]

		If StringRegExp($strSplit[2], "[()]") Then
			$strSplit2 = StringSplit(StringReplace($strSplit[2], ")", ""), "(", 1)
			If $strSplit2[2] = "" Then $strSplit2[2] = False
			$strSplit[2] = _CS_CallFunc($strSplit2[1], $strSplit2[2])
			$result = $strSplit[2]

		ElseIf StringInStr($strSplit[2], "&") Then
			$strSplitResult = StringSplit($strSplit[2], "&", 1)
			For $i = 1 To $strSplitResult[0]
				$strSplitResult[$i] = __RemoveBlank($strSplitResult[$i])
				$result &= Execute($strSplitResult[$i]) ; IsString($strSplitResult[$i]) and StringRegExp($strSplitResult[$i], "[$]") = False ? $strSplitResult[$i] : Execute($strSplitResult[$i])
				MsgBox(0,$strSplitResult[$i],Execute($strSplitResult[$i]))
			Next
		Else
			$result = Execute($strSplit[2]);IsString($strSplit[2]) and StringRegExp($strSplit[2], "[$]") = False ? $strSplit[2] : Execute($strSplit[2])
		EndIf

		If Not $result Then Return False

		Assign( $strSplit[1], $result, 2)

	ElseIf StringRegExp($String, "[+-/*]") Then
		$result = Execute($String)
		If Not $result Then Return False

	ElseIf StringInStr($String, "$") Then
		$result = Execute($String)

		If (Not $result) And (Not IsArray($result)) Then Return False

		If UBound($result) > 0 Then
			If UBound($result, 2) > 0 Then

				Local $iSpace[UBound($result, 2)], $iSpaceIndex = 7, $resultStr
				For $iRow = 0 To UBound($result) - 1
					For $iCol = 0 To UBound($result, 2) - 1
						$len = StringLen($result[$iRow][$iCol])
						$lenCol = StringLen($iCol)
						If $len + 2 > $iSpace[$iCol] Then $iSpace[$iCol] = $len + 2
						If $iCol + 2 > $iSpace[$iCol] Then $iSpace[$iCol] = $iCol + 2
					Next
					If StringLen($iRow) + 2 > $iSpaceIndex Then $iSpaceIndex = StringLen($iRow) + 2
				Next

				$resultStr = "|  index" & __Space($iSpaceIndex - 5) & "|"
				For $iCol = 0 To UBound($result, 2) - 1
					$resultStr &= "  " & $iCol & __Space($iSpace[$iCol] - StringLen($iCol)) & "|"
				Next
				$resultStr &= @CRLF & @CRLF
				For $iRow = 0 To UBound($result) - 1
					$resultStr &= "   |  " & $iRow & __Space($iSpaceIndex - StringLen($iRow)) & "|"
					For $iCol = 0 To UBound($result, 2) - 1
						$resultStr &= "  " & $result[$iRow][$iCol] & __Space($iSpace[$iCol] - StringLen($result[$iRow][$iCol])) & "|"
					Next
					If $iRow <> UBound($result) - 1 Then $resultStr &= @CRLF
				Next
				$result = $resultStr

			Else
				$strResult = "["
				For $i = 0 To UBound($result) - 1
					If IsString($result[$i]) Then $result[$i] = '"' & $result[$i] & '"'
					$strResult &= $result[$i]
					If $i <> UBound($result) - 1 Then $strResult &= ", "
				Next
				$strResult &= "]"
				$result = $strResult
			EndIf
		EndIf
	EndIf

	_GUICtrlRichEdit_SetCharColor($hConsole, 0xFF0000)
	_GUICtrlRichEdit_AppendText($hConsole, @CRLF & "   " & $result & @CRLF)
	_GUICtrlRichEdit_SetCharColor($hConsole, $Console.cText)

	Return $result
EndFunc

Func _CS_CallFunc($Func, $AllParams = False)
	$Func = StringReplace($Func, " ", "")
	If Not $AllParams Then Return Call($Func)

	$Params = StringSplit(StringRegExpReplace($AllParams, "[" & '"' & "'" & "]" , ""), ",", 1)

	For $i = 0 To $Params[0]
		If StringRegExp($Params[$i], "[$]") Then $Params[$i] = Execute($Params[$i])
	Next

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


Func __RemoveBlank($string)
	While StringLeft($string, 1) = " "
		$string = StringTrimLeft($string, 1)
	WEnd
	While StringRight($string, 1) = " "
		$string = StringTrimRight($string, 1)
	WEnd
	Return $string
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

Func _CS_Info($hConsole)
	_GUICtrlRichEdit_SetText($hConsole, "")
	_GUICtrlRichEdit_SetFont($hConsole, 11, "CONSOLAS")
	_GUICtrlRichEdit_InsertText($hConsole, "AutoIT Console - created by Ho Hai Dang" & @CRLF & @CRLF)
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
			$Console.cResultText = $__cBlue
	EndSwitch
EndFunc


Func __CheckConsole($Console)
	If Not IsObj($Console) Then Return False
	Return True
EndFunc