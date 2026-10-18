#define DR_WEAPON2( x, y, itemID ) \
itemDef \
{ \
	visible			when( rank < tableLookup(ITEM_TABLE, 0, itemID, 2) ) /*locked*/ \
	rect			x y 220 35 DR_BUTTON_ALIGN \
	style WINDOW_STYLE_SHADER \
	background "apx_button_disabled" \
	forecolor 1 1 1 1 \
	decoration \
} \
itemDef \
{ \
	visible			when( rank >= tableLookup(ITEM_TABLE, 0, itemID, 2) ) /*unlocked*/ \
	rect			x y 220 35 DR_BUTTON_ALIGN \
	style WINDOW_STYLE_SHADER \
	background "apx_button_idle" \
	forecolor 1 1 1 1 \
	decoration \
} \
itemDef \
{ \
	visible			when( localVarString(ui_apx_hover) == itemID && ( rank >= tableLookup(ITEM_TABLE, 0, itemID, 2) ) ) /*unlocked*/ \
	rect			x y 220 35 DR_BUTTON_ALIGN \
	style WINDOW_STYLE_SHADER \
	background "apx_button_hover" \
	forecolor 1 1 1 1 \
	decoration \
} \
itemDef \
{ \
	rect			(x+2) (y+2) 60 31 DR_BUTTON_ALIGN \
	style			WINDOW_STYLE_SHADER \
	exp				material( tablelookup( "mp/itemTable.csv", 0, itemID, 3 ) ) \
	visible			when( rank >= tableLookup(ITEM_TABLE, 0, itemID, 2) ) /*unlocked*/ \
	forecolor		1 1 1 1 \
	decoration \
} \
itemDef \
{ \
	rect			(x+2) (y+2) 60 31 DR_BUTTON_ALIGN \
	style			WINDOW_STYLE_SHADER \
	exp				material( tablelookup( "mp/itemTable.csv", 0, itemID, 3 ) ) \
	visible			when( rank < tableLookup(ITEM_TABLE, 0, itemID, 2) ) /*locked*/ \
	forecolor		0.8 0.8 0.8 0.6 \
	decoration \
} \
itemDef \
{ \
	style		WINDOW_STYLE_FILLED \
	rect		x y 220 35 DR_BUTTON_ALIGN \
	forecolor	1 1 1 0.8 \
	exp			text( tableLookup(ITEM_TABLE, 0, itemID, 5) ) \
	type		ITEM_TYPE_BUTTON \
	textfont	UI_FONT_NORMAL \
	textstyle	ITEM_TEXTSTYLE_SHADOWED \
	textalign	ITEM_ALIGN_LEFT \
	textscale	0.32 \
	textalignx	70 \
	textaligny	22 \
	visible		when( rank >= tableLookup(ITEM_TABLE, 0, itemID, 2) ) /*unlocked*/ \
	onFocus { setLocalVarString ui_apx_hover itemID; } \
	leaveFocus { setLocalVarString ui_apx_hover ""; } \
	mouseEnter { setLocalVarString ui_apx_hover itemID; play "mouse_over"; } \
	mouseExit { setLocalVarString ui_apx_hover ""; } \
	action \
	{ \
		scriptMenuResponse itemID; \
		close self; \
		open "character_stuff"; \
	} \
} \
itemDef \
{ \
	style		WINDOW_STYLE_FILLED \
	rect		x y 220 35 DR_BUTTON_ALIGN \
	forecolor	0.8 0.8 0.8 0.6 \
	exp			text( tableLookup(ITEM_TABLE, 0, itemID, 5) ) \
	type		ITEM_TYPE_TEXT \
	textfont	UI_FONT_NORMAL \
	textstyle	ITEM_TEXTSTYLE_SHADOWED \
	textalign	ITEM_ALIGN_LEFT \
	textscale	0.32 \
	textalignx	70 \
	textaligny	22 \
	visible		when( rank < tableLookup(ITEM_TABLE, 0, itemID, 2) ) /*locked*/ \
} \
itemDef \
{ \
	visible		1 \
	rect		x y 220 35 DR_BUTTON_ALIGN \
	textscale	0.18 \
	textalignx	70 \
	textaligny	33 \
	forecolor	1 1 1 0.8 \
	exp			text( tableLookup(ITEM_TABLE, 0, itemID, 6) ) \
	textfont	UI_FONT_NORMAL \
	textalign	ITEM_ALIGN_LEFT \
	textscale	0.2 \
	decoration \
} \
itemDef \
{ \
	visible		when( rank < tableLookup(ITEM_TABLE, 0, itemID, 2) ) /*locked*/ \
	origin		(x+218) y \
	textscale	0.22 \
	textaligny	11 \
	forecolor	1 1 1 0.8 \
	exp			text( "^1LOCKED ("+tableLookup(ITEM_TABLE, 0, itemID, 2)+")" ) \
	textfont	UI_FONT_NORMAL \
	textalign	ITEM_ALIGN_RIGHT \
	textscale	0.2 \
	decoration \
} \
itemDef \
{ \
	visible		when( rank >= tableLookup(ITEM_TABLE, 0, itemID, 2) ) /*unlocked*/ \
	origin		(x+218) y \
	textscale	0.22 \
	textaligny	11 \
	forecolor	1 1 1 0.8 \
	exp			text( "^2UNLOCKED" ) \
	textfont	UI_FONT_NORMAL \
	textalign	ITEM_ALIGN_RIGHT \
	textscale	0.2 \
	decoration \
}
