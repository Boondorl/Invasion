enum EModeStates
{
	GS_INVALID = -1,
	GS_WAITING,
	GS_ENDED,
	GS_COUNTDOWN,
	GS_ACTIVE,
	GS_VICTORY
}

const COUNTDOWN_TIME = Thinker.TICRATE * 5;
const VICTORY_TIME = Thinker.TICRATE * 3;

class Invasion : EventHandler
{
	private bool bStarted;
	private bool bPaused;
	private bool bWaveStarted;
	private bool bWaveFinished;
	private int length;
	private int waveTimer;
	private int modeState;
	
	private int enemies;
	private int lastSpawnThreshold;
	private int wave;
	private int timer;
	
	private Dictionary ignore;
	
	override void OnRegister()
	{
		ignore = Dictionary.Create();
	}
	
	override void WorldLoaded(WorldEvent e)
	{
		if (modeState != GS_WAITING)
		{
			bStarted = bPaused = bWaveStarted = bWaveFinished = false;
			length = wave = waveTimer = timer = 0;
			modeState = GS_WAITING;
			ClearMonsters();
			RemoveCorpses();
		}
	}
	
	override void WorldTick()
	{
		bWaveStarted = bWaveFinished = false;
		if (!bStarted || bPaused)
			return;
		
		switch (modeState)
		{
			case GS_VICTORY:
				DoVictory();
				break;
				
			case GS_COUNTDOWN:
				DoCountdown();
				break;
			
			case GS_ACTIVE:
				DoActive();
				break;
		}
	}
	
	private void DoVictory()
	{
		--timer;
		if (timer <= 0)
		{
			timer = waveTimer;
			bWaveFinished = true;
			++wave;
			modeState = GS_COUNTDOWN;
			RemoveCorpses();
		}
	}
	
	private void DoCountdown()
	{
		--timer;
		if (timer <= 0)
			WaveStart();
	}
	
	private void DoActive()
	{
		timer = 0;
		if (enemies <= 0)
			WaveEnd();
	}
	
	void UpdateMonsterCount()
	{
		let it = ThinkerIterator.Create("InvasionSpawner", Thinker.STAT_FIRST_THINKING);
		InvasionSpawner inv;
		int counter, thresholdCounter;
		while (inv = InvasionSpawner(it.Next()))
		{
			int add = 0;
			if (!inv.bDormant && inv.InWaveRange(wave))
			{
				add = inv.RemainingSpawns();
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
			if (!(inv.args[FLAGS] & FL_WAITMONST))
				thresholdCounter += add;
		}
		
		enemies = counter;
		lastSpawnThreshold = max(0, counter - thresholdCounter);
	}
	
	void ClearMonsters()
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
		
		it = ThinkerIterator.Create("InvasionSpawner", Thinker.STAT_FIRST_THINKING);
		InvasionSpawner s;
		while (s = InvasionSpawner(it.Next()))
		{
			bool dontWipe = true;
			if (!s.bDormant && s.InWaveRange(wave))
			{
				dontWipe = false;
				let di = s.GetDropItems();
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
								dontWipe = true;
								break;
							}
						}
					}
					
