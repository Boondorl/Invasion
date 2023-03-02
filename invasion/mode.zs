enum EModeStates
{
	GS_INVALID = -1,
	GS_WAITING,
	GS_ENDED,
	GS_COUNTDOWN,
	GS_ACTIVE,
	GS_VICTORY
}

const COUNTDOWN_TIME = 5.0;
const VICTORY_TIME = 3.0;

class Invasion : EventHandler
{
	private bool bStarted;
	private bool bPaused;
	private bool bWaveStarted;
	private bool bWaveFinished;
	private int skipCounter;
	private int length;
	private int waveTimer;
	private int modeState;
	
	private int enemies;
	private int lastSpawnThreshold;
	private int wave;
	private int timer;

	private Array<Actor> toClear;

	bool bShowText;

	void ClearMode()
	{
		bStarted = bPaused = bWaveStarted = bWaveFinished = bShowText = false;
		skipCounter = length = waveTimer = enemies = lastSpawnThreshold = wave = timer = 0;
		modeState = GS_WAITING;
		toClear.Clear();

		ResetSpawners();
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

			case GS_ENDED:
				DoEnd();
				break;
		}
	}
	
	protected void DoVictory()
	{
		if (--timer > 0)
			return;

		timer = waveTimer;
		bWaveFinished = true;
		++wave;
		modeState = GS_COUNTDOWN;
		RemoveCorpses();
		toClear.Clear();
	}
	
	protected void DoCountdown()
	{
		if (--timer <= 0)
			WaveStart();
	}
	
	protected void DoActive()
	{
		timer = 0;
		if (enemies <= 0)
			WaveEnd();
	}

	protected void DoEnd()
	{
		if (--timer <= 0)
			ClearMode();
	}
	
	void UpdateMonsterCount()
	{
		InvasionSpawner inv;
		int counter, thresholdCounter;
		let it = ThinkerIterator.Create("InvasionSpawner", Thinker.STAT_FIRST_THINKING);
		while (inv = InvasionSpawner(it.Next()))
		{
			if (inv.bDormant || !inv.CountMonster() || !inv.InWaveRange(wave))
				continue;

			int add = inv.RemainingSpawns();
			counter += add;
			if (inv.args[InvasionSpawner.FLAGS] & InvasionSpawner.FL_WAIT_MONST)
				thresholdCounter += add;
		}
		
		enemies = counter;
		lastSpawnThreshold = thresholdCounter;
	}
	
	void ModifyMonsterCount(InvasionSpawner s)
	{
		if (modeState != GS_ACTIVE || !s.CountMonster() || !s.InWaveRange(wave))
			return;
		
		int add = s.RemainingSpawns();
		if (s.bDormant)
			add = -add;
		
		enemies = max(0, enemies + add);
		if (s.args[InvasionSpawner.FLAGS] & InvasionSpawner.FL_WAIT_MONST)
			lastSpawnThreshold = max(0, lastSpawnThreshold + add);
	}
	
	void ClearMonsters()
	{
		foreach (mo : toClear)
		{
			if (!mo || mo.bKilled)
				continue;

			mo.damageTypeReceived = 'None';
			mo.special1 = mo.health;
			mo.health = 0;
			mo.bKilled = true;
		}
		
		let it = ThinkerIterator.Create("InvasionSpawner", Thinker.STAT_FIRST_THINKING);
		InvasionSpawner s;
		while (s = InvasionSpawner(it.Next()))
		{
			if (!s.bDormant && s.CountMonster() && s.InWaveRange(wave))
				s.ClearSpawns();
		}
		
		enemies = lastSpawnThreshold = 0;
	}
	
	void RemoveCorpses()
	{
		foreach (mo : toClear)
		{
			if (mo && mo.bKilled)
				level.ExecuteSpecial(226, mo, null, false, -int('ExecuteCallbackFunction'));
		}
	}

	void ResetSpawners()
	{
		let it = ThinkerIterator.Create("InvasionSpawner", Thinker.STAT_FIRST_THINKING);
		InvasionSpawner s;
		while (s = InvasionSpawner(it.Next()))
			s.Reset();
	}
	
	void DisableCounter()
	{
		++skipCounter;
	}
	
	override void WorldThingSpawned(WorldEvent e)
	{
		if (!e.thing || !e.thing.bIsMonster || modeState != GS_ACTIVE)
			return;

		if (skipCounter > 0)
		{
			toClear.Push(e.thing);
			--skipCounter;
		}
	}
	
	override void WorldThingRevived(WorldEvent e)
	{
		if (!e.thing || !e.thing.bIsMonster || modeState != GS_ACTIVE || toClear.Find(e.thing) >= toClear.Size())
			return;
		
		++enemies;
	}
	
	override void WorldThingDied(WorldEvent e)
	{
		if (!e.thing || !e.thing.bIsMonster || modeState != GS_ACTIVE || toClear.Find(e.thing) >= toClear.Size())
			return;
		
		--enemies;
	}
	
	override void WorldThingDestroyed(WorldEvent e)
	{
		if (!e.thing || !e.thing.bIsMonster || modeState != GS_ACTIVE)
			return;

		int i = toClear.Find(e.thing);
		if (i < toClear.Size())
		{
			toClear.Delete(i);
			if (!e.thing.bKilled)
				--enemies;
		}
	}
	
	override void RenderOverlay(RenderEvent e)
	{
		if (!bStarted || modeState == GS_INVALID || !bShowText)
			return;
		
		Vector2 scale = (2,2.4) * (Screen.GetHeight() / 1080.);		
		int height = int(bigFont.GetHeight() * scale.y);
		int w = int(Screen.GetWidth() * 0.5);

		int x, y;
		if (modeState != GS_ENDED)
		{
			string waveCount = length > 0 ? String.Format(StringTable.Localize("$IN_WAVE"), wave, length) : String.Format(StringTable.Localize("$IN_ENDLESS"), wave);
			x = int(w - bigFont.StringWidth(waveCount)*scale.x*0.5);
			Screen.DrawText(bigFont, -1, x, y, waveCount, DTA_ScaleX, scale.x, DTA_ScaleY, scale.y);
			y += height;
		}
		
		if (!bPaused || (modeState == GS_ACTIVE && enemies > 0))
		{
			string text;
			switch (modeState)
			{
				case GS_COUNTDOWN:
					if (bWaveFinished)
						text = StringTable.Localize("$IN_DEFEATED");
					else if (timer <= ceil(COUNTDOWN_TIME*gameTicRate))
						text = StringTable.Localize("$IN_PREPARE");
					else
						text = String.Format(StringTable.Localize("$IN_COUNTDOWN"), ceil(double(timer) / TICRATE));
					break;
					
				case GS_ACTIVE:
					if (enemies == 1)
					{
						text = String.Format(StringTable.Localize("$IN_ONE_REMAINING"), enemies);
					}
					else if (!enemies)
					{
						if (length <= 0 || wave < length)
							text = StringTable.Localize("$IN_DEFEATED");
					}
					else
					{
						text = String.Format(StringTable.Localize("$IN_REMAINING"), enemies);
					}
					break;
					
				case GS_VICTORY:
					text = StringTable.Localize("$IN_DEFEATED");
					break;
					
				case GS_ENDED:
					text = StringTable.Localize("$IN_VICTORY");
					break;
			}
			
			x = int(w - bigFont.StringWidth(text)*scale.x*0.5);
			Screen.DrawText(bigFont, -1, x, y, text, DTA_ScaleX, scale.x, DTA_ScaleY, scale.y);
			
			if (modeState == GS_COUNTDOWN && timer <= ceil(COUNTDOWN_TIME*gameTicRate) && !bWaveFinished)
			{
				y += height;
				string counter = String.Format("%d", ceil(double(timer) / TICRATE));
				x = int(w - bigFont.StringWidth(counter)*scale.x);
				Screen.DrawText(bigFont, -1, x, y, counter, DTA_ScaleX, scale.x*2, DTA_ScaleY, scale.y*2);
			}
		}
	}

	override void PlayerRespawned(PlayerEvent e)
	{
		FuturePlayerStart spot, def, current;
		let it = ThinkerIterator.Create("FuturePlayerStart", STAT_FUTURE_PLAYER_START);
		while (spot = FuturePlayerStart(it.Next()))
		{
			if (spot.args[FuturePlayerStart.PLAY_NUM] == 0
				&& spot.args[FuturePlayerStart.START_WAVE] <= wave
				&& (!def || def.args[FuturePlayerStart.START_WAVE] < spot.args[FuturePlayerStart.START_WAVE]))
			{
				def = spot;
			}

			if (spot.args[FuturePlayerStart.PLAY_NUM] != e.playerNumber
				|| spot.args[FuturePlayerStart.START_WAVE] > wave)
			{
				continue;
			}
			
			if (!current || current.args[FuturePlayerStart.START_WAVE] < spot.args[FuturePlayerStart.START_WAVE])
				current = spot;
		}

		if (!current)
			current = def;

		PlayerPawn mo = players[e.playerNumber].mo;
		if (current)
			mo.Teleport(current.pos, current.angle, TF_TELEFRAG|TF_NOSRCFOG|TF_OVERRIDE);
		else if (!multiplayer)
			mo.Teleport(mo.pos, mo.angle, TF_TELEFRAG|TF_NOSRCFOG|TF_OVERRIDE);
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

	clearscope int GetTimer() const
	{
		if (modeState != GS_COUNTDOWN)
			return 0;

		return int(ceil(double(timer) / gameTicRate));
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
	
	void Start(int l, int t, bool v = true, bool nd = false)
	{
		if (bStarted)
			return;
		
		bStarted = true;
		modeState = GS_COUNTDOWN;
		wave = 1;
		length = l;
		waveTimer = t;
		bShowText = v;

		if (nd)
			WaveStart();
		else
			timer = t;
	}
	
	void End(bool kill = true)
	{
		if (!bStarted)
			return;
		
		if (kill)
			ClearMonsters();

		RemoveCorpses();
		ClearMode();
	}
	
	void Pause(bool val)
	{
		bPaused = val;
	}
	
	void WaveStart()
	{
		if (!bStarted || modeState != GS_COUNTDOWN)
			return;
		
		timer = 0;
		modeState = GS_ACTIVE;
		bWaveStarted = true;
		UpdateMonsterCount();
	}
	
	void WaveEnd()
	{
		if (!bStarted || modeState != GS_ACTIVE)
			return;
		
		timer = int(ceil(VICTORY_TIME*gameTicRate));
		if (length > 0 && wave >= length)
		{
			modeState = GS_ENDED;
			wave = length;
		}
		else
		{
			modeState = GS_VICTORY;
		}
		
		ClearMonsters();
		skipCounter = 0;
	}
	
	// ACS Helpers
	clearscope static Invasion GetMode()
	{
		return Invasion(EventHandler.Find("Invasion"));
	}
	
	clearscope static int GetRemainingEnemies()
	{
		return Invasion.GetMode().RemainingEnemies();
	}
	
	clearscope static int GetCurrentWave()
	{
		return Invasion.GetMode().CurrentWave();
	}
	
	clearscope static int GetGameLength()
	{
		return Invasion.GetMode().GameLength();
	}

	clearscope static int GetCountdownTimer()
	{
		return Invasion.GetMode().GetTimer();
	}
	
	clearscope static int GetGameState()
	{
		return Invasion.GetMode().GameState();
	}
	
	clearscope static bool GetWaveStarted()
	{
		return Invasion.GetMode().WaveStarted();
	}
	
	clearscope static bool GetWaveEnded()
	{
		return Invasion.GetMode().WaveEnded();
	}
	
	clearscope static bool GetGameStarted()
	{
		return Invasion.GetMode().Started();
	}
	
	clearscope static bool GetGamePaused()
	{
		return Invasion.GetMode().Paused();
	}
	
	static void StartGame(int length, int timer, bool textVis = true, bool noDel = false)
	{
		Invasion.GetMode().Start(length, timer, textVis, noDel);
	}
	
	static void EndGame(bool kill = true)
	{
		Invasion.GetMode().End(kill);
	}
	
	static void PauseGame(bool val)
	{
		Invasion.GetMode().Pause(val);
	}
	
	static void StartWave()
	{
		Invasion.GetMode().WaveStart();
	}
	
	static void EndWave()
	{
		Invasion.GetMode().WaveEnd();
	}
	
	static void PauseSpawners(int tid, bool val)
	{
		let it = level.CreateActorIterator(tid, "InvasionSpawner");
		InvasionSpawner spawner;
		while (spawner = InvasionSpawner(it.Next()))
			spawner.Pause(val);
	}

	static void SetCallback(Name s)
	{
		ACS_ExecuteAlways(-int('SetCallbackFunction'), 0, -int(s), 0, 0);
	}

	static void TextVisible(bool vis)
	{
		Invasion.GetMode().bShowText = vis;
	}

	clearscope static bool GetTextVisible()
	{
		return Invasion.GetMode().bShowText;
	}
}