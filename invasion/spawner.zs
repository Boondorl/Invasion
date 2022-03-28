enum EArgType
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
	FL_WAITMONST = 1<<3,
	FL_WAITFIRST = 1<<4,
	FL_DELAY = 1<<5,
	FL_HALF = 1<<6,
	FL_DOUBLE = 1<<7,
	FL_QUADRUPLE = 1<<8,
	FL_NOFOG = 1<<9,
	FL_SILENT = 1<<10,
	FL_WAVE = 1<<11,
	FL_DIFFICULTY = 1<<12,
	FL_PLAYER = 1<<13,
	FL_SETCALLER = 1<<14,
	FL_NOTARGET = 1<<15
}

class InvasionSpawner : Actor abstract
{
	private Invasion mode;
	private int timer;
	private int spawnLimit;
	private bool bPaused;
	private bool bSpawned;
	private PlayerInfo alerter;
	
	Default
	{
		//$Arg0 Spawn Script
		//$Arg0Str
		//$Arg0Tooltip If a script name or number is provided, execute this when an Actor is spawned
		//$Arg1 Actor TID
		//$Arg1Tooltip The TID to give spawned Actors
		//$Arg2 Spawn Delay
		//$Arg2Default 70
		//$Arg2Tooltip The delay in tics (35 per second) between spawns
		//$Arg3 Spawn Limit
		//$Arg4 Flags
		//$Arg4Enum { 1 = "Reset on new wave"; 2 = "Spawn between waves"; 4 = "Spawn sequentially"; 8 = "Spawn last"; 16 = "Wait for first active wave"; 32 = "Use inital spawn delay"; 64 = "Halve intial spawn delay"; 128 = "Double initial spawn delay"; 256 = "Quadruple initial spawn delay"; 512 = "No teleport fog"; 1024 = "Silent initial spawn"; 2048 = "Scale with wave"; 4096 = "Scale with difficulty"; 8192 = "Scale with players"; 16384 = "Set spawned as script caller"; 32768 = "Don't set monster target on spawn"; }
		//$Arg4Type 12
		
		FloatBobPhase 0;
		Radius 0;
		Height 0;
		Health 1;
		
		+SYNCHRONIZED
		+NOBLOCKMAP
		+NOSECTOR
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
		timer = GetSpawnDelay();
		spawnLimit = GetSpawnAmount(max(mode.CurrentWave(), 1));
		if (!bDormant && mode.GameState() == GS_ACTIVE)
			mode.ModifyMonsterCount(self);
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
			alerter = null;
			if (!(args[FLAGS] & FL_ALWAYS))
				timer = GetSpawnDelay();
			if (args[flags] & FL_RESET)
				spawnLimit = GetSpawnAmount(mode.CurrentWave());
		}
		
		if (alerter)
		{
			SoundAlert(alerter.mo);
			alerter = null;
		}
		
		if ((args[FLAGS] & FL_SEQUENCE) && target)
		{
			if (target.bIsMonster && target.health <= 0)
				target = null;
			else
			{
				let i = Inventory(target);
				if (i && i.owner)
					target = null;
			}
		}
		
		if (bDestroyed || bDormant || bPaused
			|| !InWaveRange(mode.CurrentWave())
			|| (mode.GameState() != GS_ACTIVE && (!(args[FLAGS] & FL_ALWAYS) || ((args[FLAGS] & FL_WAITFIRST) && !bSpawned)))
			|| ((args[FLAGS] & FL_WAITMONST) && mode.RemainingEnemies() > mode.SpawnThreshold())
			|| IsFrozen())
		{
			return;
		}
		
