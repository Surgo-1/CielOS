.pragma library
// Il tasto premuto (KeyEvent di Qt) come lo scrive Hyprland: «SUPER + SHIFT + S». "" se è solo un modificatore.
const NOMI = {
    [0x20]: "Space", [0x01000004]: "Return", [0x01000005]: "Return", [0x01000001]: "Tab", [0x01000007]: "Delete",
    [0x01000006]: "Insert", [0x01000010]: "Home", [0x01000011]: "End", [0x01000016]: "Prior", [0x01000017]: "Next",
    [0x01000012]: "Left", [0x01000013]: "Up", [0x01000014]: "Right", [0x01000015]: "Down", [0x01000009]: "Print",
    [0x2c]: "comma", [0x2e]: "period", [0x2f]: "slash", [0x2d]: "minus", [0x3d]: "equal", [0x3b]: "semicolon",
    [0x27]: "apostrophe", [0x5b]: "bracketleft", [0x5d]: "bracketright", [0x5c]: "backslash", [0x60]: "grave",
    [0x01000003]: "BackSpace"
};
const MOD = [0x01000020, 0x01000021, 0x01000022, 0x01000023, 0x01000053, 0x01000054, 0x01001103];

function nome(e) {
    if (MOD.indexOf(e.key) >= 0) return "";
    let t = NOMI[e.key];
    if (!t && e.key >= 0x01000030 && e.key <= 0x0100003b) t = "F" + (e.key - 0x01000030 + 1);
    if (!t && ((e.key >= 0x30 && e.key <= 0x39) || (e.key >= 0x41 && e.key <= 0x5a))) t = String.fromCharCode(e.key);
    if (!t) return "";
    const m = [];
    if (e.modifiers & 0x10000000) m.push("SUPER");       // Qt.MetaModifier
    if (e.modifiers & 0x04000000) m.push("CTRL");        // Qt.ControlModifier
    if (e.modifiers & 0x08000000) m.push("ALT");         // Qt.AltModifier
    if (e.modifiers & 0x02000000) m.push("SHIFT");       // Qt.ShiftModifier
    return [...m, t].join(" + ");
}
