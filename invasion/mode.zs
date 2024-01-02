class FuturePlayerStarts
{
	private int wave;
	private Map<int, FuturePlayerStart> starts;

	static FuturePlayerStarts Create(int wave)
	{
		let fps = new("FuturePlayerStarts");
		fps.wave = wave;

		return fps;
	}

	void AddStart(FuturePlayerStart start)
	{
		starts.Insert(start.args[FuturePlayerStart.PLAY_NUM], start);
	}

	int GetWave() const
	{
		return wave;
	}

	FuturePlayerStart GetStart(int playNum) const
	{
		return starts.GetIfExists(playNum);
	}
}

enum EModeStates
{
	GS_INVALID = -1,
	GS_WAITING,
	GS_ENDED,
	GS_COUNTDOWN,
	GS_ACTIVE,
	GS_VICTORY
}

class Invasion : EventHandler
{
	const COUNTDOWN_TIME = 5.0;
	const VICTORY_TIME = 3.0;

	// Game mode info
	private int mapSkill;
	private bool bStarted;
	private bool bPaused;
	private bool bWaveStarted;
	private bool bWaveFinished;
	private int length;
	private int waveTimer;
	private EModeStates modeState;
	private int modeID;
	
	// Wave info
	private int skipCounter;
	private int enemies, healers;
	private int lastSpawnThreshold;
	private int wave;
	private int timer;

	private Array<FuturePlayerStarts> playerStarts;
	private Array<InvasionSpawner> spawners;
	private Array<Actor> toClear;

	bool bShowText;

	override void WorldLoaded(WorldEvent e)
	{
		if (!e.isReopen)
			mapSkill = 1 + int(log(G_SkillPropertyInt(SKILLP_SpawnFilter)) / log(2));
	}

	void ClearMode()
	{
		bStarted = bPaused = bWaveStarted = bWaveFinished = bShowText = false;
		skipCounter = length = waveTimer = enemies = healers = lastSpawnThreshold = wave = timer = modeID = 0;
		modeState = GS_WAITING;

		foreach (s : spawners)
		{
			s.Reset(true, true);
			s.ActivateSpawner(false);
		}

		playerStarts.Clear();
		spawners.Clear();
		toClear.Clear();
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

		foreach (s : spawners)
		{
			s.Reset(!(s.args[InvasionSpawner.FLAGS] & InvasionSpawner.FL_ALWAYS),
					s.args[InvasionSpawner.FLAGS] & InvasionSpawner.FL_RESET);

			s.ActivateSpawner(s.ShouldActivate(wave));
		}
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
		int counter, thresholdCounter;
		foreach (s : spawners)
		{
			if (s.bDormant || !s.Activated()|| !s.CountMonster())
				continue;

			int add = s.RemainingSpawns();
			counter += add;
			if (s.args[InvasionSpawner.FLAGS] & InvasionSpawner.FL_WAIT_MONST)
				thresholdCounter += add;
		}
		
		enemies = counter;
		lastSpawnThreshold = thresholdCounter;
	}
	
	void ModifyMonsterCount(InvasionSpawner s)
	{
		if (modeState != GS_ACTIVE || s.user_InvasionID != modeID
			|| !s.Activated() || !s.CountMonster())
		{
			return;
		}
		
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
			if (mo.bKilled)
				continue;

			mo.damageTypeReceived = 'None';
			mo.special1 = mo.health;
			mo.health = 0;
			mo.bKilled = true;
		}
		
		foreach (s : spawners)
		{
			if (!s.bDormant && s.Activated() && s.CountMonster())
				s.ClearSpawns();
		}
		
