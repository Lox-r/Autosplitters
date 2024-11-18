state("Clay-Win64-Shipping"){}

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Basic");
    vars.Helper.GameName = "Garten of Banban";
    vars.Helper.AlertLoadless();

    vars.CompletedSplits = new HashSet<string>();
    vars.LoadingScreens = new List<string>() { "None", "Main_Menu", "Disclaimer" };
}

init
{
    IntPtr gWorld = vars.Helper.ScanRel(3, "48 8B 1D ???????? 48 85 DB 74 ?? 41 B0 01");
    IntPtr gEngine = vars.Helper.ScanRel(3, "48 8B 0D ???????? 66 0F 5A C9 E8");
    IntPtr fNames = vars.Helper.ScanRel(7, "8B D9 74 ?? 48 8D 15 ???????? EB");

    vars.Helper["POVX"] = vars.Helper.Make<double>(gEngine, 0x1058, 0x38, 0x0, 0x30, 0x348, 0x12D0);
    vars.Helper["POVY"] = vars.Helper.Make<double>(gEngine, 0x1058, 0x38, 0x0, 0x30, 0x348, 0x12D8);
    vars.Helper["POVZ"] = vars.Helper.Make<double>(gEngine, 0x1058, 0x38, 0x0, 0x30, 0x348, 0x12E0);

    //GWorld.???.???.Begin_Player_C
    vars.Helper["???"] = vars.Helper.Make<bool>(gEngine, 0x1058, 0x38, 0x0, 0x30, 0x348, 0x12D0);

    if (gWorld == IntPtr.Zero || gEngine == IntPtr.Zero || fNames == IntPtr.Zero)
    {
        const string Msg = "Not all required addresses could be found by scanning.";
        throw new Exception(Msg);
    }

    vars.Helper["GWorldName"] = vars.Helper.Make<ulong>(gWorld, 0x18);

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
}

update
{
    vars.Helper.Update();
    vars.Helper.MapPointers();

    var world = vars.FNameToString(current.GWorldName);
    if (!string.NullOrEmpty(world) && world != "None") current.World = world;
}

start
{
    return current.World == "FirstPersonMap" && old.POVX != current.POVX && current.POVX != 0 && old.POVX != 0;
}

isLoading
{
    return vars.LoadingScreens.Contains(current.World);
}

exit
{
    timer.IsGameTimePaused = true;
}