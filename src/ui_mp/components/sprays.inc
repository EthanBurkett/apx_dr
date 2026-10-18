#define DR_SPRAY( row, column, itemID ) \
itemDef \
{ \
	rect			80 90 96 72 DR_BUTTON_ALIGN \
	origin			(96*row) (72*column) \
	style			WINDOW_STYLE_SHADER \
	exp				material( tableLookup(SPRAY_TABLE, 0, itemID, 3) ) \
	visible			1 \
	border			1 \
	bordercolor		0 0 0 1 \
	decoration \
} \
itemDef \
{ \
	rect			80 90 96 72 DR_BUTTON_ALIGN \
	origin			(96*row) (72*column) \
	style			WINDOW_STYLE_SHADER \
	background		"black" \
	forecolor		0 0 0 0.8 \
	visible			when( rank < tableLookup(SPRAY_TABLE, 0, itemID, 2) ) \
	decoration \
} \
itemDef \
{ \
	visible		when( rank < tableLookup(SPRAY_TABLE, 0, itemID, 2) ) \
	rect		80 90 0 0 DR_BUTTON_ALIGN \
	origin		(96*row) (72*column) \
	textalignx	48 \
	textaligny	45 \
	forecolor	1 1 1 0.8 \
	exp			text( "^1UNLOCKED AT LEVEL" + tableLookup(SPRAY_TABLE, 0, itemID, 2) ) \
	textfont	UI_FONT_NORMAL \
	textalign	ITEM_ALIGN_CENTER \
	textscale	0.2 \
	decoration \
} \
itemDef \
{ \
	style		WINDOW_STYLE_FILLED \
	rect		80 90 95 71 DR_BUTTON_ALIGN \
	origin		(96*row) (72*column) \
	forecolor	1 1 1 0.8 \
	type		ITEM_TYPE_BUTTON \
	exp			text( " " ) \
	textfont	UI_FONT_NORMAL \
	textstyle	ITEM_TEXTSTYLE_SHADOWED \
	textalign	ITEM_ALIGN_LEFT \
	textscale	0.32 \
	textalignx	70 \
	textaligny	22 \
	visible		1 /*unlocked*/ \
	mouseEnter \
	{ \
		play "mouse_over"; \
	} \
	action \
	{ \
		scriptMenuResponse itemID; \
		close self; \
		open "character_stuff"; \
	} \
}
