#include "ui/menudef.h"
#include "ui_mp/common_macro.inc"

#define CHOICE_SEP_1			5

#include "ui_mp/menustyle.inc"
#include "ui_mp/components/choices.inc"

// menu specifice re-positioning

#undef CHOICE_X_START
#define CHOICE_X_START			0

#undef CHOICE_Y_START
#define CHOICE_Y_START			34
	
#undef CHOICE_POPUP_BACKCOLOR
#define CHOICE_POPUP_BACKCOLOR	0.2 0.2 0.22 1 //0.15 0.15 0.155 1//0.125 0.125 0.1275 1

#undef HIGHLIGHT_COLOR
#define HIGHLIGHT_COLOR			0.9 0.95 1 0.25

#define LABEL_TEXT_COLOR		0.7 0.75 0.75 1

#define SHOW_DESC( pnum ) \
	show "desc_tier"#pnum;

#define HIDE_DESC( pnum ) \
	hide "desc_tier"#pnum; \
	hide "desc2_tier"#pnum;
	
#define SHOW_DESC2( pnum ) \
	show "desc2_tier"#pnum;

#define HIDE_DESC2( pnum ) \
	hide "desc2_tier"#pnum;	\
	hide "desc_tier"#pnum;
	
#define HIDEALL_DESC \
	HIDE_DESC( 1 ) HIDE_DESC( 6 ) HIDE_DESC( 11 ) HIDE_DESC( 16 ) \
	HIDE_DESC( 2 ) HIDE_DESC( 7 ) HIDE_DESC( 12 ) HIDE_DESC( 17 ) \
	HIDE_DESC( 3 ) HIDE_DESC( 8 ) HIDE_DESC( 13 ) \
	HIDE_DESC( 4 ) HIDE_DESC( 9 ) HIDE_DESC( 14 ) \
	HIDE_DESC( 5 ) HIDE_DESC( 10 ) HIDE_DESC( 15 )
	
#define ORIGIN_DESCRIPTION		100 320

#define LOCAL_TIER_ACTION( pnum_s, pstat ) \
	play "mouse_click"; \
	execnow "set ui_tier_num "pnum_s; \
	execnow "set ui_table_name mp/challengeTable_tier"pnum_s".csv"; \
	execnow "statset "pstat" 1"; \
	open "popup_tier"

#define LOCAL_NAME( pnum ) "@"+tablelookup("mp/challengetable.csv",0,pnum,1)

#define LOCAL_DESC( pnum ) \
	PREPROC_TEXT_DRAW_ALIGNED_EXP( ORIGIN_DESCRIPTION 220 50 CHOICE_HORIZONTAL_ALIGN VERTICAL_ALIGN_TOP, 0 0, "@"+tablelookup("mp/challengetable.csv",0,pnum,2), TEXTSIZE_SMALL, 0, 0, ITEM_ALIGN_MIDDLE_LEFT, CHOICE_TEXTCOLOR name "desc_tier"#pnum )

#define LOCAL_DESC2( pnum ) \
	PREPROC_TEXT_DRAW_ALIGNED_EXP( ORIGIN_DESCRIPTION 220 50 CHOICE_HORIZONTAL_ALIGN VERTICAL_ALIGN_TOP, 0 0, "@"+tablelookup("mp/challengetable.csv",0,pnum,3), TEXTSIZE_SMALL, 0, 0, ITEM_ALIGN_MIDDLE_LEFT, CHOICE_TEXTCOLOR name "desc2_tier"#pnum )

#define LOCAL_UNLOCK_COLOR 		0.31 0.31 0.33 0.55 //0.21 0.21 0.23 0.65



#include "ui_mp/dr_common.inc"
// ============== end init =============

