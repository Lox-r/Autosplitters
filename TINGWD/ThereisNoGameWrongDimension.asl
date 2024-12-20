//Autostart and split made by lox
state("Ting"){}

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.GameName = "There Is No Game: Wrong Dimension";
    vars.Helper.LoadSceneManager = true;
    vars.Helper.AlertRealTime();

    dynamic[,] _settings =
    {
        { "ChapterSplits", false, "Speedrun Category - Chapter Splits", null},
            { "Chapter3", true, "Complete Chapter 1", "ChapterSplits" },
            { "Chapter4a", true, "Complete Chapter 2", "ChapterSplits" },
            { "Chapter4b", true, "Complete Chapter 3", "ChapterSplits" },
            { "Chapter5", true, "Complete Chapter 4", "ChapterSplits" },
            { "Chapter6a", true, "Complete Chapter 5", "ChapterSplits" },
            { "End", true, "Complete Chapter 6", "ChapterSplits" },
        { "EndingSplits", false, "Speedrun Category - Ending Splits", null},
            { "E_End", true, "Click on either of the Buttons at the end of the game", "EndingSplits" },
    };

    vars.Helper.Settings.Create(_settings);
    vars.CompletedSplits = new HashSet<string>();
}

init
{
    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
        var ic = mono["Xen.Framework.InteractionController", 1];
        var h = mono["Xen.Framework.Hotspot"];

        vars.Helper["lastInteraction"] = ic.MakeString("_mInstance", "_lastTriggeredHotspot", h["_activationEvent"]);
        vars.Helper["lastInteraction"] = ic.MakeString("_mInstance", "_lastTriggeredHotspot", h["_activationEvent"]);
		vars.Helper["lastInteractionIntPtr"] = ic.Make<IntPtr>("_mInstance", "_lastTriggeredHotspot");
		vars.Helper["lastInteractionIntPtr"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;
		vars.Helper["currentInteraction"] = ic.MakeString("_mInstance", "_currentHotspot", h["_activationEvent"]);
		vars.Helper["currentInteractionIntPtr"] = ic.Make<IntPtr>("_mInstance", "_currentHotspot");
		vars.Helper["currentInteractionIntPtr"].FailAction = MemoryWatcher.ReadFailAction.SetZeroOrNull;

        return true;
    });

    current.Interaction = "";
	current.currentInteraction = "";
	current.currentInteractionPrint = "0";
	current.overColliderPrint = "0";
	vars.ButtonReady = false;
	vars.ButtonPrepReady = false;
}

onStart
{
	vars.ButtonPrepReady = false;
	vars.ButtonReady = false;
    vars.CompletedSplits.Clear();
}

start
{
    return current.activeScene == "Chapter1";
}

update
{
    if(!String.IsNullOrWhiteSpace(vars.Helper.Scenes.Active.Name))    current.activeScene = vars.Helper.Scenes.Active.Name;
    if(current.activeScene != old.activeScene) vars.Log("active: Old: \"" + old.activeScene + "\", Current: \"" + current.activeScene + "\"");

	if(current.currentInteractionIntPtr != old.currentInteractionIntPtr) vars.Log("currentInteractionIntPtr: Old: \"" + old.currentInteractionIntPtr.ToString() + "\", Current: \"" + current.currentInteractionIntPtr.ToString() + "\"");
	if (old.currentInteractionIntPtr != current.currentInteractionIntPtr) current.currentInteractionPrint = current.currentInteractionIntPtr.ToString("X");
	if (current.activeScene == "End" && current.currentInteraction == "EVT_Click" && old.currentInteractionPrint != "0" && current.currentInteractionPrint == "0") vars.ButtonPrepReady = true;
	if (current.activeScene == "End" && current.currentInteraction == "EVT_Click" && vars.ButtonPrepReady == true && old.currentInteractionPrint == "0" && current.currentInteractionPrint != "0") vars.ButtonReady = true;

}

split
{
    if (settings["ChapterSplits"])
    {
        if (current.activeScene != "Chapter1" && current.activeScene != "Menus")
        {
            if (settings[current.activeScene] && old.activeScene != current.activeScene && !vars.CompletedSplits.Contains(current.activeScene))
            {
                vars.CompletedSplits.Add(current.activeScene);
                return true;
            }
        }
    }

	if (settings["EndingSplits"])
    {
        if (settings["E_End"] && current.currentInteraction == "EVT_Click" && current.lastInteraction == "EVT_Click" && vars.ButtonReady == true 
			&& old.currentInteractionPrint != "0" && current.currentInteractionPrint == "0" && !vars.CompletedSplits.Contains("E_End"))
			{
				vars.CompletedSplits.Add("E_End");
				return true;
			}
    }
}
