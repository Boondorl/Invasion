class FuturePlayerStarts
{
	private int wave;
	private FuturePlayerStart starts[MAXPLAYERS];

	static FuturePlayerStarts Create(int wave)
	{
		let fps = new("FuturePlayerStarts");
		fps.wave = Max(wave, 1);

		return fps;
	}

	void AddStart(FuturePlayerStart start)
	{
        int num = start.Args[FuturePlayerStart.PLAY_NUM] - 1;
        if (num >= 0 && num < MAXPLAYERS)
            starts[num] = start;
	}

	clearscope int GetWave() const
	{
		return wave;
	}

	clearscope FuturePlayerStart GetStart(int playNum) const
	{
		return playNum < 0 || playNum >= MAXPLAYERS ? null : starts[playNum];
	}
}

class Invasion : GameMode
{
    const COUNTDOWN_TIME = 5.0;
	const VICTORY_TIME = 3.0;

    enum EInvasionState
    {
        IS_INVALID = -1,
        IS_IDLE,
        IS_ENDED,
        IS_COUNTDOWN,
        IS_ACTIVE,
        IS_VICTORY
    }

    // Invasion info
    private bool bStarted;
	private bool bPaused;
	private bool bWaveStarted, bWaveFinished;
	private int totalWaves;
	private int waveTimer;
	private EInvasionState invasionState;
	private string objective;
	
	// Wave info
	private int enemies, healers;
	private int lastSpawnThreshold;
	private int wave;
	private int timer;

	private Array<FuturePlayerStarts> playerStarts;
	private Array<InvasionSpawner> spawners;
	private Array<Actor> waveMonsters, countedMonsters;

	private Map<int, bool> trackingTIDs;
	private Array<Actor> TIDTracked; // For monsters being tracked solely by their TID.

    override void OnDestroy()
    {
        foreach (s : spawners)
        {
			if (!s)
				continue;

            s.ActivateSpawner(false, null);
            s.Reset(true, true);
            s.Pause(false);
        }

        Super.OnDestroy();
    }

    clearscope int Seconds2Ticks(double s) const
    {
        if (s <= 0.0)
            return 0;

        return int(Min(Ceil(s * GameTicRate), int.max));
    }

    clearscope double Ticks2Seconds(int t) const
    {
        if (t <= 0)
            return 0.0;

        return double(t) / GameTicRate;
    }

    clearscope int GetRemainingInvasionEnemies() const
	{
		return enemies;
	}

	clearscope int GetRemainingInvasionHealers() const
	{
		return healers;
	}
	
	clearscope int GetInvasionLastSpawnThreshold() const
	{
		return lastSpawnThreshold;
	}
	
	clearscope int GetInvasionWave() const
	{
		return wave;
	}
	
	clearscope int GetTotalInvasionWaves() const
	{
		return totalWaves;
	}

	clearscope int GetInvasionTimer() const
	{
		return invasionState != IS_COUNTDOWN ? 0 : int(Ceil(Ticks2Seconds(timer)));
	}
	
	clearscope EInvasionState GetInvasionState() const
	{
		return invasionState;
	}
	
	clearscope bool InvasionWaveStarted() const
	{
		return bWaveStarted;
	}
	
	clearscope bool InvasionWaveEnded() const
	{
		return bWaveFinished;
	}
	
	clearscope bool InvasionStarted() const
	{
		return bStarted;
	}
	
	clearscope bool InvasionPaused() const
	{
		return bPaused;
	}

	clearscope string GetObjective() const
	{
		return StringTable.Localize(objective);
	}

