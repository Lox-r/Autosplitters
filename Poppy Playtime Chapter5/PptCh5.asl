// Asl by Lox & Arkham
// HUGE shoutout to Rumii for helping with the inventory and to Nikoheart for The Checkpoints
// Autostart, LoadRemoval by Lox
// Autosplitting by Arkham and Lox
// Thank you to Sky & SamAgent for providing much much feedback on the autosplitter
state("ch5_pro-Win64-Shipping"){}

startup
{
	Assembly.Load(File.ReadAllBytes("Components/uhara9")).CreateInstance("Main");
	vars.Uhara.Settings.CreateFromXml("Components/PPCH5.Settings.xml");
	vars.Uhara.AlertLoadless();
	vars.Uhara.EnableDebug();

	vars.completedSplits = new HashSet<string>();
	vars.splitstoComplete = new HashSet<string>();
}

init
{
	vars.Utils = vars.Uhara.CreateTool("UnrealEngine", "Utils");
	vars.Events = vars.Uhara.CreateTool("UnrealEngine", "Events");

	vars.Resolver.Watch<uint>("GWorldName", vars.Utils.GWorld, 0x18);
	vars.Resolver.Watch<int>("Loading", vars.Utils.GSync);
	vars.Resolver.Watch<bool>("TransitionType", vars.Utils.GEngine, 0x0D44);
	vars.Resolver.Watch<bool>("showHUD", vars.Utils.GEngine,0x1248, 0x38, 0x0, 0x30, 0x358, 0x2B0);

	//loadingscreen
	vars.Events.FunctionFlag("EndCutscene", "LS_12_DoctorReveal_DirectorBP_C", "LS_12_DoctorReveal_DirectorBP_C", "SequenceEvent__ENTRYPOINTLS_12_DoctorReveal_DirectorBP");
	vars.Events.FunctionFlag("LoadStart", "WBP_LoadingScreen_Host_C", "WBP_LoadingScreen_Host_C", "OnInitialized");
	vars.Events.FunctionFlag("LoadEnd", "WBP_LoadingScreen_Host_C", "WBP_LoadingScreen_Host_C", "Destruct");

	vars.InventoryInstancePtr = vars.Events.InstancePtr("PoppyInventoryManagerComponent", "PoppyInventoryManagerComponent");

	switch (modules.First().ModuleMemorySize)
	{
		case (194347008):
			version = "SteamRelease";
			break;
	}

	vars.FindSubsystem = (Func<string, IntPtr>)(name =>
	{
		var subsystems = vars.Resolver.Read<int>(vars.Utils.GEngine, 0x1248, 0x110);
		for (int i = 0; i < subsystems; i++)
		{
			var subsystem = vars.Resolver.Deref(vars.Utils.GEngine, 0x1248, 0x108, 0x18 * i + 0x8);
			var sysName = vars.Utils.FNameToString(vars.Resolver.Read<uint>(subsystem, 0x18));
			if (sysName.StartsWith(name)) return subsystem;
		}
		throw new InvalidOperationException("Subsystem not found: " + name);
	});
	vars.MobLevelStreamingSubsystem = IntPtr.Zero;

	current.World = "";
	vars.LastUpdatedWorld = "";
	current.LevelSection = "";
	vars.LoadFlag = false;

	vars.CurrentItems = new HashSet<string>();
	vars.OldItems = new HashSet<string>();
	vars.AddedItems = new HashSet<string>();
	vars.RemovedItems = new HashSet<string>();
}

update
{
	//Uncomment debug information in the event of an update.
	// print(modules.First().ModuleMemorySize.ToString());

	IntPtr gm;
	if (!vars.Resolver.TryRead<IntPtr>(out gm, vars.MobLevelStreamingSubsystem))
	{
		vars.MobLevelStreamingSubsystem = vars.FindSubsystem("MobLevelStreamingSubsystem");
		// CurrentSectionTag.TagName
		vars.Resolver.Watch<uint>("CurrentLevelSectionTag", vars.MobLevelStreamingSubsystem, 0x274);
	}

	var levelsection = vars.Utils.FNameToString(current.CurrentLevelSectionTag);
	if (!string.IsNullOrEmpty(levelsection) && levelsection != "None") current.LevelSection = levelsection;

	vars.Uhara.Update();

	var world = vars.Utils.FNameToString(current.GWorldName);
	if (!string.IsNullOrEmpty(world) && world != "None") current.World = world;
	if (current.World != old.World) vars.LastUpdatedWorld = old.World;

	if (vars.Resolver.CheckFlag("LoadStart"))
	{
		vars.LoadFlag = true;
	}

	if (vars.Resolver.CheckFlag("LoadEnd"))
	{
		vars.LoadFlag = false;
	}

	// Inventory
	do
	{

		IntPtr inventoryInstance = vars.Resolver.Read<IntPtr>(vars.InventoryInstancePtr);
		if (inventoryInstance == IntPtr.Zero) break;

		IntPtr inventoryList = vars.Resolver.Read<IntPtr>(inventoryInstance + 0x210);
		if (inventoryList == IntPtr.Zero) break;

		int inventoryListCount = vars.Resolver.Read<int>(inventoryInstance + 0x218);

		int elementStartOffset = 0x10;
		int elementSize = 0x18;

		// ---
		vars.OldItems = new HashSet<string>(vars.CurrentItems);
		vars.CurrentItems.Clear();

		for (int i = 0; i < inventoryListCount; i++)
		{
			uint itemFName = vars.Resolver.Read<uint>(
				inventoryList + elementStartOffset + (i * elementSize),
				0x70, 0x18);

			if (itemFName == 0)
				continue;

			string itemName = vars.Utils.FNameToString(itemFName);
			if (string.IsNullOrEmpty(itemName) || itemName == "None")
				continue;

			vars.CurrentItems.Add(itemName);
		}

	} while (false);
}

onStart
{
	vars.LastUpdatedWorld = "X";
	vars.completedSplits.Clear();
}

start
{
	return old.showHUD == false && current.World == "01_LabsChase_Main" && current.showHUD;
}

split
{
	var addedItems = new HashSet<string>(vars.CurrentItems);
	addedItems.ExceptWith(vars.OldItems);
	foreach (var element in addedItems)
	{
		if (vars.AddedItems.Add(element))
		{
			print("item added: " + element);;
		}
	}

	if (settings.ContainsKey(current.LevelSection.ToString()) && settings["Checkpoints"] && !vars.completedSplits.Contains(current.LevelSection.ToString()))
	{
		vars.completedSplits.Add(current.LevelSection.ToString());
		return true;
	}

	if (current.EndCutscene == 1 && !vars.completedSplits.Contains("EndCutscene"))
	{
		vars.completedSplits.Add("EndCutscene");
		return true;
	}
}

isLoading
{
	return current.TransitionType || current.World == "MainMenu_Main" || vars.LoadFlag;
}

exit
{
	timer.IsGameTimePaused = true;
}
