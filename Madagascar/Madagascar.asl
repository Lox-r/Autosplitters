//Original Asl by Triguii Updated by Lox
state("Game")
{
	byte load: 0x229740; //0 When in loading screen
	byte level: 0x206A38; //number of level, 14 when on map
	byte levelUnlocked: 0x21F9AC, 0x368, 0x1C; //It starts in 0, it adds 1 each time you complete a level and the next one unlocks. This happens in the load screen at the end of each level
	byte movie: "binkw32.dll", 0x54A9C; //1 When playing an outside video file (eg. the initial cutscene)
	float bossHealth: 0x21F9AC, 0x678, 0x10, 0x1C; //Final boss health
}

startup
{
	vars.CompletedSplits = new HashSet<string>();

	settings.Add("Marty's Escape", true);
	settings.Add("N.Y. Street Chase", true);
	settings.Add("Penguin Mutiny", true);
	settings.Add("Mysterious Jungle", true);
	settings.Add("Save TheLemurs", true);
	settings.Add("Jungle Banquet", true);
	settings.Add("Coming of Age", true);
	settings.Add("Back to the Beach", true);
	settings.Add("Marty to the Rescue", true);
    settings.Add("Final Battle", true);
}

init
{
	vars.thirdBossPhase = false;
}

onStart
{
	vars.thirdBossPhase = false;
	vars.CompletedSplits.Clear();
}

start
{
	if(current.level == 0 && old.level == 15){
		return(true);
	}
}

update
{
	if (settings["Final Battle"] && old.bossHealth == 0 && current.bossHealth == 20)
	{
		vars.thirdBossPhase = true;
	}

	if(current.bossHealth != old.bossHealth){
		print ("bossHealth = " + current.bossHealth);
	}
	
	if(current.load != old.load){
		print ("load = " + current.load);
	}
	
	if(current.level != old.level){
		print ("level = " + current.level);
	}
}

split
{	
	if (settings["Marty's Escape"] && !vars.CompletedSplits.Contains("Marty's Escape") && current.levelUnlocked == 1)
	{
		vars.CompletedSplits.Add("Marty's Escape");
		return true;
	}

	if (settings["N.Y. Street Chase"] && !vars.CompletedSplits.Contains("N.Y. Street Chase") && current.levelUnlocked == 2)
	{
		vars.CompletedSplits.Add("N.Y. Street Chase");
		return true;
	}

	if (settings["Penguin Mutiny"] && !vars.CompletedSplits.Contains("Penguin Mutiny") && current.levelUnlocked == 3)
	{
		vars.CompletedSplits.Add("Penguin Mutiny");
		return true;
	}

	if (settings["Mysterious Jungle"] && !vars.CompletedSplits.Contains("Mysterious Jungle") && current.levelUnlocked == 4)
	{
		vars.CompletedSplits.Add("Mysterious Jungle");
		return true;
	}

	if (settings["Save TheLemurs"] && !vars.CompletedSplits.Contains("Save TheLemurs") && current.levelUnlocked == 5)
	{
		vars.CompletedSplits.Add("Save TheLemurs");
		return true;
	}

	if (settings["Jungle Banquet"] && !vars.CompletedSplits.Contains("Jungle Banquet") && current.levelUnlocked == 6)
	{
		vars.CompletedSplits.Add("Jungle Banquet");
		return true;
	}

	if (settings["Coming of Age"] && !vars.CompletedSplits.Contains("Coming of Age") && current.levelUnlocked == 7)
	{
		vars.CompletedSplits.Add("Coming of Age");
		return true;
	}

	if (settings["Back to the Beach"] && !vars.CompletedSplits.Contains("Back to the Beach") && current.levelUnlocked == 8)
	{
		vars.CompletedSplits.Add("Back to the Beach");
		return true;
	}

	if (settings["Marty to the Rescue"] && !vars.CompletedSplits.Contains("Marty to the Rescue") && current.levelUnlocked == 9)
	{
		vars.CompletedSplits.Add("Marty to the Rescue");
		return true;
	}

	if (settings["Final Battle"] && !vars.CompletedSplits.Contains("Final Battle") && current.bossHealth == 0 && old.bossHealth > 0 && current.level == 11 && vars.thirdBossPhase == true)
	{
		vars.CompletedSplits.Add("Final Battle");
		return true;
	}
}

isLoading
{
	if (current.movie == 1 && current.load == 0)
	{
		return false;
	}else{
		return (current.load == 0);
	}
}
