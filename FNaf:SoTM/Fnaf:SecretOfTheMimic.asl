state("FNAF_SOTM-Win64-Shipping"){}

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
	vars.Helper.GameName = "Five Nights At Freddy's: Secret of The Mimic";
	vars.Helper.AlertLoadless();

	dynamic[,] _settings =
	{
		{ "Loads", true, "Speedrun Category - Loadremover Settings", null },
			{ "paused", true, "Pause timer when in the pause menu", "Loads"},
		{"End", true, "Speedrun Category - Final Splits", null},
			{"FinalSplit", true, "Final Split - Works on all 3 Endings", "End"},
	};

	vars.Helper.Settings.Create(_settings);
	vars.CompletedSplits = new HashSet<string>();
}

init
{
    IntPtr namePoolData = vars.Helper.ScanRel(13, "89 5C 24 ?? 89 44 24 ?? 74 ?? 48 8D 15");
	IntPtr gWorld = vars.Helper.ScanRel(3, "48 8B 05 ???????? 48 3B C? 48 0F 44 C? 48 89 05 ???????? E8");
	IntPtr gEngine = vars.Helper.ScanRel(3, "48 89 05 ???????? 48 85 c9 74 ?? e8 ???????? 48 8d 4d");
	IntPtr gSyncLoadCount = vars.Helper.ScanRel(5, "89 43 60 8B 05 ?? ?? ?? ??");

	if (namePoolData == IntPtr.Zero || gEngine == IntPtr.Zero)
    {
        throw new InvalidOperationException("Not all signatures resolved.");
    }

    vars.Helper["GWorldName"] = vars.Helper.Make<ulong>(gWorld, 0x18);

	//movement
	vars.Helper["X"] = vars.Helper.Make<double>(gEngine, 0xD28, 0x38, 0x0, 0x30, 0x260, 0x290, 0x11C);

	//load related
	vars.Helper["Loading"] = vars.Helper.Make<bool>(gSyncLoadCount);
	vars.Helper["TransitionType"] = vars.Helper.Make<byte>(gEngine, 0x8A8);
	// GEngine.LocalPlayers[0].PlayerController.AcknowledgedPawn.ShowingReticle
	vars.Helper["Crosshair"] = vars.Helper.Make<bool>(gEngine, 0xD28, 0x38, 0x0, 0x30, 0x2A0, 0x69A);
	// GEngine.LocalPlayers[0].PlayerController.AcknowledgedPawn.HasInteractionStarted
	// vars.Helper["PlayerState"] = vars.Helper.Make<bool>(gEngine, 0xD28, 0x38, 0x0, 0x30, 0x2A0, 0x6C8);
	// GEngine.LocalPlayers[0].PlayerController.AcknowledgedPawn.StateName
	vars.Helper["StateName"] = vars.Helper.Make<ulong>(gEngine, 0xD28, 0x38, 0x0, 0x30, 0x248);

	// NamePool stuff
    const int FNameBlockOffsetBits = 16;
    const uint FNameBlockOffsetMask = ushort.MaxValue; // (1 << FNameBlockOffsetBits) - 1

    const int FNameIndexBits = 32;
    const uint FNameIndexMask = uint.MaxValue; // (1 << FNameIndexBits) - 1

    var nameCache = new Dictionary<int, string> { { 0, "None" } };

    vars.FNameToString = (Func<ulong, string>)(fName =>
    {
        var number          = (int)(fName >> FNameIndexBits);
        var comparisonIndex = (int)(fName &  FNameIndexMask);

        string name;
        if (!nameCache.TryGetValue(comparisonIndex, out name))
        {
            var blockIndex = (ushort)(comparisonIndex >> FNameBlockOffsetBits);
            var offset     = (ushort)(comparisonIndex &  FNameBlockOffsetMask);

            var block = vars.Helper.Read<IntPtr>(namePoolData + 0x10 + blockIndex * 0x8);
            var entry = block + 2 * offset;

            var length = vars.Helper.Read<short>(entry) >> 6;
            name = vars.Helper.ReadString(length, ReadStringType.UTF8, entry + 2);

            nameCache.Add(comparisonIndex, name);
        }

        return number == 0 ? name : name + "_" + (number - 1);
    });

    vars.FindSubsystem = (Func<string, IntPtr>)(name =>
    {
        var subsystems = vars.Helper.Read<int>(gEngine, 0xD28, 0xF8);
        for (int i = 0; i < subsystems; i++)
        {
            var subsystem = vars.Helper.Deref(gEngine, 0xD28, 0xF0, 0x18 * i + 0x8);
            var sysName = vars.FNameToString(vars.Helper.Read<ulong>(subsystem, 0x18));

            if (sysName.StartsWith(name))
            {
                return subsystem;
            }
        }

        throw new InvalidOperationException("Subsystem not found: " + name);
    });

    vars.GameManager = IntPtr.Zero;
}

update
{
	IntPtr gm;
    if (!vars.Helper.TryRead<IntPtr>(out gm, vars.GameManager))
    {
        vars.GameManager = vars.FindSubsystem("CarnivalGameManager");

        // UCarnivalGameManager->LoadingScreenManager->0x48
        vars.Helper["LoadingState"] = vars.Helper.Make<int>(vars.GameManager, 0x168, 0x48);

        // UCarnivalGameManager->LoadingScreenManager->LoadingScreenImpl->Class->0x18
        vars.Helper["LoadingScreenImplFn"] = vars.Helper.Make<ulong>(vars.GameManager, 0x168, 0x30, 0x10, 0x18);
        vars.Helper["LoadingScreenImplFn"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
	}

    vars.Helper.Update();
	vars.Helper.MapPointers();

    var world = vars.FNameToString(current.GWorldName);
	if (!string.IsNullOrEmpty(world) && world != "None") current.World = world;
	if (old.World != current.World) vars.Log("World: " + current.World);

	if (old.LoadingState != current.LoadingState)
    {
        vars.Log("LoadingState: " + old.LoadingState + " -> " + current.LoadingState);
    }

	if (old.StateName != current.StateName)
	{
		vars.Log("StateName: " + old.StateName + " -> " + current.StateName);
	}

	if (old.Crosshair != current.Crosshair)
	{
		vars.Log("Crosshair: " + old.Crosshair + " -> " + current.Crosshair);
	}
}

onStart
{
	vars.CompletedSplits.Clear();
}

start
{
	return current.X != old.X && current.World == "MAP_TheWorld" && current.Crosshair == true;
}

isLoading
{
    return current.LoadingState == 1  || current.World == "Map_MainMenu";

    if (settings["paused"])
    {
        if (current.TransitionType == 1)
        {
            return true;
        }
    }
}

split
{
	if (settings["FinalSplit"] && current.World == "MAP_Outro_InteractiveCredits_Infinite" && !vars.CompletedSplits.Contains("FinalSplit"))
	{
		vars.CompletedSplits.Add("FinalSplit");
		return true;
	}
}

exit
{
    timer.IsGameTimePaused = true;
}
