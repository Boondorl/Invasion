class DoomHealthPowerupSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Random
		//$Title Random Health Powerup Spawner
		//$Sprite SOULA0
		DropItem "Berserk";
		DropItem "Soulsphere";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomBigPowerupSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Random
		//$Title Random Big Powerup Spawner
		//$Sprite PINVA0
		DropItem "InvulnerabilitySphere";
		DropItem "BlurSphere";
		DropItem "Megasphere";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomBerserkSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Powerups
		//$Title Berserk Pack Spawner
		//$Sprite PSTRA0
		DropItem "Berserk";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomSoulsphereSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Powerups
		//$Title Soulsphere Spawner
		//$Sprite SOULA0
		DropItem "Soulsphere";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomMegasphereSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Powerups
		//$Title Megasphere Spawner
		//$Sprite MEGAA0
		DropItem "Megasphere";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomInvulnerabilitySphereSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Powerups
		//$Title Invulnerability Sphere Spawner
		//$Sprite PINVA0
		DropItem "InvulnerabilitySphere";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomBlurSphereSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Powerups
		//$Title Partial Invisibility Spawner
		//$Sprite PINSA0
		DropItem "BlurSphere";
		Radius 20.0;
		Height 16.0;
		RenderStyle "Translucent";
	}
}

class DoomRadSuitSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Powerups
		//$Title Radiation Suit Spawner
		//$Sprite SUITA0
		DropItem "RadSuit";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomInfraredSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Powerups
		//$Title Light Amplification Goggles Spawner
		//$Sprite PVISA0
		DropItem "Infrared";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomAllmapSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Powerups
		//$Title Computer Area Map Spawner
		//$Sprite PMAPA0
		DropItem "Allmap";
		Radius 20.0;
		Height 16.0;
	}
}
