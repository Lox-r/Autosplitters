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

    settings.Add("Final Battle", true);
	settings.SetToolTip("Final Battle", "Split on the Last Hit");
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
