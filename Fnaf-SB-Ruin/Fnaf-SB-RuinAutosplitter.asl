//Five Nights at Freddys Security Breach Ruin loadremover and autosplitter
//Script by Lox and NintenDude, Updated by SAM
//Credit to daltone_21 and nintendude_sr for the SB logic to detect the nearest interactible object and the player position system
//Credit to Sanic for the memory locations for Pause, MainMenu, and LoadingScreen
//Credit to Arkham for the logic to add text components to the livesplit and the player InZone logic

state ("fnaf9-Win64-Shipping"){}

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
    vars.Helper.GameName = "Five Nights at Freddys: Ruin";
    vars.Helper.AlertLoadless();

    dynamic[,] _settings =
    {
        { "Chapter", true, "Speedrun Category - Chapter", null },
            { "autosave_2_2", true, "Complete Chapter 1", "Chapter" },
            { "vent_fall", true, "Complete Chapter 2", "Chapter" },
            { "autosave_4_2", true, "Complete Chapter 3", "Chapter" },
            { "autosave_5_2", true, "Complete Chapter 4", "Chapter" },
            { "autosave_6_2", true, "Complete Chapter 5", "Chapter" },
            { "autosave_7_2", true, "Complete Chapter 6", "Chapter" },
            { "autosave_8_2", true, "Complete Chapter 7", "Chapter" },
            { "autosave_9_2", true, "Complete Chapter 8", "Chapter" },
        { "AreaSplits", false, "Speedrun Category - Area Splits", null },
            { "PlaySequenceTrigger_GatorGolfIntro_DLC", false, "After Monty Jumpscare", "AreaSplits" },
            { "autosave_2_5", false, "Reach the Daycare Door", "AreaSplits" },
            { "autosave_2_6", false, "Reach the Daycare theatre", "AreaSplits" },
            { "autosave_3_9", false, "End of Catwalks", "AreaSplits" },
        { "Endings", true, "Speedrun Category - Endings", null },
            { "brazil", true, "Brazil Ending", "Endings" },
            { "scooper", true, "Scooper Ending", "Endings" },
            { "betrayal", true, "Betrayal Ending", "Endings" },
        { "ScooperCameras", false, "Speedrun Category - Scooper Cameras", null },
            { "camera1", false, "Chapter 1 Camera", "ScooperCameras" },
            { "camera2", false, "Chapter 3 Camera", "ScooperCameras" },
            { "camera3", false, "Chapter 5 Camera", "ScooperCameras" },
            { "camera4", false, "Chapter 7 Camera", "ScooperCameras" },
        { "CollectedCautionBots", false, "Speedrun Category - Mop Bots", null },
    };

    vars.Helper.Settings.Create(_settings);
    vars.CompletedSplits = new HashSet<string>();

    vars.lcCache = new Dictionary<string, LiveSplit.UI.Components.ILayoutComponent>();

    vars.SetText = (Action<string, object>)((text1, text2) =>
    {
        const string FileName = "LiveSplit.Text.dll";
        LiveSplit.UI.Components.ILayoutComponent lc;

        if (!vars.lcCache.TryGetValue(text1, out lc))
        {
            lc = timer.Layout.LayoutComponents.Reverse().Cast<dynamic>()
                 .FirstOrDefault(llc => llc.Path.EndsWith(FileName) && llc.Component.Settings.Text1 == text1)
                 ?? LiveSplit.UI.Components.ComponentManager.LoadLayoutComponent(FileName, timer);

            vars.lcCache.Add(text1, lc);
        }

        if (!timer.Layout.LayoutComponents.Contains(lc))
             timer.Layout.LayoutComponents.Add(lc);

        dynamic tc = lc.Component;
        tc.Settings.Text1 = text1;
        tc.Settings.Text2 = text2.ToString();
    });
}

