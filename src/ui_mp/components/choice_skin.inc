#undef CHOICE_TEXTCOLOR
#define CHOICE_TEXTCOLOR 0.93 0.95 0.94 1

#undef CHOICE_BUTTON_BG
#define CHOICE_BUTTON_BG(itemIndex,visArg) \
itemDef \
{ \
    rect CHOICE_RECT(itemIndex) \
    style WINDOW_STYLE_SHADER \
    background "apx_button_idle" \
    forecolor 1 1 1 1 \
    visible visArg \
    decoration \
}

#undef CHOICE_HIGHLIGHT_CUSTOM
#define CHOICE_HIGHLIGHT_CUSTOM(itemIndex,foreColorArg,borderColorArg,visArg) \
itemDef \
{ \
    rect CHOICE_RECT(itemIndex) \
    style WINDOW_STYLE_SHADER \
    background "apx_button_hover" \
    forecolor 1 1 1 1 \
    visible when(localVarInt(ui_highlight) == itemIndex && localVarString(ui_choicegroup) == CHOICE_GROUP && localVarInt(ui_apx_pressed) != itemIndex) \
    decoration \
} \
itemDef \
{ \
    rect CHOICE_RECT(itemIndex) \
    style WINDOW_STYLE_SHADER \
    background "apx_button_pressed" \
    forecolor 1 1 1 1 \
    visible when(localVarInt(ui_highlight) == itemIndex && localVarString(ui_choicegroup) == CHOICE_GROUP && localVarInt(ui_apx_pressed) == itemIndex) \
    decoration \
}

#undef CHOICE_SCRIPTS_ALL
#define CHOICE_SCRIPTS_ALL(itemIndex,actionArg,onFocusArg,leaveFocusArg) \
    onFocus \
    { \
        play CHOICE_FOCUS_SOUND; \
        setLocalVarInt ui_highlight itemIndex; \
        setLocalVarString ui_choicegroup CHOICE_GROUP; \
        setLocalVarInt ui_apx_pressed -1; \
        onFocusArg \
    } \
    leaveFocus \
    { \
        setLocalVarInt ui_highlight 0; \
        setLocalVarInt ui_apx_pressed -1; \
        leaveFocusArg \
    } \
    action \
    { \
        setLocalVarInt ui_apx_pressed itemIndex; \
        play "mouse_click"; \
        actionArg; \
    }

#undef CHOICE_DBUTTON_VIS
#define CHOICE_DBUTTON_VIS(itemIndex,textArg,visArg) \
itemDef \
{ \
    rect CHOICE_RECT(itemIndex) \
    style WINDOW_STYLE_SHADER \
    background "apx_button_disabled" \
    forecolor 1 1 1 1 \
    visible visArg \
    decoration \
} \
itemDef \
{ \
    rect CHOICE_RECT(itemIndex) \
    type ITEM_TYPE_TEXT \
    exp text(textArg) \
    textfont UI_FONT_NORMAL \
    textscale CHOICE_TEXTSIZE \
    textstyle CHOICE_TEXTSTYLE \
    textalign CHOICE_TEXTALIGN \
    textalignx CHOICE_TEXT_OFFSET_X \
    forecolor CHOICE_TEXTCOLOR_DISABLED \
    visible visArg \
    decoration \
}
