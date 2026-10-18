#define rank (stat(2350)+1)
#define SPRAY_TABLE "mp/sprayTable.csv"
#define CHARACTER_TABLE "mp/characterTable.csv"
#define ITEM_TABLE "mp/itemTable.csv"
#define ABILITY_TABLE "mp/abilityTable.csv"

#ifndef DR_BUTTON_FORECOLOR
	#define DR_BUTTON_FORECOLOR 1 1 1 1
	#define DR_BUTTON_BACKCOLOR 0.4 0.4 0.4 0.4
	#define DR_BUTTON_BACKCOLOR_FOCUSED 0.4 0.4 0.4 0.3
	#define DR_BUTTON_BORDERCOLOR 0.5 0.5 0.5 0.15
#endif

#ifndef DR_BUTTON_ALIGN
	#define DR_BUTTON_ALIGN 0 0 /*HORIZONTAL_ALIGN_FULLSCREEN VERTICAL_ALIGN_FULLSCREEN*/
#endif
