state("FNAF_SOTM-Win64-Shipping") { }

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
    vars.Helper.GameName = "Five Nights At Freddy's: Secret of The Mimic";
    vars.Helper.AlertLoadless();

    dynamic[,] _settings =
    {
        { "split", true, "Splitting", null },
            { "MAP_Outro_InteractiveCredits_Infinite", true, "Final Split - Works on all 3 Endings", "split" },
        { "loads", true, "Load Removal", null },
            { "pause", true, "Pause when on the Loads", "loads" },
    };

    vars.Helper.Settings.Create(_settings);
    vars.CompletedSplits = new HashSet<string>();
}

init
{
    IntPtr namePoolData = vars.Helper.ScanRel(13, "89 5C 24 ?? 89 44 24 ?? 74 ?? 48 8D 15");
    IntPtr gWorld = vars.Helper.ScanRel(3, "48 8B 1D ???????? 48 85 DB 74 ?? 41 B0 01");
    IntPtr gEngine = vars.Helper.ScanRel(3, "48 8B 0D ???????? 66 0F 5A C9 E8");
    IntPtr gSyncLoadCount = vars.Helper.ScanRel(5, "89 43 60 8B 05");

    if (namePoolData == IntPtr.Zero || gWorld == IntPtr.Zero || gEngine == IntPtr.Zero)
    {
        throw new InvalidOperationException("Not all signatures resolved.");
    }

    vars.Helper["GWorldName"] = vars.Helper.Make<ulong>(gWorld, 0x18);

    // GEngine->GameInstance->LocalPlayers[0]->PlayerController->Character->CapsuleComponent->RelativeLocation
    vars.Helper["PlayerPosition"] = vars.Helper.Make<Vector3f>(gEngine, 0xD28, 0x38, 0x0, 0x30, 0x260, 0x290, 0x11C);

    // Loading
    vars.Helper["Loading"] = vars.Helper.Make<bool>(gSyncLoadCount);
    vars.Helper["TransitionType"] = vars.Helper.Make<byte>(gEngine, 0x8A8);

    // GEngine->GameInstance->LocalPlayers[0]->PlayerController->AcknowledgedPawn->ShowingReticle
    vars.Helper["ShowingReticle"] = vars.Helper.Make<bool>(gEngine, 0xD28, 0x38, 0x0, 0x30, 0x2A0, 0x69A);

    // GEngine->GameInstance->LocalPlayers[0]->PlayerController->AcknowledgedPawn->HasInteractionStarted
    // vars.Helper["PlayerState"] = vars.Helper.Make<bool>(gEngine, 0xD28, 0x38, 0x0, 0x30, 0x2A0, 0x6C8);

    // GEngine->GameInstance->LocalPlayers[0]->PlayerController->AcknowledgedPawn->StateName
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
    }

    vars.Helper.Update();
    vars.Helper.MapPointers();

    var world = vars.FNameToString(current.GWorldName);
    if (!string.IsNullOrEmpty(world) && world != "None")
        current.World = world;

    if (old.LoadingState != current.LoadingState)
    {
        vars.Log("LoadingState: " + old.LoadingState + " -> " + current.LoadingState);
    }

    if (old.StateName != current.StateName)
    {
        vars.Log("StateName: " + old.StateName + " -> " + current.StateName);
    }

    if (old.ShowingReticle != current.ShowingReticle)
    {
        vars.Log("ShowingReticle: " + old.ShowingReticle + " -> " + current.ShowingReticle);
    }
}

start
{
    return old.PlayerPosition.X != current.PlayerPosition.X && current.World == "MAP_TheWorld" && current.ShowingReticle;
}

onStart
{
    vars.CompletedSplits.Clear();
}

split
{
    return old.World != current.World && settings[current.World] && vars.CompletedSplits.Add(current.World);
}

isLoading
{
    return current.World == "MAP_MainMenu"
        || current.LoadingState == 1
        || settings["pause"] && current.TransitionType == 1;
}

exit
{
    timer.IsGameTimePaused = true;
}
