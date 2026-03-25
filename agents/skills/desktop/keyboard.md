<usage>
Run scripts/keyboard.sh type "text" or scripts/keyboard.sh key "combo". Combos use + separator: ctrl+s, alt+F4, ctrl+shift+t.
</usage>

<pitfalls>
Types into whatever window is currently focused — always screenshot first to verify target. Never type secrets into unverified windows. The script normalizes common key aliases (ctrl, alt, shift, super, enter, esc, backspace). On macOS, uses osascript key events. On Linux, uses wtype (Wayland-only). For browser typing, use the browser skill instead (more reliable, targets specific elements).
</pitfalls>
