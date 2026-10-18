// PC HUD - MP

#include "ui/menudef.h"

#define TEAM_IS_MARINES		(localVarString( ui_team ) == "marines")
#define TEAM_IS_OPFOR		(localVarString( ui_team ) == "opfor")

#define RANK_ORIGIN 0 6
#define ONLINEGAME (dvarInt( "onlinegame" ) && !dvarInt( "xblive_privatematch" ) )
#define ONLINEGAME_OFFSET 10

#define FLASH_OFS 	((sin(milliseconds()/90))*2)
#define FLASH_OFS2 	((sin(milliseconds()/90))*4)

#define HUD_ALPHA 0.65
#define HUD_FOREGROUND_ALPHA 0.75
#define DPAD_ICON_ALPHA 0.65

#define NOT_SPECTATING (!spectatingClient())

#define OBJICON( teamName, idx, texture, dvarName, showValue ) \
	itemDef \
	{ \
		style			WINDOW_STYLE_SHADER \
		rect			(30*idx) -74 24 24 HORIZONTAL_ALIGN_LEFT VERTICAL_ALIGN_BOTTOM \
		exp				rect X( (30*idx) - ((FLASH_OFS) * dvarInt( dvarName+"_flash" )) ) \
		exp				rect Y( -74 - ((FLASH_OFS) * dvarInt( dvarName+"_flash" )) ) \
		exp				rect W( 24 + (FLASH_OFS2 * dvarInt( dvarName+"_flash" )) ) \
		exp				rect H( 24 + (FLASH_OFS2 * dvarInt( dvarName+"_flash" )) ) \
		origin			20 0 \
		background		texture \
		forecolor		1 1 1 0.61 \
		visible			when( dvarString( dvarName ) == showValue && team( name ) == teamName ); \
		decoration \
	}

#define	SCOREBAR_BORDER( setting, alliesColor, axisColor ) \
	itemDef \
	{ \
		style			WINDOW_STYLE_FILLED \
		rect			36 -36 80 12 HORIZONTAL_ALIGN_LEFT VERTICAL_ALIGN_BOTTOM \
		forecolor		0 0 0 0 \
		border			1 \
		bordercolor		alliesColor 1 \
		bordersize		2 \
		visible when ( (tableLookup( "mp/mapsTable.csv", 0, dvarString( "mapname" ), 1 ) == setting) && team( name ) == "TEAM_ALLIES" ); \
		decoration \
	} \
	itemDef \
	{ \
		style			WINDOW_STYLE_FILLED \
		rect			36 -36 80 12 HORIZONTAL_ALIGN_LEFT VERTICAL_ALIGN_BOTTOM \
		forecolor		0 0 0 0 \
		border			1 \
		bordercolor		axisColor 1 \
		bordersize		2 \
		visible when ( (tableLookup( "mp/mapsTable.csv", 0, dvarString( "mapname" ), 1 ) == setting) && team( name ) == "TEAM_AXIS" ); \
		decoration \
	}

#define	BOTTOM_RECT_X 0
#define	BOTTOM_RECT_Y 0

#define MINIMAP_ORIGIN 2 11
