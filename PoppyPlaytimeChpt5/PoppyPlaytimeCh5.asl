state(""){}

startup
{
	Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
	vars.Helper.AlertLoadless();
}

init
{
	switch (modules.First().ModuleMemorySize)
	{
		case ():
			version = "SteamRelease";
			break;
	}

	IntPtr gWorld = vars.Helper.ScanRel(3, "48 8B 05 ???????? 48 3B C? 48 0F 44 C? 48 89 05 ???????? E8");
	IntPtr gEngine = vars.Helper.ScanRel(3, "48 89 05 ???????? 48 85 c9 74 ?? e8 ???????? 48 8d 4d");
	IntPtr fNames = vars.Helper.ScanRel(3, "48 8d 0d ???????? e8 ???????? c6 05 ?????????? 0f 10 07");
	IntPtr gSyncLoad = vars.Helper.ScanRel(21, "33 C0 0F 57 C0 F2 0F 11 05");

	if (gWorld == IntPtr.Zero || gEngine == IntPtr.Zero)
	{
		const string Msg = "Not all required addresses could be found by scanning.";
		throw new Exception(Msg);
	}

	//gEngine.GameInstance.LocalPlayers[0].PlayerController.Character.CapsuleMovement.RelativeLocationYXZ
	vars.Helper["X"] = vars.Helper.Make<double>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x340, 0x330, 0x128);
	vars.Helper["Y"] = vars.Helper.Make<double>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x340, 0x330, 0x138);
	vars.Helper["Z"] = vars.Helper.Make<double>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x340, 0x330, 0x130);


	vars.FNameToString = (Func<ulong, string>)(fName =>
	{
		var nameIdx  = (fName & 0x000000000000FFFF) >> 0x00;
		var chunkIdx = (fName & 0x00000000FFFF0000) >> 0x10;
		var number   = (fName & 0xFFFFFFFF00000000) >> 0x20;

		IntPtr chunk = vars.Helper.Read<IntPtr>(fNames + 0x10 + (int)chunkIdx * 0x8);
		IntPtr entry = chunk + (int)nameIdx * sizeof(short);

		int length = vars.Helper.Read<short>(entry) >> 6;
		string name = vars.Helper.ReadString(length, ReadStringType.UTF8, entry + sizeof(short));

		return number == 0 ? name : name + "_" + number;
	});

	vars.FNameToShortString = (Func<ulong, string>)(fName =>
	{
		string name = vars.FNameToString(fName);

		int dot = name.LastIndexOf('.');
		int slash = name.LastIndexOf('/');

		return name.Substring(Math.Max(dot, slash) + 1);
	});

	vars.FNameToShortString2 = (Func<ulong, string>)(fName =>
	{
		string name = vars.FNameToString(fName);

		int under = name.LastIndexOf('_');

		return name.Substring(0, under + 1);
	});

	vars.FNameToShortString3 = (Func<ulong, string>)(fName =>
	{
		string name = vars.FNameToString(fName);

		int check = name.IndexOf('.');

		return name.Substring(check + 1);
	});
}

update
{
	//Uncomment debug information in the event of an update.
	//print(modules.First().ModuleMemorySize.ToString());

	vars.Helper.Update();
	vars.Helper.MapPointers();
}

onStart
{
}

start
{
}

split
{
}

isLoading
{
}

reset
{}
