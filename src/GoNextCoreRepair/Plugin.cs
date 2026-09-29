using System;
using MelonLoader;
using MelonLoader.Utils;

[assembly: MelonInfo(typeof(GoNextCoreRepair.Plugin), "Go Next Core Repair", "1.0.0", "local")]
[assembly: MelonGame("Go Next demo", "Go Next demo")]

namespace GoNextCoreRepair;

// Deliberately references no Unity or generated game assemblies: those are not safe yet.
public sealed class Plugin : MelonPlugin
{
    public override void OnPreModsLoaded()
    {
        try
        {
            bool changed = CoreRepair.Repair(MelonEnvironment.Il2CppAssembliesDirectory);
            LoggerInstance.Msg(changed ? "CoreModule repaired before mod loading." : "CoreModule repair hash verified; no changes needed.");
        }
        catch (Exception e)
        {
            LoggerInstance.Error("CoreModule automatic repair failed: " + e);
        }
    }
}
