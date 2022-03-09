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
	FL_WAIT = 1<<3,
	FL_DELAY = 1<<4,
	FL_HALF = 1<<5,
	FL_DOUBLE = 1<<6,
	FL_QUADRUPLE = 1<<7
}

class InvasionSpawner : Actor abstract
{
	private Invasion mode;
	private int timer;
	private int spawnLimit;
	private bool bPaused;
	
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
		//$Arg4Enum { 1 = "Reset on new wave"; 2 = "Spawn between waves"; 4 = "Spawn sequentially"; 8 = "Spawn last"; 16 = "Use inital spawn delay"; 32 = "Halve intial spawn delay"; 64 = "Double initial spawn delay"; 128 = "Quadruple initial spawn delay"; }
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
		
		timer = GetSpawnDelay();
		spawnLimit = args[SPAWN_LIMIT];
		mode = Invasion.GetMode();
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
			if (args[flags] & FL_RESET)
				spawnLimit = args[SPAWN_LIMIT];
		}
		
		if ((args[FLAGS] & FL_SEQUENCE) && target)
		{
			if (target.bIsMonster && (target.bFriendly || target.health <= 0))
				target = null;
			else
			{
				let i = Inventory(target);
				if (i && i.owner)
					target = null;
			}
		}
		
		if (bDestroyed || bDormant || bPaused
			|| (health > 0 && mode.CurrentWave() < health)
			|| (mode.GameState() != GS_ACTIVE && !(args[FLAGS] & FL_ALWAYS))
			|| ((args[FLAGS] & FL_WAIT) && mode.RemainingEnemies() > mode.SpawnThreshold())
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
		
		bool spawned;
		Actor mo;
		[spawned, mo] = A_SpawnItemEx(type, flags: SXF_TRANSFERAMBUSHFLAG, tid: args[ACTOR_TID]);
		if (spawned)
		{
			if (mo)
			{
				let tf = Spawn("TeleportFog", mo.pos);
				if (tf)
				{
					if (tf.pos.z < tf.floorz)
						tf.SetZ(tf.floorz);
					
					tf.target = mo;
				}
			}
			
			if (spawnLimit > 0)
				--spawnLimit;
			if (args[FLAGS] & FL_SEQUENCE)
				target = mo;
			if (args[SCRIPT])
				ACS_ExecuteAlways(args[SCRIPT]);
			
			timer = args[SPAWN_DELAY];
		}
		else
			timer = TICRATE; // keep retrying every second
		
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
	
	clearscope bool HasSpawns() const
	{
		return args[SPAWN_LIMIT] <= 0 || spawnLimit > 0;
	}
	
	clearscope bool Paused() const
	{
		return bPaused;
	}
	
	void Pause(bool val)
	{
		bPaused = val;
	}
}