init
{
    //Sets the version of the game upon startup
    int gameSize = modules.First().ModuleMemorySize;

    switch (gameSize){
        default: {
            vars.version = 100; // Unsupported
            if (!settings["Unsupported version warning"]) break;
            MessageBox.Show("Sorry, it seems like the version of Security Breach that you're using isn't currently fully supported! Splits may not work with this version of Security Breach currently.\n\n"+
            "gameSize = 0x"+gameSize.ToString("X")+"\n\n"+
            "Sorry for the inconvenience.", "Warning: Version Not Supported", MessageBoxButtons.OK, MessageBoxIcon.Warning).ToString();
            print(gameSize.ToString("X"));
            break;
        }
        case 0x5434000: vars.version = 1.13; break;
        case 0x5435000: vars.version = 1.14; break;
    }

    print("Version = " + vars.version);

    IntPtr gWorld = vars.Helper.ScanRel(3, "48 8B 05 ???????? 48 3B C? 48 0F 44 C? 48 89 05 ???????? E8");
    IntPtr gEngine = vars.Helper.ScanRel(3, "48 89 05 ???????? 48 85 c9 74 ?? e8 ???????? 48 8d 4d");
    IntPtr fNames = vars.Helper.ScanRel(3, "48 8d 05 ???????? eb ?? 48 8d 0d ???????? e8 ???????? c6 05");

    if (gWorld == IntPtr.Zero || gEngine == IntPtr.Zero || fNames == IntPtr.Zero)
    {
        const string Msg = "Not all required addresses could be found by scanning.";
        throw new Exception(Msg);
    }

    vars.Helper["GWorldName"] = vars.Helper.Make<ulong>(gWorld, 0x18);

    // Logic to determine the nearest interactible item
    const int CLASS_OFFSET = 0x10;
    const int CHILD_OFFSET = 0x50;
    const int NEXT_OFFSET = 0x20;
    const int NAME_OFFSET = 0x28;
    const int INTERNAL_OFFSET = 0x4C;
    const int SUPERFIELD_OFFSET = 0x40;
    vars.offsets = new Dictionary<string, int>();
    vars.fnames = new Dictionary<long, string>();

    vars.GetStaticPointerFromSig = (Func<string, int, IntPtr>) ( (signature, instructionOffset) => {
        var scanner = new SignatureScanner(game, modules.First().BaseAddress, (int)modules.First().ModuleMemorySize);
        var pattern = new SigScanTarget(signature);
        var location = scanner.Scan(pattern);
        if (location == IntPtr.Zero) return IntPtr.Zero;
        int offset = game.ReadValue<int>((IntPtr)location + instructionOffset);
        return (IntPtr)location + offset + instructionOffset + 0x4;
    });

    vars.GetNameFromFName = (Func<long, string>) ( longKey => {
        if (vars.fnames.ContainsKey(longKey)) return vars.fnames[longKey];
        int key = (int)(longKey & uint.MaxValue);
        int partial = (int)(longKey >> 32);
        int chunkOffset = key >> 16;
        int nameOffset = (ushort)key;
        IntPtr namePoolChunk = memory.ReadValue<IntPtr>((IntPtr)vars.FNamePool + (chunkOffset+2) * 0x8);
        Int16 nameEntry = game.ReadValue<Int16>((IntPtr)namePoolChunk + 2 * nameOffset);
        int nameLength = nameEntry >> 6;
        string output = game.ReadString((IntPtr)namePoolChunk + 2 * nameOffset + 2, nameLength);
        string outputParsed = (partial == 0) ? output : output + "_" + partial.ToString();
        vars.fnames[longKey] = outputParsed;
        return outputParsed;
    });

    vars.GetPropertyOffset = (Func<IntPtr, string, IntPtr>) ((address, name) => {
        var _class = game.ReadPointer(address + CLASS_OFFSET);
        for (; _class != IntPtr.Zero; _class = game.ReadPointer(_class + SUPERFIELD_OFFSET)) {
            for (IntPtr property = game.ReadPointer(_class + CHILD_OFFSET); property != IntPtr.Zero; property = game.ReadPointer(property + NEXT_OFFSET)) {
                string propName = vars.GetNameFromFName(game.ReadValue<long>(property + NAME_OFFSET));
                if (propName == name) {
                    int offset = game.ReadValue<int>(property + INTERNAL_OFFSET);
                    print("Found property \"" + name + "\" at offset 0x" + offset.ToString("X"));
                    vars.offsets[name] = offset;
                    return property;
                }
            }
        }
        print("Couldn't find property \""+name+"\".");
        return IntPtr.Zero;
    });

    vars.FNamePool      = vars.GetStaticPointerFromSig("8B 05 ??????03"     //mov eax, [badFNamePool]
                                                      +"FF C0"              //inc eax
                                                      +"C1 E9 10"           //shr ecx,10
                                                      +"3B C8"              //cmp ecx,eax
                                                      +"0F92 C0"            //setb al
                                                      +"C3 CC"              //ret
                                                      , 2)
                                                      -8;

    vars.UWorld         = vars.GetStaticPointerFromSig("E8 ????????"        //call ????????
                                                      +"48 8B 88 ??0?0000"  //mov rcx,[rax+???]
                                                      +"48 89 0D ??????02"  //mov [UWorld],rcx
                                                      , 15);

    vars.GEngine        = vars.GetStaticPointerFromSig("48 8B 05 ????????"  //mov rax,[GEngine]
                                                      +"48 8B D1"           //mov rdx,rcx
                                                      +"48 8B 88 F80A0000"  //mov rcx,[rax+AF8]
                                                      +"48 85 C9"           //test rcx,rcx
                                                      +"74 07"              //je
                                                      +"48 8B 01"           //mov rax,[rcx]
                                                      +"48 FF 60 40"        //jmp qword ptr [rax+40]
                                                      , 3);

    if (vars.UWorld == IntPtr.Zero || vars.GEngine == IntPtr.Zero || vars.FNamePool == IntPtr.Zero){
        throw new Exception("UWorld/GameEngine/FNamePool not initialized - trying again");
    }

    vars.GetPropertyOffset(game.ReadPointer((IntPtr)vars.GEngine), "GameInstance");
    vars.GetPropertyOffset(game.ReadPointer((IntPtr)vars.UWorld), "AuthorityGameMode");

    //GEngine.GameInstance.LocalPlayers[0].PlayerController.AcknowledgedPawn.isMoving
    vars.Helper["isMoving"] = vars.Helper.Make<bool>(gEngine, 0xD28, 0x38, 0x0, 0x30, 0x2A8, 0x998);
    vars.Helper["isMoving"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

    //Autosave splits
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
    vars.wasLoadingScreen = false;
    vars.onMenu = false;
    vars.arcade = "N/A";

    if (vars.version == 1.13) {
        vars.Pause                       = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F023C4);
        vars.mainMenu                    = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F464C0);
        vars.loadingScreen               = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F44904);
        vars.scooperCutscene             = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F45560, 0x28, 0x40, 0x118, 0xE4);
        vars.CollectedCautionBots        = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F01528, 0x08, 0x10, 0x38, 0x1B8);
        vars.ActiveGameAudio             = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F44240, 0x00, 0x260, 0x138);
        vars.camNum                      = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F01528, 0x08, 0x10, 0x38, 0xC0);
    } else {
        vars.Pause                       = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F03404);
        vars.mainMenu                    = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F47500);
        vars.loadingScreen               = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F45944);
        vars.scooperCutscene             = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F465A0, 0x28, 0x40, 0x118, 0xE4);
        vars.CollectedCautionBots        = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F02568, 0x08, 0x10, 0x38, 0x1B8);
        vars.ActiveGameAudio             = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F45280, 0x00, 0x260, 0x138);
        vars.camNum                      = new DeepPointer("fnaf9-Win64-Shipping.exe", 0x04F02568, 0x08, 0x10, 0x38, 0xC0);
    }

    vars.watchers = new MemoryWatcherList {
        new MemoryWatcher<bool>((IntPtr)null) { Name = "lastInteractible" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<long>(new DeepPointer(vars.UWorld, vars.offsets["AuthorityGameMode"], 0x318, 0x4E0, 0xC8, 0x18)) { Name = "closestInteractibleFName" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<Vector3f>(new DeepPointer(vars.GEngine, vars.offsets["GameInstance"], 0x38, 0x0, 0x30, 0x258, 0x298, 0x1D0)) { Name = "pos" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<int>(vars.scooperCutscene) { Name = "scooperCutscene" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<int>(vars.CollectedCautionBots) { Name = "CollectedCautionBots" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<int>(vars.ActiveGameAudio) { Name = "ActiveGameAudio" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<int>(vars.camNum) { Name = "camNum" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<int>(vars.Pause) { Name = "Pause" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<int>(vars.mainMenu) { Name = "mainMenu" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<int>(vars.loadingScreen) { Name = "loadingScreen" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
        new MemoryWatcher<IntPtr>(new DeepPointer(vars.UWorld, vars.offsets["AuthorityGameMode"], 0x318, 0x4E0, 0xC8)) { Name = "closestInteractibleAddress" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull },
    };

    vars.InZone = (Func<float, float, float, float, float, float, bool>)((casX, casZ, minX, maxX, minZ, maxZ) =>
    {
        return casX >= minX && casX <= maxX && casZ >= minZ && casZ <= maxZ;
    });

    vars.InElevatorLoad = false;
    vars.DoorOpenTime = 0;
    vars.WaitingForDoors = false;
    vars.StartingMopBots = 0;
    vars.CurrentMopBots = 0;

    vars.interactibleName = "";
    vars.watchers[0] = new MemoryWatcher<bool>((IntPtr)null){ Name = "lastInteractible" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull };

    vars.checkBoxNoBool = (Func<Vector3f, Vector3f, bool>)((point1, point2) => {
        // Calculate which X/Y/Z is the lower of the two points, and set the upper/lower bound point along that axis accordingly
        Vector3f LB = new Vector3f(Math.Min(point1.X, point2.X), Math.Min(point1.Y, point2.Y), Math.Min(point1.Z, point2.Z));
        Vector3f UB = new Vector3f(Math.Max(point1.X, point2.X), Math.Max(point1.Y, point2.Y), Math.Max(point1.Z, point2.Z));

        // Actually calculate if you are in the bounds of the defined cuboid
        // Includes a check to see if you've already completed this split (uses HashSet<string>, initialized in startup{})
        if (LB.X <= vars.watchers["pos"].Current.X && vars.watchers["pos"].Current.X <= UB.X
         && LB.Y <= vars.watchers["pos"].Current.Y && vars.watchers["pos"].Current.Y <= UB.Y
         && LB.Z <= vars.watchers["pos"].Current.Z && vars.watchers["pos"].Current.Z <= UB.Z){
            return true;
        }
        return false;
    });

    vars.checkElevs = (Func<bool>)(()
        => vars.checkBoxNoBool(new Vector3f(-50282, 90623, -382),new Vector3f(-49915, 90910, -135))    //Elevator Door Button
    );

    vars.resetVariables = (Action)(() => {
        //These 2 watchers are addresses which change while the game is running, and which change depending on what the player is interacting with.
        //Make sure they are not garbage data when reading.
        vars.interactibleName = "";
        vars.watchers[0] = new MemoryWatcher<bool>((IntPtr)null){ Name = "lastInteractible" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull };
        //vars.watchers[1] = new MemoryWatcher<bool>((IntPtr)null){ Name = "canCollect" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull };

        //Used to keep certain splits from repeating (reset)
        vars.CompletedSplits.Clear();

        vars.StartingMopBots = vars.watchers["CollectedCautionBots"].Current;
        vars.CurrentMopBots = 0;
        vars.InElevatorLoad = false;
        vars.DoorOpenTime = 0;
        vars.WaitingForDoors = false;
        current.AutoSaveID = "";
        vars.wasLoadingScreen = false;
        vars.onMenu = false;
        vars.arcade = "N/A";
    });
}

onStart
{
    vars.resetVariables();
}

update
{
    vars.watchers.UpdateAll(game);
    vars.Helper.Update();
    vars.Helper.MapPointers();

    var world = vars.FNameToString(current.GWorldName);
    if (!string.IsNullOrEmpty(world) && world != "None") current.World = world;
    if (old.World != current.World) vars.Log("World: " + current.World);

    var autosave = vars.FNameToString(current.LastAutoSaveID);
    if (!string.IsNullOrEmpty(autosave) && autosave != "None") current.AutoSaveID = autosave;
    
    string currentName = vars.GetNameFromFName(vars.watchers["closestInteractibleFName"].Current);
    string currInteract = (string)vars.interactibleName;
    IntPtr currentAddress = vars.watchers["closestInteractibleAddress"].Current;

    //Any elevator button
    if (currentName.Contains("ElevatorButton")){
        vars.watchers[0] = new MemoryWatcher<bool>(currentAddress+0x2E8){ Name = "lastInteractible" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull };
        vars.interactibleName = "elevButton";
    }

    if (vars.interactibleName == "elevButton" && !vars.checkElevs()){
        vars.watchers[0] = new MemoryWatcher<bool>((IntPtr)null){ Name = "lastInteractible" , FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull };
        vars.interactibleName = "";
    }

    vars.SetText("MopBots:", vars.watchers["CollectedCautionBots"].Current);
    vars.CurrentMopBots = vars.watchers["CollectedCautionBots"].Current;

    if ((current.AutoSaveID == "autosave_1_0") && (old.AutoSaveID != "autosave_1_0")) {
        vars.resetVariables();
        print("Reset variables");
    }
}

start
{
    return current.World == "MAP_World_DLC" && old.isMoving == false && current.isMoving == true;
}

split
{
    // Chapter Splits
    if (settings["Chapter"] || settings["AreaSplits"])
    {
        if (settings["vent_fall"] && !vars.CompletedSplits.Contains("vent_fall"))
        {
            if (vars.InZone(vars.watchers["pos"].Current.X, vars.watchers["pos"].Current.Y, -34726.0f, -34620.0f, 41230.0f, 41234.0f))
            {
                vars.CompletedSplits.Add("vent_fall");
                return true;
            }
        }
        if (current.AutoSaveID != "autosave_1_0" && current.AutoSaveID != "PlaySequenceTrigger_LobbyEntranceDLC" && current.AutoSaveID != "PlaySequenceTrigger_LobbyEntranceDLC_Intro_Cinematic")
        {
            if (settings[current.AutoSaveID.ToString()] && old.AutoSaveID != current.AutoSaveID && !vars.CompletedSplits.Contains(current.AutoSaveID.ToString()))
            {
                vars.CompletedSplits.Add(current.AutoSaveID.ToString());
                return true;
            }
        }
    }

    // Ending Splits
    if (settings["Endings"])
    {
        if (settings["brazil"] && !vars.CompletedSplits.Contains("Brazil"))
        {
            // if player puts on the mask
            if ((vars.watchers["pos"].Current.Z - vars.watchers["pos"].Old.Z) < -4500)
            {
                // if the player is near the fredbear cutout
                if (vars.InZone(vars.watchers["pos"].Current.X, vars.watchers["pos"].Current.Y, 18750.0f, 19300.0f, 60700.0f, 61600.0f))
                {
                    vars.CompletedSplits.Add("Brazil");
                    return true;
                }
            }
        }
        if (settings["scooper"] && !vars.CompletedSplits.Contains("Scooper"))
        {
            // if player is near scooper button
            if (vars.InZone(vars.watchers["pos"].Current.X, vars.watchers["pos"].Current.Y, 16100.0f, 16900.0f, 55900.0f, 57000.0f))
            {
                // if cutscene is triggered
                if ((vars.watchers["scooperCutscene"].Current == 1) && (vars.watchers["scooperCutscene"].Old == 0))
                {
                    vars.CompletedSplits.Add("Scooper");
                    return true;
                }
            }
        }
        if (settings["betrayal"] && !vars.CompletedSplits.Contains("Betrayal"))
        {
            // if player is near betrayal conduit
            if ((vars.watchers["pos"].Current.Z < -2800.0f) && (vars.watchers["pos"].Old.Z > -2800.0f))
            {
                var newName = vars.GetNameFromFName(vars.watchers["closestInteractibleFName"].Current);
                if ((vars.InZone(vars.watchers["pos"].Current.X, vars.watchers["pos"].Current.Y, 20300.0f, 20500.0f, 59700.0f, 59900.0f)) && (newName.Contains("None")))
                {
                    vars.CompletedSplits.Add("Betrayal");
                    return true;
                }
            }
        }
    }

    // Scooper Camera Splits
    if (settings["ScooperCameras"])
    {
        if (settings["camera1"] && vars.InZone(vars.watchers["pos"].Current.X, vars.watchers["pos"].Current.Y, -26750.0f, -26200.0f, 57650.0f, 58150.0f) && !vars.CompletedSplits.Contains("Camera1"))
        {
            if ((vars.watchers["camNum"].Current - vars.watchers["camNum"].Old) == 1)
            {
                vars.CompletedSplits.Add("Camera1");
                return true;
            }
        }
        if (settings["camera2"] && vars.InZone(vars.watchers["pos"].Current.X, vars.watchers["pos"].Current.Y, -41900.0f, -41100.0f, 42700.0f, 43250.0f) && !vars.CompletedSplits.Contains("Camera3"))
        {
            if ((vars.watchers["camNum"].Current - vars.watchers["camNum"].Old) == 1)
            {
                vars.CompletedSplits.Add("Camera3");
                return true;
            }
        }
        if (settings["camera3"] && vars.InZone(vars.watchers["pos"].Current.X, vars.watchers["pos"].Current.Y, -42900.0f, -42100.0f, 74900.0f, 76000.0f) && !vars.CompletedSplits.Contains("Camera5"))
        {
            if ((vars.watchers["camNum"].Current - vars.watchers["camNum"].Old) == 1)
            {
                vars.CompletedSplits.Add("Camera5");
                return true;
            }
        }
        if (settings["camera4"] && vars.InZone(vars.watchers["pos"].Current.X, vars.watchers["pos"].Current.Y, -34350.0f, -33500.0f, 71800.0f, 72750.0f) && !vars.CompletedSplits.Contains("Camera7"))
        {
            if ((vars.watchers["camNum"].Current - vars.watchers["camNum"].Old) == 1)
            {
                vars.CompletedSplits.Add("Camera7");
                return true;
            }
        }
    }

    // MopBot Splits
    if (settings["CollectedCautionBots"] && !vars.CompletedSplits.Contains("MopBot" + (vars.CurrentMopBots - vars.StartingMopBots)))
    {
        var oldName = vars.GetNameFromFName(vars.watchers["closestInteractibleFName"].Old);
        var newName = vars.GetNameFromFName(vars.watchers["closestInteractibleFName"].Current);
        if ((oldName.Contains("AR_HazardBot") || oldName.Contains("AR_Barrier") || oldName.Contains("CautionBot_DLC")) && newName.Contains("None")) {
            vars.CompletedSplits.Add("MopBot" + (vars.CurrentMopBots - vars.StartingMopBots));
            return true;
        }
    }
}

isLoading
{
    if (vars.watchers["pos"].Current.Y == 0 && vars.arcade == "N/A") {
        vars.onMenu = true;
    } else if (current.World != "MAP_Title" || vars.arcade != "N/A") {
        vars.onMenu = false;
    }
    if (vars.onMenu){
        return true;
    }

    if (vars.watchers["Pause"].Current == 3) {
        return true;
    }
    if (vars.watchers["loadingScreen"].Current == 1) {
        vars.wasLoadingScreen = true;
        return true;
    }
    if (vars.wasLoadingScreen) {
        if (current.AutoSaveID == "PlaySequenceTrigger_LobbyEntranceDLC_Intro_Cinematic") return true;
        if (current.World == "MAP_World_DLC"
          && old.isMoving == false
          && current.isMoving == true) {
            vars.wasLoadingScreen = false;
            return false;
        }
        else return true;
    }

    // isLoading logic for elevator in Chapter 9
    if (vars.interactibleName == "elevButton" && vars.watchers["lastInteractible"].Current){
        vars.InElevatorLoad = true;
        return true;
    }
    if (vars.InElevatorLoad && ((vars.watchers["ActiveGameAudio"].Old == 1) && (vars.watchers["ActiveGameAudio"].Current == 0))) {
        vars.InElevatorLoad = false;
        vars.DoorOpenTime = timer.CurrentTime.RealTime.Value.TotalSeconds;
        vars.WaitingForDoors = true;
    } else if (vars.InElevatorLoad) {
        return true;
    }
    if (vars.WaitingForDoors && ((timer.CurrentTime.RealTime.Value.TotalSeconds - vars.DoorOpenTime) > 2.333)) {
        vars.WaitingForDoors = false;
        return false;
    } else if (vars.WaitingForDoors) {
        return true;
    }
    return false;
}

exit
{
    timer.IsGameTimePaused = true;
}
