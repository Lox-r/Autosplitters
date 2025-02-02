// Poppy Playtime Ch4 Autosplitter and Load Remover
// Supports Load Remover IGT (Soon.TM)
// Splits for campaigns can be obtained from:
// Pointers, Item/Checkpoint Autosplits by TheDementedSalad
// Load/Pause Removal by Lox

state("ch4_pro-Win64-Shipping"){}
state("ch4_pro-WinGDK-Shipping"){}

startup
{
	Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
	vars.Helper.Settings.CreateFromXml("Components/PPCH4.Settings.xml");
	vars.Helper.AlertLoadless();
	
	vars.completedSplits = new HashSet<string>();
	vars.Inventory = new Dictionary<ulong, int>();
}

init
{
	switch (modules.First().ModuleMemorySize)
	{
		case (139485184):
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
	
	vars.Helper["isLoading"] = vars.Helper.Make<bool>(gSyncLoad);

	vars.Helper["TransitionType"] = vars.Helper.Make<byte>(gEngine, 0xB93);
	vars.Helper["Loading"] = vars.Helper.Make<byte>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x2E8, 0x328, 0x408);
		
	vars.Helper["Level"] = vars.Helper.MakeString(gEngine, 0xB98, 0x14);

	vars.Helper["CheckpointID"] = vars.Helper.Make<ulong>(gEngine, 0xA58, 0x78, 0x830, 0x158, 0x34);
	
	vars.Helper["localPlayer"] = vars.Helper.Make<ulong>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x18);
	vars.Helper["localPlayer"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
	
	vars.Helper["AcknowledgedPawn"] = vars.Helper.Make<ulong>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x340, 0x18);
	vars.Helper["AcknowledgedPawn"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
	
	//gEngine.GameInstance.LocalPlayers[0].PlayerController.Character.CapsuleMovement.RelativeLocationYXZ
	vars.Helper["X"] = vars.Helper.Make<double>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x340, 0x330, 0x128);
	vars.Helper["Y"] = vars.Helper.Make<double>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x340, 0x330, 0x138);
	vars.Helper["Z"] = vars.Helper.Make<double>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x340, 0x330, 0x130);
	
	vars.Helper["Inventory"] = vars.Helper.Make<IntPtr>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x340, 0xAF8, 0x1B0 + 0x0);
	
	vars.Helper["ItemCount"] = vars.Helper.Make<uint>(gEngine, 0x1080, 0x38, 0x0, 0x30, 0x340, 0xAF8, 0x1B8);

	
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
	
	if(timer.CurrentPhase == TimerPhase.NotRunning)
	{
		vars.completedSplits.Clear();
	}

	//print(current.ItemCount.ToString());
	
	//print(vars.FNameToShortString2(current.AcknowledgedPawn));
}

onStart
{
	vars.Inventory.Clear();
}

start
{
	return current.Y < 8544f && current.Y != old.Y && current.Level == "pro/Maps/00_Persistent/00_Persistent";
}

split
{
	const string ItemFormat = "[{0}] {1} ({2})";
	string setting = "";
	
	
	if(vars.FNameToShortString2(current.AcknowledgedPawn) == "BP_PPPlayerCharacter_C_"){ 
		for (int i = 0; i < current.ItemCount; i++)
		{

			ulong item = vars.Helper.Read<ulong>(current.Inventory + 0x10 + (i * 0x18), 0x78);
			byte used = vars.Helper.Read<byte>(current.Inventory + 0x10 + (i * 0x18), 0x68);

			int oldUsed;
			if (vars.Inventory.TryGetValue(item, out oldUsed))
			{
				if (oldUsed < used){
					setting = string.Format(ItemFormat, '+', vars.FNameToShortString(item), used);
				}
			}
			else
			{
				setting = string.Format(ItemFormat, '+', vars.FNameToShortString(item), '!');
			}
			
			vars.Inventory[item] = used;
		}
		
		if (settings.ContainsKey(setting) && settings[setting] && vars.completedSplits.Add(setting)){
			return true;
		}
		
	}
	
	if(vars.FNameToShortString3(current.CheckpointID) != vars.FNameToShortString3(old.CheckpointID)){
		setting = vars.FNameToShortString3(current.CheckpointID);
	}
	
	if(setting == "[+] TopSecretVideo (1)"){
		return true;
	}
	
	// Debug. Comment out before release.
	if (!string.IsNullOrEmpty(setting))
	vars.Log(setting);

	if (settings.ContainsKey(setting) && settings[setting] && vars.completedSplits.Add(setting)){
		return true;
	}
}

isLoading
{
	return current.isLoading || current.TransitionType == 1 || vars.FNameToShortString2(current.localPlayer) != "BP_PPPlayerController_C_";
}

reset
{}
