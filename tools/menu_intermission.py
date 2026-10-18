"""Native ApX match report, ballot and editorial credits, using existing assets."""
import json


def build(g):
    credits=json.loads((g.ROOT/'ui/credits.json').read_text())
    def label(name,x,y,w,value,size=.24,condition='1',expr=False,color='0.88 0.91 0.9 1',align='ITEM_ALIGN_LEFT'):
        return f'''itemDef {{ name {g.q(name)} rect {x} {y} {w} 22 0 0
exp text({value if expr else g.q(value)}) textfont UI_FONT_NORMAL textscale {size}
textalign {align} textaligny 16 textstyle ITEM_TEXTSTYLE_SHADOWED forecolor {color}
visible when({condition}) decoration }}
'''
    def rect(x,y,w,h,color,condition='1'):
        return f'''itemDef {{ rect {x} {y} {w} {h} 0 0 style WINDOW_STYLE_SHADER background "white"
forecolor {color} visible when({condition}) decoration }}\n'''
    def tab(index):return f'localVarInt(apx_post_tab)=={index}'
    def credit_body(condition):
        out=label('keep',32,169,255,'KEEP',.72,condition)+label('running',32,207,255,'RUNNING.',.72,condition,color='0.88 0.77 0.53 1')
        out+=label('community',34,273,245,'One course. Countless contributors.',.23,condition)
        out+=label('gratitude',34,296,245,'Thanks for making this place yours.',.23,condition)
        out+=label('rights',34,373,242,'Built together. Credited properly.',.19,condition,color='0.57 0.65 0.66 1')
        for index,page in enumerate(credits['pages']):
            out+=g.button('credit_page_'+str(index),306+index*98,164,92,page['title'],f'setLocalVarInt apx_credit_page {index};',condition)
            out+=rect(318+index*98,190,68,1,'0.8 0.69 0.45 0.9',f'({condition}) && localVarInt(apx_credit_page)=={index}')
            for row,(role,person) in enumerate(page['roles']):
                y=204+row*36;c=f'({condition}) && localVarInt(apx_credit_page)=={index}'
                out+=label('role_'+str(index)+'_'+str(row),308,y,296,role,.155,c,color='0.75 0.65 0.45 1')
                out+=label('person_'+str(index)+'_'+str(row),308,y+14,296,person,.205,c)
        out+=label('notice',32,413,576,credits['notice'],.16,condition,color='0.57 0.65 0.66 1')
        return out

    body='APX_UI_BACKDROP("apx_menu_background")\n'
    body+=rect(16,20,608,440,'0.027 0.038 0.046 0.97')
    body+='APX_LOGO(30,27,120,60,0 0,1,1)\n'
    body+=label('eyebrow',172,28,434,'APX / AFTER THE RUN',.17,color='0.75 0.65 0.45 1')
    body+=label('title',172,49,434,'dvarString("apx_post_map")',.43,expr=True)
    body+=rect(32,101,576,1,'0.4 0.45 0.46 0.55')
    for index,name in enumerate(('Match report','Next map','Credits')):
        body+=g.button('post_tab_'+str(index),32+index*194,112,188,name,f'setLocalVarInt apx_post_tab {index};')
        body+=rect(44+index*194,138,164,1,'0.8 0.69 0.45 0.95',tab(index))

    body+=label('stat_heading',34,158,130,'CATEGORY',.17,tab(0),color='0.65 0.72 0.72 1')
    body+=label('match_heading',172,158,158,'THIS MATCH / BEST',.17,tab(0),color='0.65 0.72 0.72 1')
    body+=label('record_heading',388,158,210,'MAP RECORD',.17,tab(0),color='0.65 0.72 0.72 1')
    stats=['Kills','Deaths','Headshots','Score','Melee kills','Fastest finish']
    for index,stat in enumerate(stats):
        y=185+index*35;prefix=f'apx_post_{index}_'
        body+=rect(32,y,576,34,'0.065 0.084 0.093 0.75' if index%2==0 else '0.04 0.055 0.063 0.75',tab(0))
        body+=label('stat_'+str(index),44,y+5,120,stat,.23,tab(0))
        body+=label('player_'+str(index),172,y+1,156,f'dvarString("{prefix}player")',.21,tab(0),True)
        body+=label('value_'+str(index),172,y+15,156,f'dvarString("{prefix}value")',.19,tab(0),True,color='0.78 0.7 0.49 1')
        body+=label('record_player_'+str(index),388,y+1,205,f'dvarString("{prefix}record_player")',.21,tab(0),True)
        body+=label('record_value_'+str(index),388,y+15,144,f'dvarString("{prefix}record_value")',.19,tab(0),True,color='0.78 0.7 0.49 1')
        body+=label('new_'+str(index),548,y+15,48,'NEW',.17,f'{tab(0)} && dvarInt("{prefix}new")',color='0.65 0.84 0.73 1')
    body+=label('record_note',34,407,570,'Match leaders and map records are separate. Only completed runs count as times.',.18,tab(0))

    active=f'{tab(1)} && dvarInt("apx_post_phase")==1'
    body+=label('choose',34,158,366,'Pick the next course. Change your vote any time.',.23,active)
    for index in range(6):
        y=190+index*34;show=f'{active} && dvarInt("apx_vote_show_{index}")'
        value=f'"{index+1}   " + dvarString("apx_vote_name_{index}")'
        body+=g.button('map_'+str(index),32,y,370,value,f'scriptMenuResponse "vote:{index}";',show,True)
        body+=label('votes_'+str(index),342,y+3,48,f'dvarInt("apx_vote_count_{index}") + ""',.21,show,True,align='ITEM_ALIGN_RIGHT')
        body+=rect(43,y+25,346,1,'0.8 0.69 0.45 0.9',f'{show} && dvarInt("apx_vote_selected")=={index}')
        body+=f'execKey "{index+1}" {{ scriptMenuResponse "vote:{index}"; }}\n'
    body+=rect(420,190,188,197,'0.06 0.079 0.088 1',active)
    body+=label('clock_label',436,202,156,'VOTE CLOSES IN',.17,active,color='0.75 0.65 0.45 1')
    body+=label('clock',436,227,156,'dvarInt("apx_post_seconds") + " s"',.54,active,True)
    body+=label('leader_label',436,279,156,'NEXT UP / CURRENT LEADER',.15,active,color='0.65 0.72 0.72 1')
    body+=label('leader',436,299,156,'dvarString("apx_vote_leader")',.22,active,True)
    body+=label('total',436,337,156,'dvarInt("apx_vote_total") + " ballots cast"',.21,active,True)
    body+=g.button('clear_vote',32,402,176,'Clear my vote','scriptMenuResponse "vote:clear";',active)
    body+=label('vote_note',224,407,384,'Ties use list order. No votes: next map in rotation.',.18,active)
    inactive=f'{tab(1)} && dvarInt("apx_post_phase")!=1'
    body+=label('closed_before',34,193,570,'Voting opens after the match report.',.28,f'{inactive} && dvarInt("apx_post_phase")==0')
    body+=label('closed_after',34,193,570,'Voting is closed. The next run is loading shortly.',.28,f'{inactive} && dvarInt("apx_post_phase")==2')
    body+=credit_body(tab(2))
    body+=rect(32,438,576,1,'0.3 0.36 0.38 0.5')
    for phase,title in enumerate(('MATCH REPORT','VOTE IS OPEN','NEXT RUN')):
        body+=label('phase_clock_'+str(phase),34,441,570,g.q(title+'  /  ')+' + dvarInt("apx_post_seconds") + " s"',.18,f'dvarInt("apx_post_phase")=={phase}',True)
    source=g.menu('apx_intermission','',body,shell_on=False,onopen='setLocalVarInt apx_post_tab (dvarInt("apx_post_phase")); setLocalVarInt apx_credit_page 0;',escape='close self;')
    g.save('ui_mp/scriptmenus/apx_intermission.menu',source)

    about='APX_UI_BACKDROP("apx_menu_background")\n'+rect(16,20,608,440,'0.027 0.038 0.046 0.97')
    about+='APX_LOGO(30,27,120,60,0 0,1,1)\n'
    about+=label('about_title',172,48,424,'THE PEOPLE BEHIND THE RUN',.37)
    about+=rect(32,101,576,1,'0.4 0.45 0.46 0.55')+credit_body('1')
    about+=g.button('back_to_main',32,112,176,'Back','close self;')
    return g.menu('single_popmenu','',about,shell_on=False,onopen='setLocalVarInt apx_credit_page 0;')
