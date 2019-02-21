
#include "Console.au3"

; Start console
$console = ConsoleStart()

; Open console thread
ConsoleOpenThread($console)

Global $var = RandomizeArray(5, 5)

; create gui
GUICreate("Example Console Thread", 250, 50, 0, 0)

$lbText = GUICtrlCreateLabel("Thread Console", 15, 10, 350, 30)
GUICtrlSetFont(-1, 20)

GUISetState()

; show var arrays
ConsolePush($console, ">$var")

While 1
	; Keep updating console, must put this in a loops
	ConsoleUpdate($console)
	$var = RandomizeArray(5, 5)

	Switch GUIGetMsg()
		Case -3
			Exit
	EndSwitch

	Sleep(10)
WEnd


Func RandomizeArray($row, $col)
	Local $rArray[$row][$col]
	For $i = 0 To $row - 1
		For $j = 0 To $col - 1
			$rArray[$i][$j] = Round(Random(), 5)
		Next
	Next
	Return $rArray
EndFunc