		if ((args[SPAWN_LIMIT] <= 0 || spawnLimit > 0) && (!(args[FLAGS] & FL_SEQUENCE) || !target) && --timer <= 0)
			SpawnActor();
	}
	
	protected void SpawnActor()
	{
		DropItem head, di;
		di = head = GetDropItems();
		int weight;
		while (di)
		{
			if (di.Name != 'None')
				weight += max(1, di.Probability);
			
			di = di.Next;
		}
		
		di = head;
		while (di)
		{
			if (di.Name != 'None')
			{
				bool hit = !di.Next || Random[InvasionSpawner](1,weight) <= max(1,di.Probability);
				if (hit)
					break;
			}
			
			di = di.Next;
		}
		
		class<Actor> type;
		if (!di)
			type = "Unknown";
		else
		{
			type = di.Name;
			if (!type)
				type = "Unknown";
		}
		
		let def = GetDefaultByType(type);
		bool success = true;
		if (def.bSolid)
		{
			bool curSolid = bSolid;
			
			bSolid = def.bSolid;
			height = def.height;
			if (radius != def.radius)
				A_SetSize(def.radius);
			
			success = TestMobjLocation();
			bSolid = curSolid;
		}
		
		if (!success)
			return;
		
		bool monst = def.bIsMonster;
		bool spawned;
		Actor mo;
		[spawned, mo] = A_SpawnItemEx(type, flags: SXF_TRANSFERAMBUSHFLAG|SXF_NOCHECKPOSITION, tid: args[ACTOR_TID]);
		if (spawned)
		{
			if (mo)
			{
				mo.bNeverRespawn = true;
				if (monst)
				{
					mode.DisableCounter();
					if (!(args[FLAGS] & FL_NOTARGET))
					{
						Actor nearest = GetNearestPlayer();
						if (nearest)
							alerter = nearest.player;
					}
				}
				
				if ((!(args[FLAGS] & FL_SILENT) || bSpawned) && !(args[FLAGS] & FL_NOFOG))
				{
					let tf = Spawn("TeleportFog", mo.pos);
					if (tf)
					{
						if (tf.pos.z < tf.floorz)
							tf.SetZ(tf.floorz);
						
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
				if (args[FLAGS] & FL_SETCALLER)
					level.ExecuteSpecial(226, mo, null, false, args[SCRIPT]);
				else
					level.ExecuteSpecial(226, self, null, false, args[SCRIPT]);
			}
			
			timer = args[SPAWN_DELAY];
			bSpawned = true;
		}
		else
			timer = TICRATE; // keep retrying every second
		
	}
	
	private Actor GetNearestPlayer()
	{
		if (!multiplayer)
			return players[0].mo;
		
		Actor validPlayer;
		uint closestIndex = MAXPLAYERS;
		double closestDist, closestValid;
		closestDist = closestValid = double.max;
		
		for (uint i = 0; i < MAXPLAYERS; ++i)
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
			else
			{
				if (closestIndex < MAXPLAYERS)
					validPlayer = players[closestIndex].mo;
				else
					validPlayer = players[0].mo;
			}
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
		{
			int multi = max(0, health > 0 ? wave-health : wave-1);
			s += ceil(args[SPAWN_LIMIT]*0.2*multi);
		}
		
		if (args[FLAGS] & FL_DIFFICULTY)
		{
			int skill = 1 + log(G_SkillPropertyInt(SKILLP_SpawnFilter)) / log(2);
			double multi;
			if (skill < 3)
			{
				multi = 1 / (1 + 0.25*(3-skill));
				s = ceil(s - args[SPAWN_LIMIT]*(1-multi));
			}
			else
			{
				multi = max(0, skill - 3);
				s += ceil(args[SPAWN_LIMIT]*0.25*multi);
			}
		}
		
		if (args[FLAGS] & FL_PLAYER)
		{
			int count;
			for (uint i = 0; i < MAXPLAYERS; ++i)
			{
				if (!playerInGame[i])
					continue;
				
				++count;
			}
			
			int multi = max(0, count-1);
			s += ceil(args[SPAWN_LIMIT]*0.3*multi);
		}
		
		return s;
	}
	
	clearscope int GetSpawnDelay() const
	{
		if (!(args[FLAGS] & FL_DELAY))
			return 0;
		
		int d = args[SPAWN_DELAY];
		if (args[FLAGS] & FL_DOUBLE)
			d *= 2;
		if (args[FLAGS] & FL_QUADRUPLE)
			d *= 4;
		if (args[FLAGS] & FL_HALF)
			d /= 2;
		
		return d;
	}
	
	clearscope bool InWaveRange(int wave) const
	{
		return (health <= 0 || wave >= health) && (score <= 0 || wave < score);
	}
	
	clearscope int RemainingSpawns() const
	{
		return spawnLimit;
	}
	
	clearscope bool Paused() const
	{
		return bPaused;
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