					di = di.Next;
				}
			}
			
			if (!dontWipe)
				s.ClearSpawns();
		}
		
		enemies = lastSpawnThreshold = 0;
	}
	
	void RemoveCorpses()
	{
		let it = ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT);
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (mo.bIsMonster && mo.health <= 0)
				mo.Destroy();
		}
	}
	
	void AddIgnore(Actor mo)
	{
		if (mo)
			ignore.Insert(String.Format("%p", mo), "1");
	}
	
	override void WorldThingSpawned(WorldEvent e)
	{
		if (!e.thing || !e.thing.bIsMonster)
			return;
		
		string key = String.Format("%p", e.thing);
		if (ignore.At(key) != "")
		{
			ignore.Remove(key);
			return;
		}
		
		++enemies;
	}
	
	override void WorldThingRevived(WorldEvent e)
	{
		if (!e.thing || !e.thing.bIsMonster)
			return;
		
		++enemies;
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
	
	override void RenderOverlay(RenderEvent e)
	{
		if (!bStarted || modeState == GS_INVALID)
			return;
		
		Vector2 scale = (2,2.4) * (Screen.GetHeight() / 1080.);		
		int height = bigfont.GetHeight() * scale.y;
		int w = Screen.GetWidth() / 2;
		int x, y;
		if (modeState != GS_ENDED)
		{
			string waveCount = String.Format("Wave %d of %d", wave, length);
			x = w - bigfont.StringWidth(waveCount)*scale.x/2;
			Screen.DrawText(bigfont, -1, x, y, waveCount, DTA_ScaleX, scale.x, DTA_ScaleY, scale.y);
			y += height;
		}
		
		if (!bPaused || (modeState == GS_ACTIVE && enemies > 0))
		{
			string text;
			switch (modeState)
			{
				case GS_COUNTDOWN:
					if (timer <= COUNTDOWN_TIME)
						text = "Prepare for battle!";
					else
						text = String.Format("Next wave in %d seconds", ceil(double(timer) / TICRATE));
					break;
					
				case GS_ACTIVE:
					text = String.Format("%d enemies remaining", enemies);
					break;
					
				case GS_VICTORY:
					text = "Wave defeated!";
					break;
					
				case GS_ENDED:
					text = "Invasion defeated!";
					break;
			}
			
			x = w - bigfont.StringWidth(text)*scale.x/2;
			Screen.DrawText(bigfont, -1, x, y, text, DTA_ScaleX, scale.x, DTA_ScaleY, scale.y);
			
			if (modeState == GS_COUNTDOWN && timer <= COUNTDOWN_TIME)
			{
				y += height;
				string counter = String.Format("%d", ceil(double(timer) / TICRATE));
				x = w - bigfont.StringWidth(counter)*scale.x;
				Screen.DrawText(bigfont, -1, x, y, counter, DTA_ScaleX, scale.x*2, DTA_ScaleY, scale.y*2);
			}
		}
	}
	
	// Getters
	clearscope int RemainingEnemies() const
	{
		return enemies;
	}
	
	clearscope int SpawnThreshold() const
	{
		return lastSpawnThreshold;
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
		return bWaveFinished;
	}
	
	clearscope bool Started() const
	{
		return bStarted;
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
		modeState = GS_COUNTDOWN;
		wave = 1;
		length = l;
		timer = waveTimer = t;
	}
	
	void End()
	{
		if (!bStarted)
			return;
		
		wave = length;
		timer = 0;
		modeState = GS_ENDED;
		ClearMonsters();
	}
	
	void Pause(bool val)
	{
		bPaused = val;
	}
	
	void WaveStart()
	{
		if (!bStarted)
			return;
		
		if (modeState == GS_COUNTDOWN)
		{
			timer = 0;
			modeState = GS_ACTIVE;
			bWaveStarted = true;
			UpdateMonsterCount();
		}
	}
	
	void WaveEnd()
	{
		if (!bStarted)
			return;
		
		if (modeState == GS_ACTIVE)
		{
			if (wave >= length)
			{
				timer = 0;
				wave = length;
				modeState = GS_ENDED;
			}
			else
			{
				modeState = GS_VICTORY;
				timer = VICTORY_TIME;
			}
			
			ClearMonsters();
		}
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
	
	static void EndGame()
	{
		let inv = Invasion.GetMode();
		if (inv)
			inv.End();
	}
	
	static void PauseGame(bool val)
	{
		let inv = Invasion.GetMode();
		if (inv)
			inv.Pause(val);
	}
	
	static void StartWave()
	{
		let inv = Invasion.GetMode();
		if (inv)
			inv.WaveStart();
	}
	
	static void EndWave()
	{
		let inv = Invasion.GetMode();
		if (inv)
			inv.WaveEnd();
	}
	
	static void PauseSpawners(int tid, bool val)
	{
		let it = level.CreateActorIterator(tid, "InvasionSpawner");
		InvasionSpawner spawner;
		while (spawner = InvasionSpawner(it.Next()))
			spawner.Pause(val);
	}
}