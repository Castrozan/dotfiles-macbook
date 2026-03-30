<usage>
Run scripts/mouse.sh with subcommands: click X Y, move X Y, scroll DIRECTION [AMOUNT], drag X1 Y1 X2 Y2. Click accepts --button left|right|middle and --double.
</usage>

<pitfalls>
Coordinates are absolute pixels from top-left of the display. Always take a screenshot first to identify target coordinates; never click blindly. On macOS, uses osascript mouse events. On Linux, requires ydotool and ydotoold daemon with uinput access. For browser clicks, use the browser skill instead (element-based, not coordinate-based).
</pitfalls>
