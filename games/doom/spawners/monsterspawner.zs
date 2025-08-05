class DoomPossessedSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Random
		//$Title Random Zombie Spawner
		//$Sprite POSSA1
		DropItem "ZombieMan";
		DropItem "ShotgunGuy";
		DropItem "ChaingunGuy";
		Radius 20.0;
		Height 56.0;
	}
}

class DoomSmallMonsterSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Random
		//$Title Random Small Demon Spawner
		//$Sprite TROOA1
		DropItem "DoomImp";
		DropItem "Demon";
		DropItem "Spectre";
		DropItem "LostSoul";
		Radius 30.0;
		Height 56.0;
	}
}

class DoomLargeMonsterSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Random
		//$Title Random Large Demon Spawner
		//$Sprite BOS2A1C1
		DropItem "Arachnotron";
		DropItem "BaronOfHell";
		DropItem "Cacodemon";
		DropItem "HellKnight";
		DropItem "Fatso";
		DropItem "PainElemental";
		DropItem "Revenant";
		Radius 64.0;
		Height 64.0;
	}
}

class DoomBossMonsterSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Random
		//$Title Random Boss Demon Spawner
		//$Sprite CYBRA1
		DropItem "Cyberdemon";
		DropItem "SpiderMastermind";
		Radius 128.0;
		Height 110.0;
	}
}

class DoomZombieManSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Grunt Spawner
		//$Sprite POSSA1
		DropItem "ZombieMan";
		Radius 20.0;
		Height 56.0;
	}
}

class DoomShotgunGuySpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Sergeant Spawner
		//$Sprite SPOSA1
		DropItem "ShotgunGuy";
		Radius 20.0;
		Height 56.0;
	}
}

class DoomChaingunGuySpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Commando Spawner
		//$Sprite CPOSA1
		DropItem "ChaingunGuy";
		Radius 20.0;
		Height 56.0;
	}
}

class DoomImpSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Imp Spawner
		//$Sprite TROOA1
		DropItem "DoomImp";
		Radius 20.0;
		Height 56.0;
	}
}

class DoomDemonSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Pinkie Spawner
		//$Sprite SARGA1
		DropItem "Demon";
		Radius 30.0;
		Height 56.0;
	}
}

class DoomSpectreSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Spectre Spawner
		//$Sprite SARGA1
		DropItem "Spectre";
		Radius 30.0;
		Height 56.0;
		RenderStyle "Translucent";
		Alpha 0.5;
	}
}

class DoomLostSoulSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Lost Soul Spawner
		//$Sprite SKULA1
		DropItem "LostSoul";
		Radius 16.0;
		Height 56.0;
		RenderStyle "SoulTrans";
	}
}

class DoomCacodemonSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Cacodemon Spawner
		//$Sprite HEADA1
		DropItem "Cacodemon";
		Radius 31.0;
		Height 56.0;
	}
}

class DoomPainElementalSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Pain Elemental Spawner
		//$Sprite PAINA1
		DropItem "PainElemental";
		Radius 31.0;
		Height 56.0;
	}
}

class DoomRevenantSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Revenant Spawner
		//$Sprite SKELA1D1
		DropItem "Revenant";
		Radius 20.0;
		Height 56.0;
	}
}

class DoomHellKnightSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Hell Knight Spawner
		//$Sprite BOS2A1C1
		DropItem "HellKnight";
		Radius 24.0;
		Height 64.0;
	}
}

class DoomBaronofHellSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Baron of Hell Spawner
		//$Sprite BOSSA1
		DropItem "BaronofHell";
		Radius 24.0;
		Height 64.0;
	}
}

class DoomFatsoSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Mancubus Spawner
		//$Sprite FATTA1
		DropItem "Fatso";
		Radius 48.0;
		Height 64.0;
	}
}

class DoomArachnotronSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Arachnotron Spawner
		//$Sprite BSPIA1D1
		DropItem "Arachnotron";
		Radius 64.0;
		Height 64.0;
	}
}


class DoomArchvileSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Arch-vile Spawner
		//$Sprite VILEA1D1
		DropItem "Archvile";
		Radius 20.0;
		Height 56.0;
	}
}

class DoomCyberdemonSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Cyberdemon Spawner
		//$Sprite CYBRA1
		DropItem "Cyberdemon";
		Radius 40.0;
		Height 110.0;
	}
}

class DoomSpiderMastermindSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Monsters
		//$Title Spider Mastermind Spawner
		//$Sprite SPIDA1D1
		DropItem "SpiderMastermind";
		Radius 128.0;
		Height 100.0;
	}
}
