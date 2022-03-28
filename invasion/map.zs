enum EPusherArgs
{
	SECTOR_TAG,
	PUSH_POW,
	PUSH_ANG
}

class MonsterPusher : Actor
{
	Default
	{
		//$NotAngled
		//$Category Invasion
		//$Title Monster Push Spot
		//$Arg0 Sector tag
		//$Arg0ToolTip If set to 0, pushes anything in the same sector as the Push Spot.
		//$Arg1 Push Power
		//$Arg1Default 8
		//$Arg2 Angle
		//$Arg2Type 8
		FloatBobPhase 0;
		Radius 0;
		Height 0;
		
		+SYNCHRONIZED
		+NOBLOCKMAP
		+NOSECTOR
		+NOTONAUTOMAP
		+DONTBLAST
	}
	
	override void Activate(Actor activator)
	{
		bDormant = false;
	}
	
	override void Deactivate(Actor deactivator)
	{
		bDormant = true;
	}
	
	override void Tick()
	{
		if (bDormant || !args[PUSH_POW])
			return;
		
		Vector2 dir = AngleToVector(args[PUSH_ANG]);
		if (args[PUSH_POW] < 0)
			dir *= -1;
		double power = abs(args[PUSH_POW]);
		
		if (args[SECTOR_TAG] != 0)
		{
			let it = level.CreateSectorTagIterator(args[SECTOR_TAG]);
			int sectorID;
			while ((sectorID = it.Next()) >= 0)
				PushMonsters(level.sectors[sectorID], dir, power);
		}
		else
			PushMonsters(level.PointInSector(pos.xy), dir, power);
	}
	
	private void PushMonsters(Sector sec, Vector2 dir, double power)
	{
		Actor cur = sec.thinglist;
		while (cur)
		{
			if (cur.bIsMonster && !cur.bDormant && !cur.IsFrozen())
			{
				double diff = cur.vel.xy dot dir;
				if (diff < power)
					cur.vel.xy += dir * min(power, power-diff);
			}
			
			cur = cur.snext;
		}
	}
}