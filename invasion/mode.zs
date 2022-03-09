enum EModeStates
{
	GS_INVALID = -1,
	GS_IDLE,
	GS_COUNTDOWN,
	GS_ACTIVE,
	GS_END
}

const COUNTDOWN_TIME = Thinker.TICRATE * 10;

class Invasion : EventHandler
{
	private bool bStarted;
	private bool bPaused;
	private bool bWaveEnded;
	private bool bWaveStarted;
	
	private int length;
	private int waveTimer;
	
	private int modeState;
	private int enemies;
	private int wave;
	private int timer;
	
	override void WorldTick()
	{
		if (!bStarted || bPaused)
			return;
		
		bWaveStarted = bWaveEnded = false;
		switch (modeState)
		{
			case GS_IDLE:
				DoIdle();
				break;
				
			case GS_COUNTDOWN:
				DoCountDown();
				break;
				
			case GS_ACTIVE:
				DoActive();
				break;
				
			case GS_END:
				DoEnd();
				break;
		}
	}
	
	virtual void DoIdle()
	{
		--timer;
		if (timer <= 0)
		{
			modeState = GS_ACTIVE;
			bWaveStarted = true;
			UpdateMonsterCount();
		}
		else if (timer <= COUNTDOWN_TIME)
			modeState = GS_COUNTDOWN;
	}
	
	virtual void DoCountDown()
	{
		--timer;
		if (timer <= 0)
		{
			modeState = GS_ACTIVE;
			bWaveStarted = true;
			UpdateMonsterCount();
		}
		else if (timer > COUNTDOWN_TIME)
			modeState = GS_IDLE;
	}
	
	virtual void DoActive()
	{
		timer = 0;
		if (enemies <= 0)
		{
			if (wave >= length)
				modeState = GS_END;
			else
			{
				modeState = GS_IDLE;
				bWaveEnded = true;
				timer = waveTimer;
				++wave;
				ClearMonsters();
			}
		}
	}
	
	virtual void DoEnd() {}
	
	protected void UpdateMonsterCount()
	{
		let it = ThinkerIterator.Create("InvasionSpawner", Thinker.STAT_FIRST_THINKING);
		InvasionSpawner inv;
		int counter;
		while (inv = InvasionSpawner(it.Next()))
		{
			int add = 0;
			if (!inv.bDormant && inv.args[SPAWN_LIMIT] > 0)
			{
				add = inv.args[SPAWN_LIMIT];
				let di = inv.GetDropItems();
				while (di)
				{
					// if it has any chance to spawn non-monsters it shouldn't be counted
					if (di.Name != 'None')
					{
						class<Actor> type = di.Name;
						if (type)
						{
							let def = GetDefaultByType(Actor.GetReplacement(type));
							if (!def.bIsMonster || def.bFriendly)
							{
								add = 0;
								break;
							}
						}
					}
					
					di = di.Next;
				}
			}
			
			counter += add;
		}
		
		enemies = counter;
	}
	
