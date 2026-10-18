///////////////////////////////////////////////////////////////
////|         |///|        |///|       |/\  \/////  ///|  |////
////|  |////  |///|  |//|  |///|  |/|  |//\  \///  ////|__|////
////|  |////  |///|  |//|  |///|  |/|  |///\  \/  /////////////
////|          |//|  |//|  |///|       |////\    //////|  |////
////|  |////|  |//|         |//|  |/|  |/////    \/////|  |////
////|  |////|  |//|  |///|  |//|  |/|  |////  /\  \////|  |////
////|  |////|  |//|  | //|  |//|  |/|  |///  ///\  \///|  |////
////|__________|//|__|///|__|//|__|/|__|//__/////\__\//|__|////
///////////////////////////////////////////////////////////////
/*
	BraXi's Death Run Mod
	(c) 2010-2020 Paulina Sokołowska

	https://www.moddb.com/mods/braxs-death-run-mod

	Twitter: https://twitter.com/TheBraXi
	GitHub: https://github.com/BraXi/

	E-mail: paulinabraxi somewhere at gmail.com
*/

/*********** MAPVOTING ***********

	Name: DMS
	Author: Bipo
	Design: Mr-X
	Desc: Dynamic Mapvoting Script
	Date: Feb. 2011
	
All rights reserved � iNext Gaming
**********************************/


#include braxi\_common;

// ApX: vote hud implementation.

playerVisuals() {
	self setclientdvar("ui_hud_hardcore", 1);
	
		
	// BraX
	self braxi\_mod::spawnSpectator( level.spawn["spectator"].origin, level.spawn["spectator"].angles );

	self allowSpectateTeam( "allies", false );
	self allowSpectateTeam( "axis", false );
	self allowSpectateTeam( "freelook", false );
	self allowSpectateTeam( "none", true );

	for (i=0; i<=level.mapitems; i++ ) {
		self.voteitem[i] = newClientHudElem(self);
		self.voteitem[i].index = i;
		voteindex = getIndex((i-level.voteavg));
		self.voteitem[i].voteindex = voteindex;
		self.voteitem[i].x = getX(i);
		self.voteitem[i].y = getY(i);
		self.voteitem[i].elemType = "font";
		self.voteitem[i].alignX = "center";
		self.voteitem[i].alignY = "middle";
		self.voteitem[i].horzAlign = "center";
		self.voteitem[i].vertAlign = "middle";
		self.voteitem[i].color = (1, 1, 1);
		self.voteitem[i].alpha = getAlpha(i);
		self.voteitem[i].sort = 0;
		self.voteitem[i].font = "default";
		self.voteitem[i].fontScale = getFontSize(i);
		self.voteitem[i].foreground = true;
		self.voteitem[i] setText(level.maps[voteindex].visname);
		self.voteitem[i].parent = self;
		
		self.voteitem[i].votes = newClientHudElem(self);
		self.voteitem[i].votes.index = i;
		self.voteitem[i].votes.x = getX(i);
		self.voteitem[i].votes.y = getY(i)*1.75;
		self.voteitem[i].votes.elemType = "font";
		self.voteitem[i].votes.alignX = "center";
		self.voteitem[i].votes.alignY = "middle";
		self.voteitem[i].votes.horzAlign = "center";
		self.voteitem[i].votes.vertAlign = "middle";
		self.voteitem[i].votes.color = (1, 1, 0);
		self.voteitem[i].votes.alpha = getAlpha(i);
		self.voteitem[i].votes.sort = 0;
		self.voteitem[i].votes.font = "default";
		self.voteitem[i].votes.fontScale = getFontSize(i);
		self.voteitem[i].votes.foreground = true;
		self.voteitem[i].votes.value = level.maps[voteindex].votes;
		self.voteitem[i].votes setValue(level.maps[voteindex].votes);
	}
}

playerDelVisuals() {
	self endon("disconnect");

	//BraX - this gave runtime errors when bots were enabled...
	for (i=0; i<=level.mapitems; i++ ) 
	{
		self.voteitem[i] FadeOverTime(1);
		self.voteitem[i].alpha = 0;
		
		self.voteitem[i].votes FadeOverTime(1);
		self.voteitem[i].votes.alpha = 0;
	}
	
	if (isdefined(self.startvote))
	self.startvote destroy();
	
	wait 1;
	for (i=0; i<=level.mapitems; i++ ) {
		self.voteitem[i].votes destroy();
		self.voteitem[i] destroy();
	}
	


}

getIndex(i) {
	if( !isDefined( level.maps ) || !level.maps.size ) return 0;
	return ((int(i) % level.maps.size) + level.maps.size) % level.maps.size;
}

