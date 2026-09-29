using System;
using System.IO;
using System.Runtime.Loader;
using System.Security.Cryptography;
using System.Diagnostics;
using System.Reflection;
using GoNextCoreRepair;

if (args[0] == "--load")
{
    try { AssemblyLoadContext.Default.LoadFromAssemblyPath(args[1]); Environment.Exit(0); }
    catch (BadImageFormatException) { Environment.Exit(10); }
    return;
}
string original = args[0];
string testDir = Path.GetFullPath(args[1]);
Directory.CreateDirectory(testDir);
foreach (string file in Directory.GetFiles(original, "*.dll"))
    File.Copy(file, Path.Combine(testDir, Path.GetFileName(file)), true);
string target = Path.Combine(testDir, "UnityEngine.CoreModule.dll");
byte[] generated = File.ReadAllBytes(target);
string Hash() => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(target)));
void Assert(bool condition, string message) { if (!condition) throw new Exception(message); Console.WriteLine("PASS " + message); }
bool Loads()
{
    var start = new ProcessStartInfo(Environment.ProcessPath) { UseShellExecute = false, CreateNoWindow = true };
    if (Path.GetFileNameWithoutExtension(Environment.ProcessPath).Equals("dotnet", StringComparison.OrdinalIgnoreCase))
        start.ArgumentList.Add(Assembly.GetExecutingAssembly().Location);
    start.ArgumentList.Add("--load");
    start.ArgumentList.Add(target);
    using var child = Process.Start(start);
    child.WaitForExit();
    if (child.ExitCode != 0 && child.ExitCode != 10) throw new Exception("Unexpected loader exit: " + child.ExitCode);
    return child.ExitCode == 0;
}
Assert(!Loads(), "Original reproduces BadImageFormatException");
Assert(CoreRepair.Repair(testDir), "First repair applied");
Assert(Loads(), "Repaired assembly accepted by CLR");
string fixedHash = Hash();
Assert(!CoreRepair.Repair(testDir) && Hash() == fixedHash, "Second startup makes no changes");
Assert(Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(target + ".orig"))) == Convert.ToHexString(SHA256.HashData(generated)), "Original preserved in backup");
File.WriteAllBytes(target, generated);
Assert(CoreRepair.Repair(testDir), "Regenerated assembly repaired again");
Assert(Loads(), "Regenerated repaired assembly accepted by CLR");
