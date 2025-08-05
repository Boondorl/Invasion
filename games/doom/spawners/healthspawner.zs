class DoomBonusSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Random
		//$Title Random Bonus Spawner
		//$Sprite BON1A0
		DropItem "HealthBonus";
		DropItem "ArmorBonus";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomHealthBonusSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Health
		//$Title Health Bonus Spawner
		//$Sprite BON1A0
		DropItem "HealthBonus";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomStimpackSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Health
		//$Title Stimpack Spawner
		//$Sprite STIMA0
		DropItem "Stimpack";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomMedikitSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Health
		//$Title Medikit Spawner
		//$Sprite MEDIA0
		DropItem "Medikit";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomArmorBonusSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Armor
		//$Title Armor Bonus Spawner
		//$Sprite BON2A0
		DropItem "ArmorBonus";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomGreenArmorSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Armor
		//$Title Green Armor Spawner
		//$Sprite ARM1A0
		DropItem "GreenArmor";
		Radius 20.0;
		Height 16.0;
	}
}

class DoomBlueArmorSpawner : InvasionSpawner
{
	Default
	{
		//$Category Invasion/Doom/Armor
		//$Title Blue Armor Spawner
		//$Sprite ARM2A0
		DropItem "BlueArmor";
		Radius 20.0;
		Height 16.0;
	}
}