updateVotes() {
	for (i=0; i<=level.mapitems; i++ ) {
		val = level.maps[self.voteitem[i].voteindex].votes;
		if (val != self.voteitem[i].votes.value) {
			self.voteitem[i].votes.value = val;
			self.voteitem[i].votes setValue(val);
		}
	
	}
}

nextIndex() {
	self endon("death");
	
	if (self.index==0) {
		index = level.mapitems+1;
		self.voteIndex = getIndex(self.parent.voteindex+level.votesup);
		map = level.maps[self.voteIndex];
		self setText(map.visname);
		self.votes.value = map.votes;
		self.votes setValue(map.votes);
	
		self.fontScale = getFontSize(index);
		self.votes.fontScale = self.fontScale;
		self.alpha = getAlpha(index);
		self.votes.alpha = self.alpha;
		self.x = getX(index);
		self.y = getY(index);
		self.votes.x = self.x;
		self.votes.y = self.y*1.75;
		self.index = index;
	}
	self.index-=1;

	self MoveOverTime( level.voteswitchtime );
	self.votes MoveOverTime( level.voteswitchtime );
	
	self FadeOverTime(level.voteswitchtime);
	self.votes FadeOverTime(level.voteswitchtime);
	
	self thread scaleFont(getFontSize(self.index), level.voteswitchtime);
	self.votes thread scaleFont(getFontSize(self.index), level.voteswitchtime);
	
	self.alpha = getAlpha(self.index);
	self.votes.alpha = getAlpha(self.index);
	
	self.x = getX(self.index);
	self.y = getY(self.index);
	self.votes.x = self.x;
	self.votes.y = self.y*1.75;
}

prevIndex() {
	self endon("death");
	
	if (self.index>level.mapitems) {
		index = 0;
		self.voteIndex = getIndex(self.parent.voteindex-level.voteavg+1);
		map = level.maps[self.voteIndex];
		self setText(map.visname);
		self.votes.value = map.votes;
		self.votes setValue(map.votes);
	
		self.fontScale = getFontSize(index);
		self.votes.fontScale = self.fontScale;
		self.alpha = getAlpha(index);
		self.votes.alpha = self.alpha;
		self.x = getX(index);
		self.y = getY(index);
		self.votes.x = self.x;
		self.votes.y = self.y*1.75;
		self.index = index;
	} 

	self.index+=1;

	self MoveOverTime( level.voteswitchtime );
	self.votes MoveOverTime( level.voteswitchtime );
	
	self FadeOverTime(level.voteswitchtime);
	self.votes FadeOverTime(level.voteswitchtime);
	
	self thread scaleFont(getFontSize(self.index), level.voteswitchtime);
	self.votes thread scaleFont(getFontSize(self.index), level.voteswitchtime);
	
	self.alpha = getAlpha(self.index);
	self.votes.alpha = getAlpha(self.index);
	
	self.x = getX(self.index);
	self.y = getY(self.index);
	self.votes.x = self.x;
	self.votes.y = self.y*1.75;
	

}

scaleFont(new,time) {
	self endon("death");
	
	dif = (new-self.fontScale)/(20*time);
	for (i=0; i<time*20; i++) {
	self.fontScale += dif;
	wait 0.05;
	}
}

getFontSize(i) {
	return 3.5 - abs(i-level.voteavg)*4/(level.mapitems+1);
}

getAlpha(i) {
	return 1 - abs(i-level.voteavg)*(2*level.alphaintensity)/(level.mapitems+1);
}

getX(i) {
	return (480/(level.mapitems-1))*(i-level.voteavg);
}

getY(i) {
	return 64 - abs(i-level.voteavg)*56/(level.mapitems);
}

