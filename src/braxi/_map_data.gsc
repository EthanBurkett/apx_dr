// ApX Deathrun. Original map coordinates and trap names by BraXi and contributors.
// Map-specific data lives in mp/apx_*.csv instead of large script switches.
#include braxi\_common;

createTimeTrigger()
{
	if( getEntArray( "endmap_trig", "targetname" ).size ) return;
	table = "mp/apx_time_triggers.csv";
	if( tableLookup( table, 0, level.mapName, 1 ) == "" ) return;
	origin = (float(tableLookup(table,0,level.mapName,1)), float(tableLookup(table,0,level.mapName,2)), float(tableLookup(table,0,level.mapName,3)));
	radius = float(tableLookup(table,0,level.mapName,4));
	height = float(tableLookup(table,0,level.mapName,5));
	trigger = spawn( "trigger_radius", origin, 0, radius, height );
	trigger.targetname = "endmap_trig";
}

findTrapTriggers()
{
	names = strTok( tableLookup( "mp/apx_trap_triggers.csv", 0, level.mapName, 1 ), ";" );
	triggers = [];
	for( i = 0; i < names.size; i++ )
	{
		trigger = getEnt( names[i], "targetname" );
		if( isDefined( trigger ) ) triggers[triggers.size] = trigger;
	}
	return triggers;
}

createCollisions()
{
	table = "mp/apx_collisions.csv";
	// Each collision uses a unique numeric row key; map name is column 1.
	for( row = 1; tableLookup(table,0,row,0) != ""; row++ )
	{
		if( tableLookup(table,0,row,1) != level.mapName ) continue;
		origin = (float(tableLookup(table,0,row,2)), float(tableLookup(table,0,row,3)), float(tableLookup(table,0,row,4)));
		spawnCollision( origin, float(tableLookup(table,0,row,5)), float(tableLookup(table,0,row,6)) );
	}
}
