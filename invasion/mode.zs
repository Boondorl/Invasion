class GameMode play
{
	private bool bSetID;
	private int ID;

	void SetID(int newID)
	{
		if (bSetID)
			return;

		ID = newID;
		bSetID = true;
	}

	clearscope int GetID() const
	{
		return ID;
	}

	virtual void Initialize() {}
	virtual void Tick() {}
	virtual void ThingSpawned(WorldEvent e) {}
	virtual void ThingRevived(WorldEvent e) {}
	virtual void ThingDied(WorldEvent e) {}
	virtual void ThingDestroyed(WorldEvent e) {}
	virtual void ThingDamaged(WorldEvent e) {}
	virtual void ThingGrounded(WorldEvent e) {}
	virtual void PlayerEntered(PlayerEvent e) {}
	virtual void PlayerSpawned(PlayerEvent e) {}
	virtual bool PlayerRespawning(PlayerEvent e) { return true; }
	virtual void PlayerRespawned(PlayerEvent e) {}
	virtual void PlayerDied(PlayerEvent e) {}
	virtual void PlayerDisconnected(PlayerEvent e) {}
	virtual void CheckReplacement(ReplaceEvent e) {}
	virtual void CheckReplacee(ReplacedEvent e) {}
	virtual void NetworkProcess(ConsoleEvent e) {}
	virtual void NetworkCommandProcess(NetworkCommand cmd) {}
	virtual ui void UITick() {}
	virtual ui void PostUITick() {}
	virtual ui void Draw(RenderEvent e) {}
	virtual ui void ConsoleProcess(ConsoleEvent e) {}
	virtual ui void InterfaceProcess(ConsoleEvent e) {}

	override void OnDestroy()
	{
		Super.OnDestroy();

		let handler = GameModeHandler.Get();
		handler.RemoveGameMode(handler.GetGameModeIndex(self));
	}
}

class GameModeHandler : EventHandler
{
	const INVALID_MODE = -1;

	private int mapSkill;
	private int mainMode;
	private Array<GameMode> gameModes;

	static clearscope GameModeHandler Get()
	{
		return GameModeHandler(Find("GameModeHandler"));
	}

	clearscope int GetMapSkill() const
	{
		return mapSkill;
	}

	GameMode AddGameMode(class<GameMode> type, int id, bool setMain = true)
	{
		if (!type)
			return null;

		if (id < 0)
		{
			Console.Printf("%sWarning: Negative ID %d is invalid. Game mode failed to create.", Font.TEXTCOLOR_YELLOW, id);
			return null;
		}

		let existing = FindGameMode(id, type);
		if (existing)
		{
			Console.Printf("%sWarning: ID %d of type %s already exists. Game mode failed to create.", Font.TEXTCOLOR_YELLOW, id, type.GetClassName());
			return null;
		}

		let mode = GameMode(new(type));
		mode.SetID(id);
		mode.Initialize();
		if (mode.bDestroyed)
			return null;

		int i = gameModes.Push(mode);
		if (setMain)
			SetMainGameMode(i);

		return mode;
	}

	void SetMainGameMode(int i)
	{
		mainMode = i < 0 || i >= gameModes.Size() || !gameModes[i] ? INVALID_MODE : i;
	}

	void RemoveGameMode(int i)
	{
		if (i == mainMode)
			mainMode = INVALID_MODE;

		gameModes.Delete(i);
	}

	clearscope GameMode GetMainGameMode() const
	{
		return mainMode == INVALID_MODE ? null : gameModes[mainMode];
	}

	clearscope GameMode, int FindGameMode(int id, class<GameMode> type = null) const
	{
		if (id < 0)
			return GetMainGameMode(), mainMode;

		int i;
		for (; i < gameModes.Size(); ++i)
		{
			if (gameModes[i].GetID() == id && (!type || gameModes[i].GetClass() == type))
				return gameModes[i], i;
		}

		return null, i;
	}

	clearscope int GetGameModeIndex(GameMode mode) const
	{
		int i;
		for (; i < gameModes.Size(); ++i)
		{
			if (gameModes[i] == mode)
				break;
		}

		return i;
	}

	override void OnRegister()
	{
		mainMode = INVALID_MODE;
	}

	override void WorldLoaded(WorldEvent e)
	{
		if (!e.IsReopen)
			mapSkill = int(Log(G_SkillPropertyInt(SKILLP_SpawnFilter)) / Log(2));
	}
	
	override void WorldTick()
	{
		foreach (mode : gameModes)
			mode.Tick();
	}
	
	override void WorldThingSpawned(WorldEvent e)
	{
		foreach (mode : gameModes)
			mode.ThingSpawned(e);
	}
	
	override void WorldThingRevived(WorldEvent e)
	{
		foreach (mode : gameModes)
			mode.ThingRevived(e);
	}
	
	override void WorldThingDied(WorldEvent e)
	{
		foreach (mode : gameModes)
			mode.ThingDied(e);
	}
	
	override void WorldThingDestroyed(WorldEvent e)
	{
		foreach (mode : gameModes)
			mode.ThingDestroyed(e);
	}

	override void WorldThingDamaged(WorldEvent e)
	{
		foreach (mode : gameModes)
			mode.ThingDamaged(e);
	}

	override void WorldThingGround(Worldevent e)
	{
		foreach (mode : gameModes)
			mode.ThingGrounded(e);
	}

	override void PlayerEntered(PlayerEvent e)
	{
		foreach (mode : gameModes)
			mode.PlayerEntered(e);
	}

	override void PlayerSpawned(PlayerEvent e)
	{
		foreach (mode : gameModes)
			mode.PlayerSpawned(e);
	}

	override bool PlayerRespawning(PlayerEvent e)
	{
		foreach (mode : gameModes)
		{
			if (!mode.PlayerRespawning(e))
				return false;
		}

		return true;
	}

	override void PlayerRespawned(PlayerEvent e)
	{
		foreach (mode : gameModes)
			mode.PlayerRespawned(e);
	}

	override void PlayerDied(PlayerEvent e)
	{
		foreach (mode : gameModes)
			mode.PlayerDied(e);
	}

	override void PlayerDisconnected(PlayerEvent e)
	{
		foreach (mode : gameModes)
			mode.PlayerDisconnected(e);
	}

	override void CheckReplacement(ReplaceEvent e)
	{
		foreach (mode : gameModes)
			mode.CheckReplacement(e);
	}

	override void CheckReplacee(ReplacedEvent e)
	{
		foreach (mode : gameModes)
			mode.CheckReplacee(e);
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		foreach (mode : gameModes)
			mode.NetworkProcess(e);
	}

	override void NetworkCommandProcess(NetworkCommand cmd)
	{
		foreach (mode : gameModes)
			mode.NetworkCommandProcess(cmd);
	}

	override void UITick()
	{
		foreach (mode : gameModes)
			mode.UITick();
	}

	override void PostUITick()
	{
		foreach (mode : gameModes)
			mode.PostUITick();
	}

	override void ConsoleProcess(ConsoleEvent e)
	{
		foreach (mode : gameModes)
			mode.ConsoleProcess(e);
	}

	override void InterfaceProcess(ConsoleEvent e)
	{
		foreach (mode : gameModes)
			mode.InterfaceProcess(e);
	}

	override void RenderOverlay(RenderEvent e)
	{
		// Only the main mode gets to be drawn on the screen.
		let mode = GetMainGameMode();
		if (mode)
			mode.Draw(e);
	}
}