    void StartInvasion(int wTotal, double wTimer, double initialTimer)
	{
		if (bStarted)
			return;
		
		bStarted = true;
		invasionState = IS_COUNTDOWN;
		wave = 1;
		totalWaves = wTotal;
		waveTimer = Seconds2Ticks(wTimer);

		// Cache spawners local to the invasion.
		InvasionSpawner s;
		let it = ThinkerIterator.Create("InvasionSpawner", InvasionSpawner.DEFAULT_STAT);
		while (s = InvasionSpawner(it.Next()))
		{
			if (s.user_InvasionID == GetID())
			{
				spawners.Push(s);
				if (s is "GenericSpawner")
					GenericSpawner(s).Initialize();
					
				s.Reset(true, true);
				s.ActivateSpawner(s.ShouldActivate(wave), self);
			}
		}	

		// Cache player starts local to the invasion.
		FuturePlayerStart start;
		it = ThinkerIterator.Create("FuturePlayerStart", FuturePlayerStart.DEFAULT_STAT);
		while (start = FuturePlayerStart(it.Next()))
		{
			if (start.user_InvasionID != GetID())
				continue;

			int i;
			for (; i < playerStarts.Size(); ++i)
			{
				if (playerStarts[i].GetWave() == start.Args[FuturePlayerStart.START_WAVE])
				{
					break;
				}
				else if (playerStarts[i].GetWave() > start.Args[FuturePlayerStart.START_WAVE])
				{
					playerStarts.Insert(i, FuturePlayerStarts.Create(start.Args[FuturePlayerStart.START_WAVE]));
					break;
				}
			}

			if (i >= playerStarts.Size())
				i = playerStarts.Push(FuturePlayerStarts.Create(start.Args[FuturePlayerStart.START_WAVE]));

			playerStarts[i].AddStart(start);
		}

		timer = Seconds2Ticks(initialTimer);
        if (timer <= 0)
            StartInvasionWave();
	}
	
	void EndInvasion(bool kill = true)
	{
		if (!bStarted)
			return;
		
		if (kill)
			ClearMonsters();

		RemoveCorpses();
		Destroy();
	}
	
	void PauseInvasion(bool val)
	{
		bPaused = val;
	}
	
	void StartInvasionWave()
	{
		if (!bStarted || invasionState != IS_COUNTDOWN)
			return;
		
		timer = 0;
		invasionState = IS_ACTIVE;
		bWaveStarted = true;
		objective = "";
		UpdateMonsterCount();
	}
	
	void EndInvasionWave()
	{
		if (!bStarted || invasionState != IS_ACTIVE)
			return;
		
		timer = Seconds2Ticks(VICTORY_TIME);
		if (totalWaves > 0 && wave >= totalWaves)
		{
			invasionState = IS_ENDED;
			wave = totalWaves;
		}
		else
		{
			invasionState = IS_VICTORY;
		}
		
		ClearMonsters();
	}

	void TrackTID(int tid)
	{
		if (!tid || trackingTIDs.CheckKey(tid))
			return;

		trackingTIDs.Insert(tid, true);

		Actor mo;
		let it = Level.CreateActorIterator(tid);
		while (mo = it.Next())
		{
			if (AddMonsterToCount(mo))
				TIDTracked.Push(mo);
		}
	}

	void ClearTrackingTID(int tid = 0)
	{
		Array<int> toRemove;
		if (!tid)
		{
			MapIterator<int, bool> mit;
			mit.Init(trackingTIDs);
			while (mit.Next())
				toRemove.Push(mit.GetKey());

			trackingTIDs.Clear();
		}
		else if (trackingTIDs.CheckKey(tid))
		{
			toRemove.Push(tid);
			trackingTIDs.Remove(tid);
		}

		if (!toRemove.Size())
			return;

		for(int i = TIDTracked.Size() - 1; i >= 0; --i)
		{
			if (toRemove.Find(TIDTracked[i].TID) < toRemove.Size())
			{
				RemoveMonsterFromCount(TIDTracked[i]);
				TIDTracked.Delete(i);
			}
		}
	}

    override void Tick()
    {
        bWaveStarted = bWaveFinished = false;
		if (!bStarted)
			return;
		
		if (!bPaused)
		{
			switch (invasionState)
			{
				case IS_VICTORY:
					DoVictory();
					break;
					
				case IS_COUNTDOWN:
					DoCountdown();
					break;
				
				case IS_ACTIVE:
					DoActive();
					break;

				case IS_ENDED:
					DoEnd();
					break;
			}

			if (bDestroyed)
				return;
		}

        foreach (s : spawners)
        {
            if (!s.bDormant && s.Activated())
                s.Tick();
        }
    }

    protected void DoVictory()
	{
		if (--timer > 0)
			return;

		timer = waveTimer;
		bWaveFinished = true;
		++wave;
		invasionState = IS_COUNTDOWN;

		RemoveCorpses();
        waveMonsters.Clear();
		countedMonsters.Clear();
		TIDTracked.Clear();

        ActivateSpawners();
	}
	
	protected void DoCountdown()
	{
		if (--timer <= 0)
			StartInvasionWave();
	}
	
