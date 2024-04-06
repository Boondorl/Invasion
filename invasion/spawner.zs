class InvasionType
{
	private class<Actor> type;
	private int probability;

	static InvasionType Create(class<Actor> type, int probability)
	{
		let it = new("InvasionType");
		it.type = type;
		it.probability = probability;

		return it;
	}

	clearscope class<Actor> GetType() const
	{
		return type;
	}

	clearscope int GetProbability() const
	{
		return probability;
	}
}

class InvasionSpawner : Actor abstract
{
	const DEFAULT_STAT = Thinker.STAT_STATIC + 2;

	enum ESpawnerArgs
	{
		SCRIPT,
		ACTOR_TID,
		SPAWN_DELAY,
		SPAWN_LIMIT,
		FLAGS
	}

	enum EFlags
	{
		FL_NONE 		= 0,
		FL_RESET 		= 1,
		FL_SEQUENCE 	= 1 << 1,
		FL_ALWAYS 		= 1 << 2,
		FL_WAIT_FIRST 	= 1 << 3,
		FL_WAIT_MONST 	= 1 << 4,
		FL_SILENT 		= 1 << 5,
		FL_NO_FOG 		= 1 << 6,
		FL_WAVE 		= 1 << 7,
		FL_DIFFICULTY 	= 1 << 8,
		FL_PLAYER 		= 1 << 9,
		FL_NO_TARGET 	= 1 << 10,
		FL_SET_CALLER 	= 1 << 11,
	}

	// Meta info
	private Invasion mode;
	private Array<InvasionType> spawnTypes;
	private int weight;
	private bool bDontCount;

	// Status
	private Inventory item; // Track if the currently spawned Actor is an item when spawning sequentially.
	private int timer;
	private int spawnLimit;
	private bool bPaused;
	private bool bSpawned; // Has spawned at least once.
	private bool bActivated;

	//$UserDefaultValue 1
	int user_StartWave;
	int user_EndWave;
	int user_InitialSpawnDelay;
	//$UserDefaultValue 0.2
	double user_WaveScale;
	//$UserDefaultValue 0.25
	double user_DifficultyScale;
	//$UserDefaultValue 0.3
	double user_PlayerScale;
	int user_PlayerThreshold;
	int user_InvasionID;
	
	Default
	{
		//$Arg0 Spawn Script
		//$Arg0Str
		//$Arg0Tooltip If a script name or number is provided, execute this when an Actor is spawned.
		//$Arg1 Actor TID
		//$Arg1Tooltip The TID to give to spawned Actors.
		//$Arg2 Spawn Delay
		//$Arg2Default 70
		//$Arg2Tooltip The delay in tics (35 per second) between spawns.
		//$Arg3 Spawn Limit
		//$Arg3Tooltip If not a positive value, spawn infinitely (won't count towards wave total).
		//$Arg4 Flags
		//$Arg4Enum { 1 = "Reset on new wave"; 2 = "Spawn sequentially"; 4 = "Spawn between waves"; 8 = "Wait for first wave to start"; 16 = "Spawn last"; 32 = "Silent initial spawn"; 64 = "No teleport fog"; 128 = "Scale with wave"; 256 = "Scale with difficulty"; 512 = "Scale with players"; 1024 = "Don't set monster target on spawn"; 2048 = "Set spawned Actor as script caller"; }
		//$Arg4Type 12
		
		FloatBobPhase 0u;
		Radius 32.0;
		Height 64.0;
		
		+SYNCHRONIZED
		+NOBLOCKMAP
		+NOSECTOR
		+NOTONAUTOMAP
		+DONTBLAST
	}
	
	override void BeginPlay()
	{
		DropItem di = GetDropItems();	
		while (di)
		{
			class<Actor> type = di.Name;
			if (type)
				AddSpawnType(type, di.Probability);
			
			di = di.Next;
		}

		if (!spawnTypes.Size())
		{
			Destroy();
			return;
		}

		Reset(true, true);
		ChangeStatNum(DEFAULT_STAT);

		Super.BeginPlay();
	}

	override void Activate(Actor activator)
	{
		if (!bDormant)
			return;
		
		bDormant = false;
		if (mode)
			mode.ModifyMonsterCount(self);
	}
	
