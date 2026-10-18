#define DR_ABILITY( y, itemID ) \
itemDef \
{ \
	visible			when( stat(tableLookup(ABILITY_TABLE, 0, itemID, 2)) != 1 && itemID != 1 ) /*locked*/ \
	rect			90 y 220 35 DR_BUTTON_ALIGN \
	style WINDOW_STYLE_SHADER \
	background "apx_button_disabled" \
	forecolor 1 1 1 1 \
	decoration \
} \
itemDef \
{ \
	visible			when( stat(tableLookup(ABILITY_TABLE, 0, itemID, 2)) == 1 || itemID == 1 ) /*unlocked*/ \
	rect			90 y 220 35 DR_BUTTON_ALIGN \
	style WINDOW_STYLE_SHADER \
	background "apx_button_idle" \
	forecolor 1 1 1 1 \
	decoration \
} \
itemDef \
{ \
	visible			when( localVarString(ui_apx_hover) == itemID && ( stat(tableLookup(ABILITY_TABLE, 0, itemID, 2)) == 1 || itemID == 1 ) ) /*unlocked*/ \
	rect			90 y 220 35 DR_BUTTON_ALIGN \
	style WINDOW_STYLE_SHADER \
	background "apx_button_hover" \
	forecolor 1 1 1 1 \
	decoration \
} \
itemDef \
{ \
	rect			95 (y+1) 55 35 DR_BUTTON_ALIGN \
	style			WINDOW_STYLE_SHADER \
	exp				material( tablelookup(ABILITY_TABLE, 0, itemID, 4) ) \
	visible			when( stat(tableLookup(ABILITY_TABLE, 0, itemID, 2)) == 1 || itemID == 1 ) /*unlocked*/ \
	forecolor		1 1 1 1 \
	decoration \
} \
itemDef \
{ \
	rect			95 (y+1) 55 35 DR_BUTTON_ALIGN \
	style			WINDOW_STYLE_SHADER \
	exp				material( tablelookup(ABILITY_TABLE, 0, itemID, 4) ) \
	visible			when( stat(tableLookup(ABILITY_TABLE, 0, itemID, 2)) != 1 && itemID != 1 ) /*locked*/ \
	forecolor		0.8 0.8 0.8 0.6 \
	decoration \
} \
itemDef \
{ \
	style		WINDOW_STYLE_FILLED \
	rect		90 y 220 35 DR_BUTTON_ALIGN \
	forecolor	1 1 1 0.8 \
	exp			text( tableLookup(ABILITY_TABLE, 0, itemID, 5) ) \
	type		ITEM_TYPE_BUTTON \
	textfont	UI_FONT_NORMAL \
	textstyle	ITEM_TEXTSTYLE_SHADOWED \
	textalign	ITEM_ALIGN_LEFT \
	textscale	0.32 \
	textalignx	70 \
	textaligny	22 \
	visible		when( stat(tableLookup(ABILITY_TABLE, 0, itemID, 2)) == 1 || itemID == 1 ) /*unlocked*/ \
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
	rect		90 y 220 35 DR_BUTTON_ALIGN \
	forecolor	0.8 0.8 0.8 0.6 \
	exp			text( tableLookup(ABILITY_TABLE, 0, itemID, 5) ) \
	type		ITEM_TYPE_TEXT \
	textfont	UI_FONT_NORMAL \
	textstyle	ITEM_TEXTSTYLE_SHADOWED \
	textalign	ITEM_ALIGN_LEFT \
	textscale	0.32 \
	textalignx	70 \
	textaligny	22 \
	visible		when( stat(tableLookup(ABILITY_TABLE, 0, itemID, 2)) != 1 && itemID != 1 ) /*locked*/ \
} \
itemDef \
{ \
	visible		1 \
	rect		90 y 220 35 DR_BUTTON_ALIGN \
	textscale	0.18 \
	textalignx	70 \
	textaligny	33 \
	forecolor	1 1 1 0.8 \
	exp			text( tableLookup(ABILITY_TABLE, 0, itemID, 6) ) \
	textfont	UI_FONT_NORMAL \
	textalign	ITEM_ALIGN_LEFT \
	textscale	0.2 \
	decoration \
} \
itemDef \
{ \
	visible		when( rank < tableLookup(ABILITY_TABLE, 0, itemID, 2) && itemID != 1 ) /*locked*/ \
	origin		308 y \
	textscale	0.22 \
	textaligny	11 \
	forecolor	1 1 1 0.8 \
	exp			text( "^1LOCKED" ) \
	textfont	UI_FONT_NORMAL \
	textalign	ITEM_ALIGN_RIGHT \
	textscale	0.2 \
	decoration \
} \
itemDef \
{ \
	visible		when( stat(tableLookup(ABILITY_TABLE, 0, itemID, 2)) == 1 || itemID == 1 ) /*unlocked*/ \
	origin		308 y \
	textscale	0.22 \
	textaligny	11 \
	forecolor	1 1 1 0.8 \
	exp			text( "^2UNLOCKED" ) \
	textfont	UI_FONT_NORMAL \
	textalign	ITEM_ALIGN_RIGHT \
	textscale	0.2 \
	decoration \
}


// 20 sprays - 96x90
// 25 sprays = 96x72
