//Script Made by Lox
//Auto start and autosplit
state("HelloNeighbor3-Win64-Shipping"){}

startup 
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
	vars.Helper.GameName = "Hello Neighbor 3";
	vars.Helper.AlertRealTime();

	dynamic[,] _settings =
	{
		{ "EndSplit", true, "Speedrun Category - End Splits", null },
			{ "0.950000", true, "Get a full Phone Signal", "EndSplit" },		
	};

	vars.Helper.Settings.Create(_settings);
	vars.CompletedSplits = new HashSet<string>();
}

init 
{
    switch (modules.First().ModuleMemorySize)
	{
		case (143495168):
			version = "SteamReleaseP1";  //This is for The Prototype 1 Game as of now i don't know if they will release new updates as different games or just updates
			break;
	}

    IntPtr gWorld = vars.Helper.ScanRel(3, "48 8B 05 ???????? 48 3B C? 48 0F 44 C? 48 89 05 ???????? E8");
	IntPtr gEngine = vars.Helper.ScanRel(3, "48 89 05 ???????? 48 85 c9 74 ?? e8 ???????? 48 8d 4d");
	IntPtr fNames = vars.Helper.ScanRel(3, "48 8d 05 ???????? eb ?? 48 8d 0d ???????? e8 ???????? c6 05");

    if (gWorld == IntPtr.Zero || gEngine == IntPtr.Zero || fNames == IntPtr.Zero)
	{
		const string Msg = "Not all required addresses could be found by scanning.";
		throw new Exception(Msg);
	}

    vars.Helper["GWorldName"] = vars.Helper.Make<ulong>(gWorld, 0x18);

	//can possibly be used in the future for splits
	vars.Helper["CurrentSignalLevel"] = vars.Helper.Make<double>(gEngine, 0x10A8, 0x38, 0x0, 0x30, 0x338, 0x730, 0xB8);

    vars.FNameToString = (Func<ulong, string>)(fName =>
	{
		var nameIdx = (fName & 0x000000000000FFFF) >> 0x00;
		var chunkIdx = (fName & 0x00000000FFFF0000) >> 0x10;
		var number = (fName & 0xFFFFFFFF00000000) >> 0x20;

		// IntPtr chunk = vars.Helper.Read<IntPtr>(fNames + 0x10 + (int)chunkIdx * 0x8);
		IntPtr chunk = vars.Helper.Read<IntPtr>(fNames + 0x10 + (int)chunkIdx * 0x8);
		IntPtr entry = chunk + (int)nameIdx * sizeof(short);

		int length = vars.Helper.Read<short>(entry) >> 6;
		string name = vars.Helper.ReadString(length, ReadStringType.UTF8, entry + sizeof(short));

		return number == 0 ? name : name + "_" + number;
	});
}

update
{
    //Uncomment debug information in the event of an update.
	// print(modules.First().ModuleMemorySize.ToString());

    vars.Helper.Update();
	vars.Helper.MapPointers();

    var world = vars.FNameToString(current.GWorldName);
	if (!string.IsNullOrEmpty(world) && world != "None") current.World = world;
	if (old.World != current.World) vars.Log("World: " + current.World);
}

onStart
{
	vars.CompletedSplits.Clear();
}

start
{
    return current.World == "MainMap_02_P" && old.World == "HN3_MainMenu_P";
}

split
{
	if (settings["EndSplit"] && settings["0.950000"] && !vars.CompletedSplits.Contains("0.950000") && current.CurrentSignalLevel >= 0.950000)
	{
		vars.CompletedSplits.Add("0.950000");
		print("END SPLIT POOGGGGG");
		return true;
	}
}