	protected void ClearMonsters()
	{
		let it = ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT);
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (mo.bIsMonster && !mo.bFriendly && mo.health > 0)
			{
				mo.damageTypeReceived = 'None';
				mo.special1 = mo.health;
				mo.health = 0;
				mo.Die(null, null);
			}
		}
		
		enemies = 0;
	}
	
	override void WorldThingDied(WorldEvent e)
	{
		if (!e.thing || !e.thing.bIsMonster)
			return;
		
		--enemies;
	}
	
	override void WorldThingDestroyed(WorldEvent e)
	{
		if (!e.thing || !e.thing.bIsMonster || e.thing.health <= 0)
			return;
		
		--enemies;
	}
	
	override void WorldThingRevived(WorldEvent e)
	{
		if (!e.thing || !e.thing.bIsMonster)
			return;
		
		++enemies;
	}
	
	override void RenderOverlay(RenderEvent e)
	{
		if (!bStarted || modeState == GS_INVALID)
			return;
		
		int height = bigfont.GetHeight() * 2.4;
		int w = Screen.GetWidth() / 2;
		int x, y;
		if (modeState != GS_END)
		{
			string waveCount = String.Format("Wave %d of %d", wave, length);
			x = w - bigfont.StringWidth(waveCount);
			Screen.DrawText(bigfont, -1, x, y, waveCount, DTA_ScaleX, 2, DTA_ScaleY, 2.4);
			y += height;
		}
		
		if (!bPaused)
		{
			string text;
			switch (modeState)
			{
				case GS_IDLE:
					text = String.Format("Next wave in %d seconds", timer / TICRATE);
					break;
					
				case GS_COUNTDOWN:
					text = "Prepare for battle!";
					break;
					
				case GS_ACTIVE:
					text = String.Format("%d enemies remaining", enemies);
					break;
					
				case GS_END:
					text = "Completed!";
					break;
			}
			
			x = w - bigfont.StringWidth(text);
			Screen.DrawText(bigfont, -1, x, y, text, DTA_ScaleX, 2, DTA_ScaleY, 2.4);
			
			if (modeState == GS_COUNTDOWN)
			{
				y += height;
				string counter = String.Format("%d", timer / TICRATE);
				x = w - bigfont.StringWidth(counter)*2;
				Screen.DrawText(bigfont, -1, x, y, counter, DTA_ScaleX, 4, DTA_ScaleY, 4.8);
			}
		}
	}
	
	// Getters
	clearscope int RemainingEnemies() const
	{
		return enemies;
	}
	
	clearscope int CurrentWave() const
	{
		return wave;
	}
	
	clearscope int GameLength() const
	{
		return length;
	}
	
	clearscope int GameState() const
	{
		return modeState;
	}
	
	clearscope bool WaveStarted() const
	{
		return bWaveStarted;
	}
	
	clearscope bool WaveEnded() const
	{
		return bWaveEnded;
	}
	
	clearscope bool Started() const
	{
		return bStarted;
	}
	
	clearscope bool Ended() const
	{
		return modeState == GS_END;
	}
	
	clearscope bool Paused() const
	{
		return bPaused;
	}
	
	void Start(int l, int t)
	{
		if (bStarted)
			return;
		
		bStarted = true;
		wave = 1;
		length = l;
		timer = waveTimer = t;
	}
	
	void Pause(bool val)
	{
		bPaused = val;
	}
	
	// ACS Helpers
	clearscope static Invasion GetMode()
	{
		return Invasion(EventHandler.Find("Invasion"));
	}
	
	clearscope static int GetRemainingEnemies()
	{
		let inv = Invasion.GetMode();
		if (!inv)
			return 0;
		
		return inv.RemainingEnemies();
	}
	
	clearscope static int GetCurrentWave()
	{
		let inv = Invasion.GetMode();
		if (!inv)
			return 0;
		
		return inv.CurrentWave();
	}
	
	clearscope static int GetGameLength()
	{
		let inv = Invasion.GetMode();
		if (!inv)
			return 0;
		
		return inv.GameLength();
	}
	
	clearscope static int GetGameState()
	{
		let inv = Invasion.GetMode();
		if (!inv)
			return GS_INVALID;
		
		return inv.GameState();
	}
	
	clearscope static bool GetWaveStarted()
	{
		let inv = Invasion.GetMode();
		if (!inv)
			return false;
		
		return inv.WaveStarted();
	}
	
	clearscope static bool GetWaveEnded()
	{
		let inv = Invasion.GetMode();
		if (!inv)
			return false;
		
		return inv.WaveEnded();
	}
	
	clearscope static bool GetGameStarted()
	{
		let inv = Invasion.GetMode();
		if (!inv)
			return false;
		
		return inv.Started();
	}
	
	clearscope static bool GetGameEnded()
	{
		let inv = Invasion.GetMode();
		if (!inv)
			return false;
		
		return inv.Ended();
	}
	
	clearscope static bool GetGamePaused()
	{
		let inv = Invasion.GetMode();
		if (!inv)
			return false;
		
		return inv.Paused();
	}
	
	static void StartGame(int length, int timer)
	{
		let inv = Invasion.GetMode();
		if (inv)
			inv.Start(length, timer);
	}
	
	static void PauseGame(bool val)
	{
		let inv = Invasion.GetMode();
		if (inv)
			inv.Pause(val);
	}
	
	static void PauseSpawners(int tid, bool val)
	{
		let it = level.CreateActorIterator(tid, "InvasionSpawner");
		InvasionSpawner spawner;
		while (spawner = InvasionSpawner(it.Next()))
			spawner.Pause(val);
	}
}