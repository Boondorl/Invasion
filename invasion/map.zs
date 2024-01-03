const STAT_IDLE_PUSHER = Thinker.STAT_STATIC + 3;

class MonsterPusher : Actor
{
	enum EPusherArgs
	{
		SEC_TAG,
		PUSH_POW,
		PUSH_RAD
	}

	private Array<Sector> sectors;

	Default
	{
		//$Category Invasion
		//$Title Monster Push Spot
		//$Arg0 Sector Tag
		//$Arg0Type 13
		//$Arg0Tooltip If set to 0, pushes anything in the same sector as the Push Spot.
		//$Arg1 Push Power
		//$Arg1Default 8
		//$Arg1Tooltip Angle determines the direction monsters are pushed.
		//$Arg2 Push Radius
		//$Arg2Tooltip If a positive non-zero number, push within radius instead of the sector.

		FloatBobPhase 0u;
		Radius 16.0;
		Height 32.0;
		
		+SYNCHRONIZED
		+NOBLOCKMAP
		+NOSECTOR
		+NOTONAUTOMAP
		+DONTBLAST
	}

	override void PostBeginPlay()
	{
		super.PostBeginPlay();

		if (args[SEC_TAG])
		{
			int secID;
			let it = level.CreateSectorTagIterator(args[SEC_TAG]);
			while ((secID = it.Next()) >= 0)
				sectors.Push(level.sectors[secID]);
		}
	}
	
	override void Activate(Actor activator)
	{
		bDormant = false;
		ChangeStatNum(STAT_FIRST_THINKING);
	}
	
	override void Deactivate(Actor deactivator)
	{
		bDormant = true;
		ChangeStatNum(STAT_IDLE_PUSHER);
	}
	
	override void Tick()
	{
		if ((freezeTics > 0u && --freezeTics >= 0u) || !args[PUSH_POW] || IsFrozen())
			return;
		
		double power = abs(args[PUSH_POW]);
		Vector2 dir = angle.ToVector();
		if (args[PUSH_POW] < 0)
			dir = -dir;

		if (args[PUSH_RAD] > 0)
		{
			double radSq = args[PUSH_RAD] * args[PUSH_RAD];
			let it = BlockThingsIterator.Create(self, args[PUSH_RAD]);
			while (it.Next())
			{
				Actor mo = it.thing;
				if (mo && mo.bIsMonster && !mo.bDormant && !mo.IsFrozen() && Distance2DSquared(mo) <= radSq)
					PushMonster(mo, dir, power);
			}
		}
		else if (sectors.Size())
		{
			foreach (sec : sectors)
				PushMonstersInSector(sec, dir, power);
		}
		else
		{
			PushMonstersInSector(curSector, dir, power);
		}
	}
	
	protected void PushMonstersInSector(Sector sec, Vector2 dir, double power)
	{
		Actor cur = sec.thingList;
		while (cur)
		{
			if (cur.bIsMonster && !cur.bDormant && !cur.IsFrozen())
				PushMonster(cur, dir, power);
			
			cur = cur.sNext;
		}
	}

	protected void PushMonster(Actor mo, Vector2 dir, double power)
	{
		double diff = mo.vel.xy dot dir;
		if (diff < power)
			mo.vel.xy += dir * min(power, power-diff);
	}
}

const STAT_FUTURE_PLAYER_START = Thinker.STAT_STATIC + 1;

class FuturePlayerStart : Actor
{
	enum EFuturePlayerArgs
	{
		PLAY_NUM,
		START_WAVE
	}

	int user_InvasionID;

	Default
	{
		//$Category Invasion
		//$Title Future Player Start
		//$Sprite PLAYA1
		//$Color 2
		//$Arg0 Player Start Number
		//$Arg0Default 1
		//$Arg1 Wave
		//$Arg1Tooltip The wave signifying when the matching player number will start spawning here.
		//$Arg1Default 2

		FloatBobPhase 0u;
		Radius 16.0;
		Height 56.0;
		
		+SYNCHRONIZED
		+NOBLOCKMAP
		+NOSECTOR
		+NOTONAUTOMAP
		+DONTBLAST
	}

	override void BeginPlay()
	{
		super.BeginPlay();

		ChangeStatNum(STAT_FUTURE_PLAYER_START);
	}

	override void PostBeginPlay()
	{
		super.PostBeginPlay();

		--args[PLAY_NUM]; // Players are 0-indexed
		if (args[PLAY_NUM] < 0 || args[PLAY_NUM] >= MAXPLAYERS)
		{
			Destroy();
			return;
		}

		if (args[START_WAVE] <= 0)
			args[START_WAVE] = 1;
	}
}