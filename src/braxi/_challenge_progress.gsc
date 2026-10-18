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


#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;
#include braxi\_common;

// ApX: challenge progress implementation.

unlockChallenge( refString )
{
	assert( isDefined( refString ) && refString != "" );

	// tokenize reference string, accepting multiple camo unlocks in one call
	Ref_Tok = strTok( refString, ";" );
	assertex( Ref_Tok.size > 0, "Camo unlock specified in datatable ["+refString+"] is incomplete or empty" );
	
	for( i=0; i<Ref_Tok.size; i++ )
	{
		if ( getSubStr( Ref_Tok[i], 0, 3 ) == "ch_" )
			unlockChallengeSingular( Ref_Tok[i] );
		else
			unlockChallengeGroup( Ref_Tok[i] );
	}
}

unlockChallengeSingular( refString )
{
	assertEx( isDefined( level.challengeInfo[refString] ), "Challenge unlock "+refString+" does not exist." );
	tableName = "mp/challengetable_tier" + level.challengeInfo[refString]["tier"] + ".csv";
	
	if ( self getStat( level.challengeInfo[refString]["stateid"] ) )
		return;

	self setStat( level.challengeInfo[refString]["stateid"], 1 );
	self setStat( 269 + level.challengeInfo[refString]["tier"], 2 );// 2: new, 1: old
}

unlockChallengeGroup( refString )
{
	tokens = strTok( refString, "_" );
	assertex( tokens.size > 0, "Challenge unlock specified in datatable ["+refString+"] is incomplete or empty" );
	
	assert( tokens[0] == "tier" );
	
	tierId = int( tokens[1] );
	assertEx( tierId > 0 && tierId <= level.numChallengeTiers, "invalid tier ID " + tierId );

	groupId = "";
	if ( tokens.size > 2 )
		groupId = tokens[2];

	challengeArray = getArrayKeys( level.challengeInfo );
	
	for ( index = 0; index < challengeArray.size; index++ )
	{
		challenge = level.challengeInfo[challengeArray[index]];
		
		if ( challenge["tier"] != tierId )
			continue;		
		if ( challenge["group"] != groupId )
			continue;		
		if ( self getStat( challenge["stateid"] ) )
			continue;
	
		self setStat( challenge["stateid"], 1 );		
		self setStat( 269 + challenge["tier"], 2 );// 2: new, 1: old	
	}
}

processChallenge( baseName, progressInc )
{
	if ( !braxi\_missions::mayProcessChallenges() )
		return;
		
	numLevels = braxi\_challenge_data::getChallengeLevels( baseName );
	
	if ( numLevels > 1 )
		missionStatus = self braxi\_challenge_data::getChallengeStatus( (baseName + "1") );
	else
		missionStatus = self braxi\_challenge_data::getChallengeStatus( baseName );

	if ( !isDefined( progressInc ) )
		progressInc = 1;
	
	///#
	//if ( getDvarInt( "debug_challenges" ) )
	//	println( "CHALLENGE PROGRESS - " + baseName + ": " + progressInc );
	//#/
	
	if ( !missionStatus || missionStatus == 255 )
		return;
		
	assertex( missionStatus <= numLevels, "Mini challenge levels higher than max: " + missionStatus + " vs. " + numLevels );
	
	if ( numLevels > 1 )
		refString = baseName + missionStatus;
	else
		refString = baseName;

	progress = self getStat( level.challengeInfo[refString]["statid"] );
	progress += progressInc;
	
	self setStat( level.challengeInfo[refString]["statid"], progress );

	if ( progress >= level.challengeInfo[refString]["maxval"] )
	{
		if( level.challengeInfo[refString]["ability"] != "" )
			self thread challengeNotify( level.challengeInfo[refString]["name"], "Unlocked new ability!" );
		else
			self thread challengeNotify( level.challengeInfo[refString]["name"], level.challengeInfo[refString]["desc"] );

		if ( missionStatus == numLevels )
			missionStatus = 255;
		else
			missionStatus += 1;

		if ( numLevels > 1 )
			self.challengeData[baseName + "1"] = missionStatus;
		else
			self.challengeData[baseName] = missionStatus;

		// prevent bars from running over
		self setStat( level.challengeInfo[refString]["statid"], level.challengeInfo[refString]["maxval"] );

		self setStat( level.challengeInfo[refString]["stateid"], missionStatus );
		self braxi\_rank::giveRankXP( "challenge", level.challengeInfo[refString]["reward"] );

		// hacks everywhere...
		if( self tierCheck( level.challengeInfo[refString]["id"] ) )
		{
			if( level.challengeInfo[refString]["id"] == 1 )
			{
				self thread unlockChallenge( "tier_2" );
				self braxi\_challenge_data::updateChallenges();
			}
		}

		if( level.challengeInfo[refString]["ability"] != "" )
			self braxi\_rank::unlockAbility( level.challengeInfo[refString]["ability"] );
	}
}

tierCheck( tierID )
{
	challengeNames = getArrayKeys( level.challengeInfo );
	for ( index = 0; index < challengeNames.size; index++ )
	{
		challengeInfo = level.challengeInfo[challengeNames[index]];

		if ( challengeInfo["tier"] != tierID )
			continue;
			
		// multi level
		if ( challengeInfo["level"] > 1 )
			continue;
		
		// undefined means it's locked
		if ( !isDefined( self.challengeData[challengeNames[index]] ) )
			return false;
		
		// 255 means it's not completed
		if ( self.challengeData[challengeNames[index]] != 255 )
			return false;
	}

	return true;
}

challengeNotify( challengeName, challengeDesc )
{
	notifyData = spawnStruct();
	notifyData.titleText = &"MP_CHALLENGE_COMPLETED";
	notifyData.notifyText = challengeName;
	notifyData.notifyText2 = challengeDesc;
	notifyData.sound = "mp_challenge_complete";
	
	self maps\mp\gametypes\_hud_message::notifyMessage( notifyData );
}