	protected void DoActive()
	{
		timer = 0;
		if (enemies <= 0)
			EndInvasionWave();
	}

	protected void DoEnd()
	{
		if (--timer <= 0)
			Destroy();
	}

    void UpdateMonsterCount()
	{
        if (invasionState != IS_ACTIVE)
            return;

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
		if (invasionState != IS_ACTIVE || !s.Activated() || !s.CountMonster())
			return;
		
		int add = s.RemainingSpawns();
		if (s.bDormant)
			add = -add;
		
		enemies = Max(0, enemies + add);
		if (s.args[InvasionSpawner.FLAGS] & InvasionSpawner.FL_WAIT_MONST)
			lastSpawnThreshold = Max(0, lastSpawnThreshold + add);
	}
	
	void ClearMonsters()
	{
		foreach (mo : waveMonsters)
		{
			if (mo && !mo.bKilled)
				mo.A_Die();
		}
		
		foreach (s : spawners)
		{
			if (!s.bDormant && s.Activated() && s.CountMonster())
				s.ClearSpawns();
		}
		
		enemies = healers = lastSpawnThreshold = 0;
	}
	
	void RemoveCorpses()
	{
		foreach (mo : waveMonsters)
		{
			if (mo && mo.bKilled)
				Level.ExecuteSpecial(226, mo, null, false, -int('ExecuteCallbackFunction'));
		}
	}

    void ActivateSpawners()
    {
        foreach (s : spawners)
		{
			s.Reset(!(s.args[InvasionSpawner.FLAGS] & InvasionSpawner.FL_ALWAYS),
					s.args[InvasionSpawner.FLAGS] & InvasionSpawner.FL_RESET);

			s.ActivateSpawner(s.ShouldActivate(wave), self);
		}
    }

	bool AddMonsterToCount(Actor mo)
	{
		if (invasionState != IS_ACTIVE || !mo || !mo.bIsMonster || mo.bFriendly
			|| waveMonsters.Find(mo) >= waveMonsters.Size() || countedMonsters.Find(mo) < countedMonsters.Size())
		{
            return false;
		}

		countedMonsters.Push(mo);
		if (!mo.bKilled)
			++enemies;

		return true;
	}

	void RemoveMonsterFromCount(Actor mo)
	{
		if (invasionState != IS_ACTIVE || !mo || !mo.bIsMonster || mo.bFriendly)
            return;

		int index = countedMonsters.Find(mo);
		if (index >= countedMonsters.Size())
			return;

		countedMonsters.Delete(index);
		if (!mo.bKilled)
			--enemies;
	}

    bool AddWaveMonster(Actor mo, bool counted)
    {
        if (invasionState != IS_ACTIVE || !mo || !mo.bIsMonster || mo.bFriendly || waveMonsters.Find(mo) < waveMonsters.Size())
            return false;

        waveMonsters.Push(mo);
		if (counted)
			countedMonsters.Push(mo);
		if (!mo.bKilled && mo.FindState("Heal"))
			++healers;

		return true;
    }

	void RemoveWaveMonster(Actor mo)
	{
		if (invasionState != IS_ACTIVE || !mo || !mo.bIsMonster || mo.bFriendly)
            return;

		int index = waveMonsters.Find(mo);
		if (index >= waveMonsters.Size())
			return;

		waveMonsters.Delete(index);

		index = countedMonsters.Find(mo);
		if (index < countedMonsters.Size())
		{
			countedMonsters.Delete(index);
			if (!mo.bKilled)
				--enemies;
		}

		index = TIDTracked.Find(mo);
		if (index < TIDTracked.Size())
			TIDTracked.Delete(index);

		if (!mo.bKilled && mo.FindState("Heal"))
			--healers;
	}

	override void ThingSpawned(WorldEvent e)
	{
		if (e.Thing && e.Thing.bIsMonster && invasionState == IS_ACTIVE && trackingTIDs.CheckKey(e.Thing.TID) && AddMonsterToCount(e.Thing))
			TIDTracked.Push(e.Thing);
	}
	
	override void ThingRevived(WorldEvent e)
	{
		if (e.Thing && e.Thing.bIsMonster && invasionState == IS_ACTIVE)
		{
			if (countedMonsters.Find(e.Thing) < countedMonsters.Size())
				++enemies;
			if (e.Thing.FindState("Heal") && waveMonsters.Find(e.Thing) < waveMonsters.Size())
				++healers;
		}
	}
	