createVisuals() {
	level.blackbg = newHudElem();
	level.blackbg.x = 0;
	level.blackbg.y = 0;
	level.blackbg.width = 920;
	level.blackbg.height = 240;
	level.blackbg.alignX = "center";
	level.blackbg.alignY = "top";
	level.blackbg.horzAlign = "center";
	level.blackbg.vertAlign = "middle";
	level.blackbg.color = (0, 0, 0);
	level.blackbg.alpha = .7;
	level.blackbg.sort = -2;
	level.blackbg.foreground = false;
	level.blackbg setShader( "white", level.blackbg.width, level.blackbg.height );
	
	level.blackbgtop = newHudElem();
	level.blackbgtop.x = 0;
	level.blackbgtop.y = 0;
	level.blackbgtop.width = 920;
	level.blackbgtop.height = 64;
	level.blackbgtop.alignX = "center";
	level.blackbgtop.alignY = "top";
	level.blackbgtop.horzAlign = "center";
	level.blackbgtop.vertAlign = "top";
	level.blackbgtop.color = (0, 0, 0);
	level.blackbgtop.alpha = .7;
	level.blackbgtop.sort = -2;
	level.blackbgtop.foreground = false;
	level.blackbgtop setShader( "white", level.blackbgtop.width, level.blackbgtop.height );
	
	
	level.blackbar = newHudElem();
	level.blackbar.x = 0;
	level.blackbar.y = 0;
	level.blackbar.width =  920;
	level.blackbar.height =  2;
	level.blackbar.alignX = "center";
	level.blackbar.alignY = "middle";
	level.blackbar.horzAlign = "center";
	level.blackbar.vertAlign = "middle";
	level.blackbar.color = (.1, .1, .1);
	level.blackbar.alpha = 1;
	level.blackbar.sort = -2;
	level.blackbar.foreground = false;
	level.blackbar setShader( "white", level.blackbar.width, level.blackbar.height );
	
	
	level.blackbartop = newHudElem();
	level.blackbartop.x = 0;
	level.blackbartop.y = 64;
	level.blackbartop.width =  920;
	level.blackbartop.height =  2;
	level.blackbartop.alignX = "center";
	level.blackbartop.alignY = "middle";
	level.blackbartop.horzAlign = "center";
	level.blackbartop.vertAlign = "top";
	level.blackbartop.color = (.1, .1, .1);
	level.blackbartop.alpha = 1;
	level.blackbartop.sort = -2;
	level.blackbartop.foreground = false;
	level.blackbartop setShader( "white", level.blackbartop.width, level.blackbartop.height );
	
	
	level.winningtxt = newHudElem();
	level.winningtxt.x = 0;
	level.winningtxt.y = 96;
	level.winningtxt.elemType = "font";
	level.winningtxt.alignX = "center";
	level.winningtxt.alignY = "middle";
	level.winningtxt.horzAlign = "center";
	level.winningtxt.vertAlign = "top";
	level.winningtxt.color = (1, 1, 1);
	level.winningtxt.alpha = 1;
	level.winningtxt.sort = 0;
	level.winningtxt.font = "objective";
	level.winningtxt.fontScale = 2.5;
	level.winningtxt.foreground = true;
	level.winningtxt.glowcolor = (1,0,0);
	level.winningtxt.glowalpha = .7;
	level.winningtxt setText("Winning Map:");
	
	
	level.winningmap = newHudElem();
	level.winningmap.x = 0;
	level.winningmap.y = 128;
	level.winningmap.elemType = "font";
	level.winningmap.alignX = "center";
	level.winningmap.alignY = "middle";
	level.winningmap.horzAlign = "center";
	level.winningmap.vertAlign = "top";
	level.winningmap.color = (1, 1, 1);
	level.winningmap.alpha = 1;
	level.winningmap.sort = 0;
	level.winningmap.font = "objective";
	level.winningmap.fontScale = 2.5;
	level.winningmap.foreground = true;
	level.winningmap.glowcolor = (1,0,0);
	level.winningmap.glowalpha = .6;
	level.winningmap.label = &"MAPVOTE_WAIT4VOTES";
	level.winningmap setText("");
}

delVisuals() {
	for (i=0; i<level.votingplayers.size; i++) {
		if (isdefined(level.votingplayers[i])) {
			level.votingplayers[i] thread playerDelVisuals();
		}
	}

	level.blackbg fadeovertime(1);
	level.blackbgtop fadeovertime(1);
	level.blackbar fadeovertime(1);
	level.blackbartop fadeovertime(1);
	level.winningtxt fadeovertime(2);
	level.winningmap fadeovertime(2);

	level.blackbg.alpha = 0;
	level.blackbgtop.alpha = 0;
	level.blackbar.alpha = 0;
	level.blackbartop.alpha = 0;
	level.winningtxt.alpha = 0;
	level.winningmap.alpha = 0;
	
	wait 2;
	
	level.blackbg destroy();
	level.blackbgtop destroy();
	level.blackbar destroy();
	level.blackbartop destroy();
	level.winningtxt destroy();
	level.winningmap destroy();

}

updateWinningMap() {
	level endon("post_mapvote");
	while (1) {
		mostvotes = level.maps[0].votes;
		lastindex = 0;
		for (i=1; i<level.maps.size; i++) {
			if (level.maps[i].votes > mostvotes) {
				mostvotes = level.maps[i].votes;
				lastindex = i;
			}
		
		}
		
		if (mostvotes != 0) {
			level.winningmap.label = &"";
			level.winningmap setText(level.maps[lastindex].visname);	
		}
		
		
		wait 0.5;
	}
}
