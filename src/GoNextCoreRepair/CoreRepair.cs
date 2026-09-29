using System;
using System.IO;
using System.Security.Cryptography;
using Mono.Cecil;

namespace GoNextCoreRepair;

public static class CoreRepair
{
    private static string Hash(string file)
    {
        using var stream = File.OpenRead(file);
        using var sha = SHA256.Create();
        return Convert.ToHexString(sha.ComputeHash(stream));
    }

    public static bool Repair(string directory)
    {
        string target = Path.Combine(directory, "UnityEngine.CoreModule.dll");
        string backup = target + ".orig";
        string stamp = Path.Combine(directory, "UnityEngine.CoreModule.fixed.sha256");
        if (!File.Exists(target)) throw new FileNotFoundException("Generated CoreModule is missing.", target);
        if (File.Exists(stamp) && File.Exists(backup) && File.ReadAllText(stamp).Trim() == Hash(target)) return false;

        string temporary = target + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var resolver = new DefaultAssemblyResolver())
            {
                resolver.AddSearchDirectory(directory);
                var parameters = new ReaderParameters { AssemblyResolver = resolver, ReadingMode = ReadingMode.Immediate };
                using var assembly = AssemblyDefinition.ReadAssembly(target, parameters);
                assembly.Write(temporary);
            }
            // Validate the completed output before atomically replacing the original.
            using (var check = AssemblyDefinition.ReadAssembly(temporary))
                if (check.Name.Name != "UnityEngine.CoreModule") throw new InvalidDataException("Unexpected assembly identity.");
            string repairedHash = Hash(temporary);
            File.Replace(temporary, target, backup, ignoreMetadataErrors: true);
            File.WriteAllText(stamp, repairedHash + Environment.NewLine);
            return true;
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }
}