	override void ThingDied(WorldEvent e)
	{
		if (e.Thing && e.Thing.bIsMonster && invasionState == IS_ACTIVE)
		{
			if (countedMonsters.Find(e.Thing) < countedMonsters.Size())
				--enemies;
			if (e.Thing.FindState("Heal") && waveMonsters.Find(e.Thing) < waveMonsters.Size())
				--healers;
		}
	}
	
	override void ThingDestroyed(WorldEvent e)
	{
		if (e.Thing && e.Thing.bIsMonster && invasionState == IS_ACTIVE)
			RemoveWaveMonster(e.Thing);
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
				spot = starts.GetStart(e.PlayerNumber);
				if (!spot)
					spot = starts.GetStart(0);
			}
		}

		PlayerPawn mo = Players[e.PlayerNumber].Mo;
		if (spot)
			mo.Teleport(spot.Pos, spot.Angle, TF_TELEFRAG|TF_NOSRCFOG|TF_OVERRIDE);
		else if (!multiplayer)
			mo.Teleport(mo.Pos, mo.Angle, TF_TELEFRAG|TF_NOSRCFOG|TF_OVERRIDE);
	}

	void SetObjective(string obj)
	{
		objective = obj;
	}
	
	override void Draw(RenderEvent e)
	{
		if (!bStarted)
			return;
		
		Vector2 scale = (2.0, 2.4) * (Screen.GetHeight() / 1080.0);		
		int height = int(BigFont.GetHeight() * scale.Y);
		int w = int(Screen.GetWidth() * 0.5);

		int x, y;
		if (invasionState != IS_ENDED)
		{
			string waveCount = totalWaves > 0 ? String.Format(StringTable.Localize("$IN_WAVE"), wave, totalWaves) : String.Format(StringTable.Localize("$IN_ENDLESS"), wave);
			x = int(w - BigFont.StringWidth(waveCount) * scale.X * 0.5);
			Screen.DrawText(BigFont, -1, x, y, waveCount, DTA_ScaleX, scale.X, DTA_ScaleY, scale.Y);
			y += height;
		}

		if (invasionState == IS_ACTIVE && objective.Length())
		{
			string obj = GetObjective();
			x = int(w - BigFont.StringWidth(obj) * scale.X * 0.5);
			Screen.DrawText(BigFont, -1, x, y, obj, DTA_ScaleX, scale.X, DTA_ScaleY, scale.Y);
			y += height;
		}
		
		if (!bPaused || (invasionState == IS_ACTIVE && enemies > 0))
		{
			Vector2 textScale = (1.0, 1.0);
			string text;
			switch (invasionState)
			{
				case IS_COUNTDOWN:
					if (bWaveFinished)
						text = StringTable.Localize("$IN_DEFEATED");
					else if (timer <= Seconds2Ticks(COUNTDOWN_TIME))
						text = StringTable.Localize("$IN_PREPARE");
					else
						text = String.Format(StringTable.Localize("$IN_COUNTDOWN"), Ceil(Ticks2Seconds(timer)));
					break;
					
				case IS_ACTIVE:
					if (enemies <= 0)
					{
						if (totalWaves <= 0 || wave < totalWaves)
							text = StringTable.Localize("$IN_DEFEATED");
					}
					else
					{
						textScale = (0.75, 0.75);
						text = String.Format(enemies == 1 ? StringTable.Localize("$IN_ONE_REMAINING") : StringTable.Localize("$IN_REMAINING"), enemies);
					}
					break;
					
				case IS_VICTORY:
					text = StringTable.Localize("$IN_DEFEATED");
					break;
					
				case IS_ENDED:
					text = StringTable.Localize("$IN_VICTORY");
					break;
			}
			
			x = int(w - BigFont.StringWidth(text) * scale.X * 0.5 * textScale.X);
			Screen.DrawText(BigFont, -1, x, y, text, DTA_ScaleX, scale.X * textScale.X, DTA_ScaleY, scale.Y * textScale.Y);
			y += int(height * textScale.Y);

			if (invasionState == IS_ACTIVE && healers > 0)
			{
				string heal = String.Format(healers == 1 ? StringTable.Localize("$IN_ONE_HEALER") : StringTable.Localize("$IN_HEALER"), healers);
				x = int(w - BigFont.StringWidth(heal) * scale.X * 0.375);
				Screen.DrawText(BigFont, -1, x, y, heal, DTA_ScaleX, scale.X * 0.75, DTA_ScaleY, scale.Y * 0.75);
				y += int(height * 0.75);
			}
			
			if (invasionState == IS_COUNTDOWN && timer <= Seconds2Ticks(COUNTDOWN_TIME) && !bWaveFinished)
			{
				string counter = String.Format("%.0f", Ceil(Ticks2Seconds(timer)));
				x = int(w - BigFont.StringWidth(counter) * scale.X);
				Screen.DrawText(BigFont, -1, x, y, counter, DTA_ScaleX, scale.X * 2.0, DTA_ScaleY, scale.Y * 2.0);
			}
		}
	}

    // ACS Helpers
    clearscope static int GetMainID()
    {
        let mode = Invasion(GameModeHandler.Get().GetMainGameMode());
		return mode ? mode.GetID() : GameModeHandler.INVALID_MODE;
    }

	clearscope static int GetRemainingEnemies(int id)
	{
        let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		return mode ? mode.GetRemainingInvasionEnemies() : -1;
	}
	
	clearscope static int GetWave(int id)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		return mode ? mode.GetInvasionWave() : -1;
	}
	
	clearscope static int GetTotalWaves(int id)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		return mode ? mode.GetTotalInvasionWaves() : -1;
	}

	clearscope static int GetCountdownTimer(int id)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		return mode ? mode.GetInvasionTimer() : -1;
	}
	
	clearscope static int GetState(int id)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		return mode ? mode.GetInvasionState() : IS_INVALID;
	}
	
	clearscope static bool WaveStarted(int id)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		return mode ? mode.InvasionWaveStarted() : false;
	}
	
	clearscope static bool WaveEnded(int id)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		return mode ? mode.InvasionWaveEnded() : false;
	}
	
	clearscope static bool Started(int id)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		return mode ? mode.InvasionStarted() : false;
	}

    clearscope static bool Ended(int id)
    {
        let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		return mode ? mode.invasionState == IS_ENDED || mode.invasionState == IS_IDLE : true;
    }
	
	clearscope static bool Paused(int id)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		return mode ? mode.InvasionPaused() : false;
	}

	clearscope static bool IsMainInvasion(int id)
	{
		let handler = GameModeHandler.Get();
		return handler.FindGameMode(id, "Invasion") == handler.GetMainGameMode();
	}

    static void SetMainInvasion(int id)
    {
        let handler = GameModeHandler.Get();
		if (id < 0)
		{
			handler.SetMainGameMode(GameModeHandler.INVALID_MODE);
		}
		else
		{
			let [mode, index] = handler.FindGameMode(id, "Invasion");
			if (mode)
				handler.SetMainGameMode(index);
		}
    }
	
	static void Start(int id, int totalWaves, int waveTimer, int initialDelay, bool setMain = true)
	{
        let mode = Invasion(GameModeHandler.Get().AddGameMode("Invasion", id, setMain));
        if (mode)
            mode.StartInvasion(totalWaves, waveTimer, initialDelay);
	}
	
	static void End(int id, bool kill = true)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
        if (mode)
            mode.EndInvasion(kill);
	}
	
	static void Pause(int id, bool val)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
        if (mode)
            mode.PauseInvasion(val);
	}
	
	static void StartWave(int id)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
        if (mode)
            mode.StartInvasionWave();
	}
	
	static void EndWave(int id)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
        if (mode)
            mode.EndInvasionWave();
	}
	
	static void PauseSpawners(int tid, bool val)
	{
		let it = level.CreateActorIterator(tid, "InvasionSpawner");
		InvasionSpawner spawner;
		while (spawner = InvasionSpawner(it.Next()))
			spawner.Pause(val);
	}

	static void StartObjective(int id, string obj)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		if (mode)
			mode.SetObjective(obj);
	}

	static void AddMonsters(int id, int tid)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		if (mode)
			mode.TrackTID(tid);
	}

	static void RemoveMonsters(int id, int tid = 0)
	{
		let mode = Invasion(GameModeHandler.Get().FindGameMode(id, "Invasion"));
		if (mode)
			mode.ClearTrackingTID(tid);
	}

	static void SetCallback(Name callback)
	{
		ACS_ExecuteAlways(-int('SetCallbackFunction'), 0, -int(callback), 0, 0);
	}
}
