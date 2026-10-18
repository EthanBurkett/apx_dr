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

// ApX: vote players implementation.

playerVote() {
	level endon("post_mapvote");
	self endon("disconnect");

	self.voteindex = -1;
	
	if ( issubstr(self.name, "bot") )
		return;
	
	self.changingVote = false;
	
	self braxi\_vote_hud::playerVisuals();
	self thread playerUpdateVotes();
	self playerStartVoting();
	
	//BraX
	self closeMenu();
	self closeInGameMenu();
	//<--

	abp = false;
	ads = self adsbuttonpressed();
	while(1) {
		if (ads != self adsbuttonpressed()) {
			ads = self adsbuttonpressed();
			self.changingVote = true;
			self decVote();
			wait level.voteswitchtime;
			self.changingVote = false;
		}
		if (!abp) {
			if (self attackbuttonpressed()) {
				abp = true;
			}
		} else {
			self.changingVote = true;
			self incVote();
			wait level.voteswitchtime;
			self.changingVote = false;
			if (!self attackbuttonpressed()) {
				abp = false;
			}
		}
		wait 0.05;
	}
}

playerUpdateVotes() {
	level endon("post_mapvote");
	self endon("disconnect");
	while (1) {
		if (!self.changingVote)
		braxi\_vote_hud::updateVotes();
		wait 0.5;
	}
}

playerStartVoting() {
	level endon("post_mapvote");
	self endon("disconnect");

	self.startvote = newClientHudElem(self);
	self.startvote.x = braxi\_vote_hud::getX(level.voteavg);
	self.startvote.y = -80;
	self.startvote.elemType = "font";
	self.startvote.alignX = "center";
	self.startvote.alignY = "middle";
	self.startvote.horzAlign = "center";
	self.startvote.vertAlign = "bottom";
	self.startvote.color = (1, 1, 1);
	self.startvote.alpha = 1;
	self.startvote.sort = 0;
	self.startvote.font = "default";
	self.startvote.fontScale = 3;
	self.startvote.foreground = true;
	self.startvote.label = &"MAPVOTE_PRESSFIRE";
	
	while(!self attackbuttonpressed()) {
		wait 0.05;
	}
	
	self.voteindex = 0;
	changeVotes(0,1);
	braxi\_vote_hud::updateVotes();
	
	self.startvote FadeOverTime(1);
	self.startvote.alpha = 0;
	
	wait 1;
	
	self.startvote destroy();

}

incVote() {
	changeVotes(self.voteindex, -1);
	
	self.voteindex++;
	if (self.voteindex>=level.maps.size)
	self.voteindex = 0;
	
	changeVotes(self.voteindex, 1);
	
	braxi\_vote_hud::updateVotes();
	
	for (i=0; i<=level.mapitems; i++ ) {
	self.voteitem[i] braxi\_vote_hud::nextIndex();
	}
}

decVote() {
	changeVotes(self.voteindex, -1);
	
	self.voteindex-=1;
	if (self.voteindex<0)
	self.voteindex = level.maps.size-1;
	
	changeVotes(self.voteindex, 1);
	
	wait 0.05;
	
	braxi\_vote_hud::updateVotes();
	
	for (i=0; i<=level.mapitems; i++ ) {
	self.voteitem[i] braxi\_vote_hud::prevIndex();
	}
}

changeVotes(index, dif) {
	if( index < 0 || index >= level.maps.size ) return;
	
	level.maps[index].votes += dif;
	if( level.maps[index].votes < 0 ) level.maps[index].votes = 0;
}