	override void Deactivate(Actor deactivator)
	{
		if (bDormant)
			return;
		
		bDormant = true;
		if (mode)
			mode.ModifyMonsterCount(self);
	}
	
	override void Tick()
	{
		if (!mode)
			return;

		if ((Args[FLAGS] & FL_SEQUENCE) && Target
			&& ((Target.bIsMonster && Target.bKilled) || (item && item.Owner)))
		{
			Target = null;
			Item = null;
		}

		if ((FreezeTics > 0u && --FreezeTics >= 0u) || IsFrozen())
			return;
		
		if (!bDormant && !bPaused
			&& (Args[SPAWN_LIMIT] <= 0 || spawnLimit > 0)
			&& (!(Args[FLAGS] & FL_SEQUENCE) || !Target)
			&& (mode.GetInvasionState() == Invasion.IS_ACTIVE || ((Args[FLAGS] & FL_ALWAYS) && (!(Args[FLAGS] & FL_WAIT_FIRST) || bSpawned)))
			&& (!(Args[FLAGS] & FL_WAIT_MONST) || mode.GetRemainingInvasionEnemies() <= mode.GetInvasionLastSpawnThreshold())
			&& --timer <= 0)
		{
			SpawnActor();
		}
	}

	protected void AddSpawnType(class<Actor> type, int probability)
	{
		let def = GetDefaultByType(type);
		bDontCount |= !def.bIsMonster;

		probability = Max(1, probability);
		spawnTypes.Push(InvasionType.Create(type, probability));
		weight += probability;
	}
	
	protected void SpawnActor()
	{
		if (!mode)
			return;

		int i;
		int w = Random[InvasionSpawner](0, weight-1);
		for (; i < spawnTypes.Size() && w >= 0; ++i)
			w -= spawnTypes[i].GetProbability();

		class<Actor> type = spawnTypes[--i].GetType();
		if (!type)
			type = "Unknown";
		
		let def = GetDefaultByType(type);
		bool success = true;
		if (def.bSolid)
		{
			bSolid = true;
			height = def.Height;
			if (!(Radius ~== def.Radius))
				A_SetSize(def.Radius);
			
			success = TestMobjLocation();
			bSolid = false;
		}
		
		if (!success)
		{
			timer = GameTicRate; // Try again in another second.
			return;
		}
		
		let [temp, mo] = A_SpawnItemEx(type, flags: SXF_TRANSFERAMBUSHFLAG|SXF_NOCHECKPOSITION, tid: Args[ACTOR_TID]);
		// Handle these manually because they're too much of a hassle to handle otherwise.
		while (mo is "RandomSpawner")
		{
			let rs = RandomSpawner(mo);
			if (rs.BounceCount >= RandomSpawner.MAX_RANDOMSPAWNERS_RECURSION)
				rs.Species = 'Unknown';

			if (rs.Species != 'None')
			{
				mo = Spawn(rs.Species, rs.Pos);
				mo.Angle = rs.Angle;
				mo.bAmbush = rs.bAmbush;
				mo.ChangeTID(rs.TID);
				if (mo is "RandomSpawner")
					mo.BounceCount = ++rs.BounceCount;

				rs.PostSpawn(mo);
			}

			rs.Destroy();
		}

		if (!mo)
			return;

		mode.AddWaveMonster(mo);
		mo.bNeverRespawn = true;
		if (mo.bIsMonster && !(Args[FLAGS] & FL_NO_TARGET))
		{
			Actor nearest = GetNearestPlayer();
			if (nearest)
				mo.LastHeard = nearest;
		}
		
		if ((!(Args[FLAGS] & FL_SILENT) || bSpawned) && !(Args[FLAGS] & FL_NO_FOG))
		{
			let tf = Spawn(mo.TeleFogDestType, mo.Pos, ALLOW_REPLACE);
			if (tf)
				tf.Target = mo;
		}
		
		if (spawnLimit > 0)
			--spawnLimit;
		if (Args[FLAGS] & FL_SEQUENCE)
		{
			Target = mo;
			item = Inventory(mo);
		}
		if (Args[SCRIPT])
		{
			Actor caller = Args[FLAGS] & FL_SET_CALLER ? mo : Actor(self);
			Level.ExecuteSpecial(226, caller, null, false, Args[SCRIPT]);
		}
		
		timer = Args[SPAWN_DELAY];
		bSpawned = true;
	}
	