		enemies = healers = lastSpawnThreshold = skipCounter = 0;
	}
	
	void RemoveCorpses()
	{
		foreach (mo : toClear)
		{
			if (mo.bKilled)
				level.ExecuteSpecial(226, mo, null, false, -int('ExecuteCallbackFunction'));
		}
	}
	
	void DisableCounter()
	{
		++skipCounter;
	}
	
	override void WorldThingSpawned(WorldEvent e)
	{
		if (e.thing && e.thing.bIsMonster && modeState == GS_ACTIVE && skipCounter > 0)
		{
			--skipCounter;
			toClear.Push(e.thing);
			if (e.thing.FindState("Heal"))
				++healers;
		}
	}
	
	override void WorldThingRevived(WorldEvent e)
	{
		if (e.thing && e.thing.bIsMonster && modeState == GS_ACTIVE && toClear.Find(e.thing) < toClear.Size())
		{
			++enemies;
			if (e.thing.FindState("Heal"))
				++healers;
		}
	}
	
	override void WorldThingDied(WorldEvent e)
	{
		if (e.thing && e.thing.bIsMonster && modeState == GS_ACTIVE && toClear.Find(e.thing) < toClear.Size())
		{
			--enemies;
			if (e.thing.FindState("Heal"))
				--healers;
		}
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
			{
				--enemies;
				if (e.thing.FindState("Heal"))
					--healers;
			}
		}
	}
	
	override void RenderOverlay(RenderEvent e)
	{
		if (!bStarted || modeState == GS_INVALID || !bShowText)
			return;
		
		Vector2 scale = (2.0, 2.4) * (Screen.GetHeight() / 1080.0);		
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
					else if (timer <= int(ceil(COUNTDOWN_TIME*gameTicRate)))
						text = StringTable.Localize("$IN_PREPARE");
					else
						text = String.Format(StringTable.Localize("$IN_COUNTDOWN"), int(ceil(double(timer) / gameTicRate)));
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
			y += height;

			if (modeState == GS_ACTIVE && healers > 0)
			{
				string heal = String.Format(StringTable.Localize("$IN_HEALERS"), healers);
				x = int(w - bigFont.StringWidth(heal)*scale.x*0.5);
				Screen.DrawText(bigFont, -1, x, y, heal, DTA_ScaleX, scale.x, DTA_ScaleY, scale.y);
				y += height;
			}
			
			if (modeState == GS_COUNTDOWN && timer <= int(ceil(COUNTDOWN_TIME*gameTicRate)) && !bWaveFinished)
			{
				string counter = String.Format("%d", int(ceil(double(timer) / gameTicRate)));
				x = int(w - bigFont.StringWidth(counter)*scale.x);
				Screen.DrawText(bigFont, -1, x, y, counter, DTA_ScaleX, scale.x*2, DTA_ScaleY, scale.y*2);
			}
		}
	}

	override void PlayerRespawned(PlayerEvent e)
	{
		FuturePlayerStart spot;
		if (playerStarts.Size())
		{
			FuturePlayerStarts starts;
			foreach (fps : playerStarts)
			{
				if (fps.GetWave() > wave)
					break;

				starts = fps;
			}

			if (starts)
			{
				spot = starts.GetStart(e.playerNumber);
				if (!spot)
					spot = starts.GetStart(0);
			}
		}

		PlayerPawn mo = players[e.playerNumber].mo;
		if (spot)
			mo.Teleport(spot.pos, spot.angle, TF_TELEFRAG|TF_NOSRCFOG|TF_OVERRIDE);
		else if (!multiplayer)
			mo.Teleport(mo.pos, mo.angle, TF_TELEFRAG|TF_NOSRCFOG|TF_OVERRIDE);
	}
	
	// Getters
	clearscope int GetSkill() const
	{
		return mapSkill;
	}

	clearscope int RemainingEnemies() const
	{
		return enemies;
	}

	clearscope int RemainingHealers() const
	{
		return healers;
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
		return modeState != GS_COUNTDOWN ? 0 : int(ceil(double(timer) / gameTicRate));
	}
	
	clearscope int GameState() const
	{
		return modeState;
	}

	clearscope int GameID() const
	{
		return modeID;
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
	
	void Start(int l, int t, bool v = true, bool nd = false, int id = 0)
	{
		if (bStarted)
			return;
		
		bStarted = true;
		modeState = GS_COUNTDOWN;
		modeID = id;
		wave = 1;
		length = l;
		waveTimer = t;
		bShowText = v;

		// Cache spawners local to the invasion
		InvasionSpawner s;
		let it = ThinkerIterator.Create("InvasionSpawner", STAT_IDLE_SPAWNERS);
		while (s = InvasionSpawner(it.Next()))
		{
			if (s.user_InvasionID == modeID)
			{
				spawners.Push(s);
				s.ActivateSpawner(s.ShouldActivate(wave));
			}
		}

		// Cache player starts local to the invasion
		FuturePlayerStart start;
		it = ThinkerIterator.Create("FuturePlayerStart", STAT_FUTURE_PLAYER_START);
		while (start = FuturePlayerStart(it.Next()))
		{
			if (start.user_InvasionID != modeID)
				continue;

			int i;
			for (; i < playerStarts.Size(); ++i)
			{
				if (playerStarts[i].GetWave() > start.args[FuturePlayerStart.START_WAVE])
				{
					--i;
					if (i < 0 || playerStarts[i].GetWave() < start.args[FuturePlayerStart.START_WAVE])
						playerStarts.Insert(++i, FuturePlayerStarts.Create(start.args[FuturePlayerStart.START_WAVE]));

					break;
				}
			}

			if (i >= playerStarts.Size())
				i = playerStarts.Push(FuturePlayerStarts.Create(start.args[FuturePlayerStart.START_WAVE]));

			playerStarts[i].AddStart(start);
		}

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

	clearscope static bool GetTextVisible()
	{
		return Invasion.GetMode().bShowText;
	}
	
	static void StartGame(int length, int timer, bool textVis = true, bool noDel = false, int id = 0)
	{
		Invasion.GetMode().Start(length, timer, textVis, noDel, id);
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
}