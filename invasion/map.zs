class MonsterPusher : Actor
{
	const IDLE_STAT = Thinker.STAT_STATIC + 3;

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

	override void BeginPlay()
	{
		ChangeStatNum(STAT_FIRST_THINKING);
		Super.BeginPlay();
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		if (Args[SEC_TAG])
		{
			int secID;
			let it = Level.CreateSectorTagIterator(Args[SEC_TAG]);
			while ((secID = it.Next()) >= 0)
				sectors.Push(Level.Sectors[secID]);
		}
	}
	
	override void Activate(Actor activator)
	{
		if (!bDormant)
			return;

		bDormant = false;
		ChangeStatNum(STAT_FIRST_THINKING);
	}
	
	override void Deactivate(Actor deactivator)
	{
		if (bDormant)
			return;

		bDormant = true;
		ChangeStatNum(IDLE_STAT);
	}
	
	override void Tick()
	{
		if ((FreezeTics > 0u && --FreezeTics >= 0u) || !Args[PUSH_POW] || IsFrozen())
			return;
		
		double power = Abs(Args[PUSH_POW]);
		Vector2 dir = Angle.ToVector();
		if (Args[PUSH_POW] < 0)
			dir = -dir;

		if (Args[PUSH_RAD] > 0)
		{
			double radSq = Args[PUSH_RAD] * Args[PUSH_RAD];
			let it = BlockThingsIterator.Create(self, Args[PUSH_RAD]);
			while (it.Next())
			{
				Actor mo = it.Thing;
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
		Actor cur = sec.ThingList;
		while (cur)
		{
			if (cur.bIsMonster && !cur.bDormant && !cur.IsFrozen())
				PushMonster(cur, dir, power);
			
			cur = cur.SNext;
		}
	}

	protected void PushMonster(Actor mo, Vector2 dir, double power)
	{
		double diff = mo.Vel.XY dot dir;
		if (diff < power)
			mo.Vel.XY += dir * Min(power, power-diff);
	}
}

class FuturePlayerStart : Actor
{
	const DEFAULT_STAT = Thinker.STAT_STATIC + 1;

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
		Super.BeginPlay();

		ChangeStatNum(DEFAULT_STAT);
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		--Args[PLAY_NUM]; // Players are 0-indexed
		if (Args[PLAY_NUM] < 0 || Args[PLAY_NUM] >= MAXPLAYERS)
		{
			Destroy();
			return;
		}

		if (Args[START_WAVE] <= 0)
			Args[START_WAVE] = 1;
	}
}
