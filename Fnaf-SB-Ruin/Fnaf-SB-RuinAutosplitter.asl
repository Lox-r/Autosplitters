//Five Nights at Freddys Security Breach Ruin loadremover and autosplitter
//Script by Lox and NintenDude

state ("fnaf9-Win64-Shipping"){}

startup
{
	Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
	vars.Helper.GameName = "Five Nights at Freddys: Ruin";
	vars.Helper.AlertLoadless();

	dynamic[,] _settings =
	{
		{ "Chapter", false, "Speedrun Category - Chapter", null },
			{ "autosave_2_2", true, "Complete Chapter 1", "Chapter" },
			{ "autosave_3_2", true, "Complete Chapter 2", "Chapter" },
			{ "autosave_4_2", true, "Complete Chapter 3", "Chapter" },
			{ "autosave_5_2", true, "Complete Chapter 4", "Chapter" },
			{ "autosave_6_2", true, "Complete Chapter 5", "Chapter" },
			{ "autosave_7_2", true, "Complete Chapter 6", "Chapter" },
			{ "autosave_8_2", true, "Complete Chapter 7", "Chapter" },
			{ "autosave_9_2", true, "Complete Chapter 8", "Chapter" },
		{ "AreaSplits", false, "Speedrun Category - Area Splits", null },
			{ "PlaySequenceTrigger_GatorGolfIntro_DLC", true, "After Monty Jumpscare", "AreaSplits" },
			{ "autosave_2_5", true, "Reach the Daycare Door", "AreaSplits" },
			{ "autosave_2_6", true, "Reach the Daycare theatre", "AreaSplits" },
			{ "autosave_3_9", true, "End of Catwalks", "AreaSplits" },
	};

	vars.Helper.Settings.Create(_settings);
	vars.CompletedSplits = new HashSet<string>();
}

init
{
	vars.cachedPos = new Vector3f(0, 0, 0);

	IntPtr gWorld = vars.Helper.ScanRel(3, "48 8B 05 ???????? 48 3B C? 48 0F 44 C? 48 89 05 ???????? E8");
	IntPtr gEngine = vars.Helper.ScanRel(3, "48 89 05 ???????? 48 85 c9 74 ?? e8 ???????? 48 8d 4d");
	IntPtr fNames = vars.Helper.ScanRel(3, "48 8d 05 ???????? eb ?? 48 8d 0d ???????? e8 ???????? c6 05");

	if (gWorld == IntPtr.Zero || gEngine == IntPtr.Zero || fNames == IntPtr.Zero)
	{
		const string Msg = "Not all required addresses could be found by scanning.";
		throw new Exception(Msg);
	}

	vars.Helper["GWorldName"] = vars.Helper.Make<ulong>(gWorld, 0x18);

	//GEngine.GameInstance.LocalPlayers[0].PlayerController.AcknowledgedPawn.isMoving
	vars.Helper["isMoving"] = vars.Helper.Make<bool>(gEngine, 0xD28, 0x38, 0x0, 0x30, 0x2A8, 0x998);
	vars.Helper["isMoving"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

	vars.Helper["loadSavedGameOnNextWorldLoad"] = vars.Helper.Make<bool>(gEngine, 0x780, 0x80, 0x300);
	vars.Helper["loadSavedGameOnNextWorldLoad"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

	//GWorld.AuthorityGameMode.HasLoaded
	vars.Helper["hasLoaded"] = vars.Helper.Make<int>(gWorld, 0x118, 0x3A8);
	vars.Helper["hasLoaded"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

	vars.Helper["TransitionType"] = vars.Helper.Make<byte>(gEngine, 0x8A8);
	vars.Helper["TransitionType"].FailAction = MemoryWatcher.ReadFailAction.DontUpdate;

	vars.Helper["onLoadingScreen"] = vars.Helper.Make<int>(gEngine, 0xD28, 0x38, 0x0, 0x30, 0x624);
	vars.Helper["onLoadingScreen"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

	//splits
	// GEngine.GameInstance.???.PointerToFNAFSaveGameSystem.SaveDataObject
	vars.Helper["LastAutoSaveID"] = vars.Helper.Make<ulong>(gEngine, 0xD28, 0xF0, 0x68, 0x30, 0x3E4);
	vars.Helper["LastAutoSaveID"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;		

	vars.FNameToString = (Func<ulong, string>)(fName =>
	{
		var nameIdx = (fName & 0x000000000000FFFF) >> 0x00;
		var chunkIdx = (fName & 0x00000000FFFF0000) >> 0x10;
		var number = (fName & 0xFFFFFFFF00000000) >> 0x20;

		IntPtr chunk = vars.Helper.Read<IntPtr>(fNames + 0x10 + (int)chunkIdx * 0x8);
		IntPtr entry = chunk + (int)nameIdx * sizeof(short);

		int length = vars.Helper.Read<short>(entry) >> 6;
		string name = vars.Helper.ReadString(length, ReadStringType.UTF8, entry + sizeof(short));

		return number == 0 ? name : name + "_" + number;
	});

	current.AutoSaveID = "";
	vars.isLoading = 0;
}

onStart
{
	vars.CompletedSplits.Clear();
}

update
{
	vars.Helper.Update();
	vars.Helper.MapPointers();

	var world = vars.FNameToString(current.GWorldName);
	if (!string.IsNullOrEmpty(world) && world != "None") current.World = world;
	if (old.World != current.World) vars.Log("World: " + current.World);

	var autosave = vars.FNameToString(current.LastAutoSaveID);
	if (!string.IsNullOrEmpty(autosave) && autosave != "None") current.AutoSaveID = autosave;
}

start
{
	return current.World == "MAP_World_DLC" && old.isMoving == false && current.isMoving == true;
}

split
{	
	// Chapter Splitting
	if (settings["Chapter"] || settings["AreaSplits"])
	{
		if (current.AutoSaveID != "autosave_1_0" && current.AutoSaveID != "PlaySequenceTrigger_LobbyEntranceDLC" && current.AutoSaveID != "PlaySequenceTrigger_LobbyEntranceDLC_Intro_Cinematic")
		{
			if (settings[current.AutoSaveID.ToString()] && old.AutoSaveID != current.AutoSaveID && !vars.CompletedSplits.Contains(current.AutoSaveID.ToString()))
			{
				vars.CompletedSplits.Add(current.AutoSaveID.ToString());
				return true;
			}
		}
	}
}

isLoading
{	
	return current.hasLoaded == 0 || current.TransitionType == 1 || current.onLoadingScreen != 0;
}

exit
{
    timer.IsGameTimePaused = true;
}