	private Actor GetNearestPlayer()
	{
		if (!multiplayer)
			return Players[0].Mo;
		
		Actor validPlayer;
		int closestIndex = MAXPLAYERS;
		double closestDist, closestValid;
		closestDist = closestValid = double.infinity;
		
		for (int i; i < MAXPLAYERS; ++i)
		{
			if (!PlayerInGame[i])
				continue;
			
			double d = Distance3DSquared(Players[i].Mo);
			if (d < closestDist)
			{
				closestIndex = i;
				closestDist = d;
			}
			
			if (d < closestValid && CheckSight(Players[i].Mo, SF_IGNOREWATERBOUNDARY))
			{
				validPlayer = Players[i].Mo;
				closestValid = d;
			}
		}
		
		if (!validPlayer)
		{
			if (CurSector.SoundTarget && CurSector.SoundTarget.Player)
				validPlayer = CurSector.SoundTarget;
			else if (closestIndex < MAXPLAYERS)
				validPlayer = Players[closestIndex].Mo;
			else
				validPlayer = Players[0].Mo;
		}
		
		return validPlayer;
	}
	
	clearscope int GetSpawnAmount(int wave) const
	{
		int s = Args[SPAWN_LIMIT];
		if (s <= 0)
			return 0;
		if (s == 1)
			return 1;
		
		if (Args[FLAGS] & FL_WAVE)
			s += int(Ceil(Args[SPAWN_LIMIT] * user_WaveScale * (wave-user_StartWave)));
		
		if (Args[FLAGS] & FL_DIFFICULTY)
		{
			int skill = GameModeHandler.Get().GetMapSkill();
			if (skill < 3)
				s = int(Ceil(s - Args[SPAWN_LIMIT]*(1.0 - (1.0 / (1 + user_DifficultyScale*(3-skill))))));
			else
				s += int(Ceil(Args[SPAWN_LIMIT] * user_DifficultyScale * (skill-3)));
		}
		
		if ((Args[FLAGS] & FL_PLAYER) && multiplayer)
		{
			int count;
			for (int i; i < MAXPLAYERS; ++i)
				count += PlayerInGame[i];
			
			s += int(Ceil(Args[SPAWN_LIMIT] * user_PlayerScale * --count));
		}

		return Max(0, s);
	}
	
	clearscope int GetSpawnDelay() const
	{
		return user_InitialSpawnDelay < 0 ? Args[SPAWN_DELAY] : user_InitialSpawnDelay;
	}
	
	clearscope bool ShouldActivate(int wave) const
	{
		bool should = user_PlayerThreshold <= 1;
		if (!should && multiplayer)
		{
			int count;
			for (int i; i < MAXPLAYERS; ++i)
				count += PlayerInGame[i];

			should = count >= user_PlayerThreshold;
		}

		return should
				&& (user_StartWave <= 0 || wave >= user_StartWave)
				&& (user_EndWave <= 0 || wave < user_EndWave);
	}

	clearscope bool Activated() const
	{
		return bActivated;
	}
	
	clearscope int RemainingSpawns() const
	{
		return spawnLimit;
	}
	
	clearscope bool Paused() const
	{
		return bPaused;
	}

	clearscope bool CountMonster() const
	{
		return !bDontCount;
	}

	void Reset(bool time, bool limit)
	{
		if (time)
			timer = GetSpawnDelay();
		if (limit)
			spawnLimit = GetSpawnAmount(mode ? Max(mode.GetInvasionWave(), 1) : 1);
	}

	void ActivateSpawner(bool val, Invasion handler)
	{
		bActivated = val;
		mode = handler;
	}
	
	void ClearSpawns()
	{
		spawnLimit = 0;
	}
	
	void Pause(bool val)
	{
		bPaused = val;
	}
}

class GenericSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion
		//$Title Generic Spawner
	}

	string user_ClassName;

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		class<Actor> type = user_ClassName;
		if (type)
			AddSpawnType(type, 1);
	}
}
