#include "Console.au3"

Global $Array = StringSplit("Hello World AutoIT Console for Debugging", " ")

; Start Console
$console = ConsoleStart()
$console.Mode = 1 ; 1 = dark theme, 0 = white theme
ConsolePush($console, "$Array")
ConsoleOpen($console)