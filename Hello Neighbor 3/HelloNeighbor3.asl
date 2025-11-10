// Script Made by Lox and Menzo
// Auto start, Auto split and Auto reset
state("HelloNeighbor3-Win64-Shipping"){}

startup 
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
    vars.Helper.GameName = "Hello Neighbor 3";
    vars.Helper.AlertRealTime();

    dynamic[,] _settings =
    {
        { "EndSplit", true, "Speedrun Category - End Splits", null },
            { "EndTrigger", true, "Complete the Game (Escaped)", "EndSplit" },        
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
    
    IntPtr EndTriggerPtr = Tool.FunctionFlag("WBP_GameResultsEscaped_C", "WBP_GameResultsEscaped_C", "OnInitialized");
    vars.Resolver.Watch<ulong>("EndTrigger", EndTriggerPtr);
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
    return current.World == "MainMap_02_P" && current.SyncLoadCount == 0;
}

reset
{
    return current.World == "HN3_MainMenu_P" && old.World == "MainMap_02_P";
}

split
{
    if (settings["EndTrigger"] && current.EndTrigger != old.EndTrigger && current.EndTrigger != 0)
    {
        return true;
    }
    
    return false;
}
