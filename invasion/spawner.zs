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

	class<Actor> GetType() const
	{
		return type;
	}

	int GetProbability() const
	{
		return probability;
	}
}

class InvasionSpawner : Actor abstract
{
	const LOG_BASE = log(2);

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
		FL_NONE = 0,
		FL_RESET = 1,
		FL_ALWAYS = 1<<1,
		FL_SEQUENCE = 1<<2,
		FL_WAIT_MONST = 1<<3,
		FL_WAIT_FIRST = 1<<4,
		FL_NO_FOG = 1<<5,
		FL_SILENT = 1<<6,
		FL_WAVE = 1<<7,
		FL_DIFFICULTY = 1<<8,
		FL_PLAYER = 1<<9,
		FL_SET_CALLER = 1<<10,
		FL_NO_TARGET = 1<<11
	}

	// Meta info
	private Invasion mode;
	private Array<InvasionType> spawnTypes;
	private int weight;
	private bool bDontCount;

	// Status
	private int timer;
	private int spawnLimit;
	private bool bPaused;
	private bool bSpawned; // Has spawned at least once

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
		//$Arg4Enum { 1 = "Reset on new wave"; 2 = "Spawn between waves"; 4 = "Spawn sequentially"; 8 = "Spawn last"; 16 = "Wait for first active wave"; 32 = "No teleport fog"; 64 = "Silent initial spawn"; 128 = "Scale with wave"; 256 = "Scale with difficulty"; 512 = "Scale with players"; 1024 = "Set spawned as script caller"; 2048 = "Don't set monster target on spawn"; }
		//$Arg4Type 12
		
		FloatBobPhase 0;
		Radius 32;
		Height 64;
		
		+SYNCHRONIZED
		+NOBLOCKMAP
		+NOSECTOR
		+NOTONAUTOMAP
		+DONTBLAST
	}
	
	override void BeginPlay()
	{
		super.BeginPlay();
		
		ChangeStatNum(STAT_FIRST_THINKING);
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		
		mode = Invasion.GetMode();
		Reset();
		if (!bDormant && mode.GameState() == GS_ACTIVE)
			mode.ModifyMonsterCount(self);

		DropItem di = GetDropItems();	
		while (di)
		{
			class<Actor> type = di.name;
			if (type)
				AddSpawnType(type, di.probability);
			
			di = di.next;
		}
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
		{
			Destroy();
			return;
		}
		
		if (!mode.Started())
			return;
		
		if (mode.WaveEnded())
		{
			if (!(args[FLAGS] & FL_ALWAYS))
				timer = GetSpawnDelay();
			if (args[FLAGS] & FL_RESET)
				spawnLimit = GetSpawnAmount(mode.CurrentWave());
		}
		
		if ((args[FLAGS] & FL_SEQUENCE) && target)
		{
			if (target.bIsMonster && target.bKilled)
			{
				target = null;
			}
			else
			{
				let i = Inventory(target);
				if (i && i.owner)
					target = null;
			}
		}
		
		if (bDestroyed || bDormant || bPaused
			|| !InWaveRange(mode.CurrentWave())
			|| (mode.GameState() != GS_ACTIVE && (!(args[FLAGS] & FL_ALWAYS) || ((args[FLAGS] & FL_WAIT_FIRST) && !bSpawned)))
			|| ((args[FLAGS] & FL_WAIT_MONST) && mode.RemainingEnemies() > mode.SpawnThreshold())
			|| IsFrozen())
		{
			return;
		}
		
		if ((args[SPAWN_LIMIT] <= 0 || spawnLimit > 0) && (!(args[FLAGS] & FL_SEQUENCE) || !target) && --timer <= 0)
			SpawnActor();
	}

	protected void AddSpawnType(class<Actor> type, int probability)
	{
		let def = GetDefaultByType(type);
		bDontCount |= !def.bIsMonster;

		probability = max(1, probability);
		spawnTypes.Push(InvasionType.Create(type, probability));
		weight += probability;
	}
	
	protected void SpawnActor()
	{
		int i;
		int limit = spawnTypes.Size() - 1;
		for (; i <= limit; ++i)
		{
			if (Random[InvasionSpawner](1, weight) <= spawnTypes[i].GetProbability())
				break;
		}
		
		class<Actor> type = spawnTypes[i].GetType();
		if (!type)
			type = "Unknown";
		
		let def = GetDefaultByType(type);
		bool success = true;
		if (def.bSolid)
		{
			bool curSolid = bSolid;
			
			bSolid = def.bSolid;
			height = def.height;
			if (!(radius ~== def.radius))
				A_SetSize(def.radius);
			
			success = TestMobjLocation();
			bSolid = curSolid;
		}
		
		if (!success)
			return;
		
		bool monst = def.bIsMonster;
		let [spawned, mo] = A_SpawnItemEx(type, flags: SXF_TRANSFERAMBUSHFLAG|SXF_NOCHECKPOSITION, tid: args[ACTOR_TID]);
		if (spawned)
		{
			// Handle these manually because they're too much of a hassle to handle otherwise
			while (mo is "RandomSpawner")
			{
				let rs = RandomSpawner(mo);
				if (rs.bounceCount >= RandomSpawner.MAX_RANDOMSPAWNERS_RECURSION)
					rs.species = 'Unknown';

				if (rs.species != 'None')
				{
					mo = Spawn(rs.species, rs.pos);
					mo.angle = rs.angle;
					mo.bAmbush = rs.bAmbush;
					mo.ChangeTID(rs.tid);
					if (mo is "RandomSpawner")
						mo.bounceCount = ++rs.bounceCount;

					rs.PostSpawn(mo);
				}

				rs.Destroy();
			}

			if (mo)
			{
				mo.bNeverRespawn = true;
				if (monst)
				{
					mode.DisableCounter();
					if (!(args[FLAGS] & FL_NO_TARGET))
					{
						Actor nearest = GetNearestPlayer();
						if (nearest)
							mo.lastHeard = nearest;
					}
				}
				
				if ((!(args[FLAGS] & FL_SILENT) || bSpawned) && !(args[FLAGS] & FL_NO_FOG))
				{
					let tf = Spawn(mo.teleFogDestType, mo.pos);
					if (tf)
					{
						if (tf.pos.z < tf.floorZ)
							tf.SetZ(tf.floorZ);
						
						tf.target = mo;
					}
				}
			}
			
			if (spawnLimit > 0)
				--spawnLimit;
			if (args[FLAGS] & FL_SEQUENCE)
				target = mo;
			if (args[SCRIPT])
			{
				Actor caller = args[FLAGS] & FL_SET_CALLER ? mo : Actor(self);
				level.ExecuteSpecial(226, caller, null, false, args[SCRIPT]);
			}
			
			timer = args[SPAWN_DELAY];
			bSpawned = true;
		}
		else
		{
			timer = gameTicRate; // Keep retrying every second
		}
	}
	
	private Actor GetNearestPlayer()
	{
		if (!multiplayer)
			return players[0].mo;
		
		Actor validPlayer;
		int closestIndex = MAXPLAYERS;
		double closestDist, closestValid;
		closestDist = closestValid = double.infinity;
		
		for (int i = 0; i < MAXPLAYERS; ++i)
		{
			if (!playerInGame[i])
				continue;
			
			double d = Distance3DSquared(players[i].mo);
			if (d < closestDist)
			{
				closestIndex = i;
				closestDist = d;
			}
			
			if (d < closestValid && CheckSight(players[i].mo, SF_IGNOREWATERBOUNDARY))
			{
				validPlayer = players[i].mo;
				closestValid = d;
			}
		}
		
		if (!validPlayer)
		{
			if (curSector.soundTarget && curSector.soundTarget.player)
				validPlayer = curSector.soundTarget;
			else if (closestIndex < MAXPLAYERS)
				validPlayer = players[closestIndex].mo;
			else
				validPlayer = players[0].mo;
		}
		
		return validPlayer;
	}
	
	clearscope int GetSpawnAmount(int wave) const
	{
		int s = args[SPAWN_LIMIT];
		if (s <= 0)
			return 0;
		if (s == 1)
			return 1;
		
		if (args[FLAGS] & FL_WAVE)
			s += int(ceil(args[SPAWN_LIMIT] * user_WaveScale * (wave-user_StartWave)));
		
		if (args[FLAGS] & FL_DIFFICULTY)
		{
			int skill = 1 + int(log(G_SkillPropertyInt(SKILLP_SpawnFilter)) / LOG_BASE);
			if (skill < 3)
			{
				double multi = 1 / (1 + user_DifficultyScale*(3-skill));
				s = int(ceil(s - args[SPAWN_LIMIT]*(1-multi)));
			}
			else
			{
				s += int(ceil(args[SPAWN_LIMIT] * user_DifficultyScale * (skill-3)));
			}
		}
		
		if (args[FLAGS] & FL_PLAYER)
		{
			int count;
			for (int i = 0; i < MAXPLAYERS; ++i)
				count += playerInGame[i];
			
			s += int(ceil(args[SPAWN_LIMIT] * user_PlayerScale * --count));
		}

		return max(0, s);
	}
	
	clearscope int GetSpawnDelay() const
	{
		return user_InitialSpawnDelay < 0 ? args[SPAWN_DELAY] : user_InitialSpawnDelay;
	}
	
	clearscope bool InWaveRange(int wave) const
	{
		return (user_StartWave <= 0 || wave >= user_StartWave)
				&& (user_EndWave <= 0 || wave < user_EndWave);
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

	void Reset()
	{
		timer = GetSpawnDelay();
		spawnLimit = GetSpawnAmount(max(mode.CurrentWave(), 1));
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
		super.PostBeginPlay();

		class<Actor> type = user_ClassName;
		if (type)
			AddSpawnType(type, 1);
	}
}