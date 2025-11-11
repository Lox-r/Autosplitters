// Script Made by Lox and Menzo
// Auto start, Auto split and Auto reset
// Supports Prototype 1 & 2
state("HelloNeighbor3-Win64-Shipping"){}

startup 
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
    vars.Helper.GameName = "Hello Neighbor 3";
    vars.Helper.AlertRealTime();

    dynamic[,] _settings =
    {
        { "EndSplit", true, "Speedrun Category - End Splits", null },
            { "EndTriggerP1", true, "Complete the Game (Escaped - Prototype 1)", "EndSplit" },
            { "EndTriggerP2", true, "Complete the Game (Escaped - Prototype 2)", "EndSplit" },
    };

    vars.Helper.Settings.Create(_settings);
    vars.CompletedSplits = new HashSet<string>();
    
    Assembly.Load(File.ReadAllBytes("Components/uhara9")).CreateInstance("Main");
    vars.Uhara.EnableDebug();
}

init 
{
    switch (modules.First().ModuleMemorySize)
    {
        case (143495168):
            version = "Prototype 1";
            break;
        case (143896576):
            version = "Prototype 2";
            break;
    }

    IntPtr gEngine = vars.Helper.ScanRel(3, "48 8B 0D ???????? 48 8B BC 24 ???????? 48 8B 9C 24");
    IntPtr gWorld = vars.Helper.ScanRel(3, "48 8B 05 ???????? 48 85 C0 75 ?? 48 83 C4 ?? 5B");
    IntPtr fNames = vars.Helper.ScanRel(3, "48 8D 0D ???????? E8 ???????? C6 05 ?????????? 0F 10 07");
    IntPtr gSyncLoadCount = vars.Helper.ScanRel(21, "33 C0 0F 57 C0 F2 0F 11 05");

    vars.Helper["GWorldName"] = vars.Helper.Make<ulong>(gWorld, 0x18);
    vars.Helper["SyncLoadCount"] = vars.Helper.Make<int>(gSyncLoadCount);

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
    
    current.World = "";
    old.World = "";
    
    var Tool = vars.Uhara.CreateTool("UnrealEngine", "Events");
    
    if (version == "Prototype 1")
    {
        IntPtr EndTriggerPtr = Tool.FunctionFlag("WBP_GameResultsEscaped_C", "WBP_GameResultsEscaped_C", "OnInitialized");
        vars.Resolver.Watch<ulong>("EndTriggerP1", EndTriggerPtr);
    }
    else if (version == "Prototype 2")
    {
        IntPtr EndTriggerPtr = Tool.FunctionFlag("WBP_GameEnding_Successful_C", "WBP_GameEnding_Successful_C", "OnInitialized");
        vars.Resolver.Watch<ulong>("EndTriggerP2", EndTriggerPtr);
    }
}

update
{
    vars.Helper.Update();
    vars.Helper.MapPointers();

    var world = vars.FNameToString(current.GWorldName);
    if (!string.IsNullOrEmpty(world) && world != "None") 
    {
        current.World = world;
    }
    
    vars.Uhara.Update();
}

start
{
    if (version == "Prototype 1")
    {
        return current.World == "MainMap_02_P" && current.SyncLoadCount == 0;
    }
    else if (version == "Prototype 2")
    {
        return current.World == "MainMap_03_P" && current.SyncLoadCount == 0;
    }
    
    return false;
}

reset
{
    if (version == "Prototype 1")
    {
        return current.World == "HN3_MainMenu_P" && old.World == "MainMap_02_P";
    }
    else if (version == "Prototype 2")
    {
        return current.World == "HN3_MainMenu_P" && old.World == "MainMap_03_P";
    }
    
    return false;
}

split
{
    if (version == "Prototype 1")
    {
        if (settings["EndTriggerP1"] && current.EndTriggerP1 != old.EndTriggerP1 && current.EndTriggerP1 != 0)
        {
            return true;
        }
    }
    else if (version == "Prototype 2")
    {
        if (settings["EndTriggerP2"] && current.EndTriggerP2 != old.EndTriggerP2 && current.EndTriggerP2 != 0)
        {
            return true;
        }
    }
    
    return false;
}
