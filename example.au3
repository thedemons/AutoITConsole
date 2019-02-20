#include <WinAPI.au3>
#include "AutoItObject_Internal.au3"
#include "Console.au3"

Global $Array2D = StringSplit("Hello World AutoIT Console for Debugging", " ")

Global $Array3D[10][5]
For $iRow = 0 To UBound($Array3D) - 1
	For $iCol = 0 To UBound($Array3D, 2) - 1
		$Array3D[$iRow][$iCol] = Random(0, 1, 1) = 1 ? Random(0, 100, 1) : _GetRandomStr(Random(5, 10, 1))
	Next
Next

$console = ConsoleStart()
ConsoleOpen($console)

Func _double($x)
	Return $x * 2
EndFunc

Func _GetRandomStr($Number)
	Local $str
	For $i = 0 To $Number - 1
		$str &= Chr(Random(65, 90, 1))
	Next
	Return $str
EndFunc