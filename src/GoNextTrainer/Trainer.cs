using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using MelonLoader;
using UnityEngine;

using GameHealth = Il2Cpp.PlayerHealth;
using GameStats = Il2Cpp.PlayerStats;
using GameGold = Il2Cpp.PlayerGold;
using GameLevel = Il2Cpp.PlayerLevel;
using GameDash = Il2Cpp.PlayerDashCharges;
using GameEnemies = Il2Cpp.EnemyRegistry;

[assembly: MelonInfo(typeof(GoNextTrainer.Trainer), "Go Next Trainer", "1.2.0", "local")]
[assembly: MelonGame("Go Next demo", "Go Next demo")]

namespace GoNextTrainer
{
    /// <summary>
    /// Input is read straight from WinAPI rather than UnityEngine.Input: the game
    /// is built on the new Input System, where legacy input can be disabled and
    /// Input.GetKeyDown then throws.
    /// </summary>
    internal static class Keys
    {
        [DllImport("user32.dll")]
        private static extern short GetAsyncKeyState(int vKey);

        private static readonly HashSet<int> Held = new HashSet<int>();

        public const int F1 = 0x70, F2 = 0x71, F3 = 0x72, F4 = 0x73;
        public const int F5 = 0x74, F6 = 0x75, F7 = 0x76, F8 = 0x77;
        public const int F9 = 0x78, F10 = 0x79, F11 = 0x7A, F12 = 0x7B;
        public const int Insert = 0x2D;
        public const int PageUp = 0x21, PageDown = 0x22;
        public const int Home = 0x24, End = 0x23;
        public const int Ctrl = 0x11;

        /// <summary>Fires once per press instead of every frame the key is held.</summary>
        public static bool Down(int vk)
        {
            bool now = IsDown(vk);
            if (now)
            {
                if (Held.Contains(vk)) return false;
                Held.Add(vk);
                return true;
            }
            Held.Remove(vk);
            return false;
        }

        public static bool IsDown(int vk)
        {
            return (GetAsyncKeyState(vk) & 0x8000) != 0;
        }
    }

    internal sealed class Toggle
    {
        public readonly string Name;
        public readonly int Key;
        public readonly string KeyName;
        public bool On;

        public Toggle(string name, int key, string keyName)
        {
            Name = name;
            Key = key;
            KeyName = keyName;
        }
    }

    public class Trainer : MelonMod
    {
        private Toggle _god, _damage, _dash, _speed, _magnet, _jumps, _luck;
        private Toggle _fireRate, _pierce, _lifesteal;
        private readonly List<Toggle> _toggles = new List<Toggle>();

        private float _damageMult = 50f;
        private float _speedMult = 2.5f;
        private float _fireRateMult = 5f;

        private bool _menu = true;
        private bool _netBlocked;
        private string _flash = "";
        private float _flashUntil;

        public override void OnInitializeMelon()
        {
            _god = Add("Invincibility", Keys.F1, "F1");
            _damage = Add("Mega damage", Keys.F2, "F2");
            _dash = Add("Infinite dash", Keys.F3, "F3");
            _speed = Add("Move speed", Keys.F4, "F4");
            _magnet = Add("Loot magnet", Keys.F5, "F5");
            _jumps = Add("Infinite jumps", Keys.F6, "F6");
            _luck = Add("Luck / gold / XP", Keys.F7, "F7");
            _fireRate = Add("Fire rate", Keys.F8, "F8");
            _pierce = Add("Pierce", Keys.Home, "Home");
            _lifesteal = Add("Lifesteal", Keys.End, "End");

            LoggerInstance.Msg("Go Next Trainer loaded. Press Insert to show/hide the menu.");
        }

        private Toggle Add(string name, int key, string keyName)
        {
            var t = new Toggle(name, key, keyName);
            _toggles.Add(t);
            return t;
        }

        private void Flash(string msg)
        {
            _flash = msg;
            _flashUntil = Time.realtimeSinceStartup + 2.5f;
            LoggerInstance.Msg(msg);
        }

        /// <summary>
        /// Co-op syncs progress and enemy state between players (CoopGoldSync /
        /// CoopSoulSync / CoopEnemySync), so every cheat is killed while a network
        /// session is live.
        /// </summary>
        private bool NetworkActive()
        {
            try
            {
                return Il2CppMirror.NetworkClient.active || Il2CppMirror.NetworkServer.active;
            }
            catch
            {
                return false;
            }
        }

        public override void OnUpdate()
        {
            if (Keys.Down(Keys.Insert)) _menu = !_menu;

            bool net = NetworkActive();
            if (net && !_netBlocked)
            {
                foreach (var t in _toggles) t.On = false;
                Flash("Network session — cheats disabled");
            }
            _netBlocked = net;
            if (net) return;

            foreach (var t in _toggles)
            {
                if (Keys.Down(t.Key))
                {
                    t.On = !t.On;
                    Flash(t.Name + (t.On ? ": ON" : ": OFF"));
                }
            }

            // Ctrl acts as a modifier: with it PgUp/PgDn drive speed, without it damage.
            bool ctrl = Keys.IsDown(Keys.Ctrl);
            if (Keys.Down(Keys.PageUp))
            {
                if (ctrl) { _speedMult = Math.Min(_speedMult + 0.5f, 20f); Flash("Speed x" + _speedMult); }
                else { _damageMult = Math.Min(_damageMult * 2f, 100000f); Flash("Damage x" + _damageMult); }
            }
            if (Keys.Down(Keys.PageDown))
            {
                if (ctrl) { _speedMult = Math.Max(_speedMult - 0.5f, 1f); Flash("Speed x" + _speedMult); }
                else { _damageMult = Math.Max(_damageMult / 2f, 1f); Flash("Damage x" + _damageMult); }
            }

            if (Keys.Down(Keys.F9)) GiveGold(10000);
            if (Keys.Down(Keys.F10)) GiveLevel();
            if (Keys.Down(Keys.F11)) KillAll();
            if (Keys.Down(Keys.F12)) FullHeal();
        }

        /// <summary>
        /// Values are re-applied every frame in LateUpdate: the item system
        /// recalculates stats in its own Update, so a single write would not stick.
        /// </summary>
        public override void OnLateUpdate()
        {
            if (_netBlocked) return;

            // GodMode is static in this game, next to a static ResetGodMode
            if (_god.On) GameHealth.GodMode = true;
            else if (GameHealth.GodMode) GameHealth.GodMode = false;

            var st = SafeStats();
            if (st == null) return;

            if (_god.On) st.incomingDamageMult = 0f;

            if (_damage.On)
            {
                st.damageMult = _damageMult;
                st.critChance = 1f;
                if (st.critDamageMult < 5f) st.critDamageMult = 5f;
            }

            if (_speed.On) st.moveSpeedMult = _speedMult;
            if (_magnet.On) st.pickupRange = 300f;
            if (_jumps.On) st.extraJumps = 99;

            if (_fireRate.On) st.fireRateMult = _fireRateMult;

            // 99 pierces: projectiles pass straight through a crowd
            if (_pierce.On) st.projectilePierces = 99;

            // 1.0: all damage dealt comes back as health
            if (_lifesteal.On) st.lifestealFraction = 1f;

            if (_luck.On)
            {
                st.luck = 100f;
                st.goldGainMult = 10f;
                st.xpGainMult = 10f;
                st.rewardDropBonus = 5f;
            }

            if (_dash.On)
            {
                var d = SafeDash();
                if (d != null && d.Charges < d.MaxCharges) d.Charges = d.MaxCharges;
            }
        }

        private static GameStats SafeStats() { try { return GameStats.Instance; } catch { return null; } }
        private static GameDash SafeDash() { try { return GameDash.Instance; } catch { return null; } }

        private void GiveGold(int amount)
        {
            try
            {
                var g = GameGold.Instance;
                if (g == null) { Flash("Gold: not in a run"); return; }
                g.Add(amount);
                Flash("+" + amount + " gold");
            }
            catch (Exception e) { LoggerInstance.Warning("GiveGold: " + e.Message); }
        }

        private void GiveLevel()
        {
            try
            {
                var l = GameLevel.Instance;
                if (l == null) { Flash("Level: not in a run"); return; }
                int need = l.XpToNext;
                l.AddXp(need > 0 ? need : 1000);
                Flash("+1 level");
            }
            catch (Exception e) { LoggerInstance.Warning("GiveLevel: " + e.Message); }
        }

        private void FullHeal()
        {
            try
            {
                var h = GameHealth.Instance;
                if (h == null) { Flash("Heal: not in a run"); return; }
                h.RefillToMax();
                Flash("Health restored");
            }
            catch (Exception e) { LoggerInstance.Warning("FullHeal: " + e.Message); }
        }

        private void KillAll()
        {
            try
            {
                var all = GameEnemies.All;
                if (all == null) { Flash("No enemies"); return; }

                // the live list mutates as enemies die, so snapshot it first
                var snapshot = new List<Il2Cpp.EnemyRobot>();
                for (int i = 0; i < all.Count; i++)
                {
                    var e = all[i];
                    if (e != null) snapshot.Add(e);
                }

                int killed = 0;
                foreach (var e in snapshot)
                {
                    try
                    {
                        if (e.dead) continue;
                        e.TakeDamage(1000000.0);
                        killed++;
                    }
                    catch { }
                }
                Flash("Enemies killed: " + killed);
            }
            catch (Exception e) { LoggerInstance.Warning("KillAll: " + e.Message); }
        }

        // GUILayout is stripped from this IL2CPP build (Method unstripping failed),
        // so the overlay is drawn only with GUI.Box / GUI.Label at explicit rects.
        private const int PanelW = 340;
        private const int LineH = 19;

        private static readonly Color ColOn = new Color(0.49f, 1f, 0.49f);
        private static readonly Color ColOff = new Color(0.60f, 0.60f, 0.60f);
        private static readonly Color ColWarn = new Color(1f, 0.40f, 0.40f);
        private static readonly Color ColHint = new Color(1f, 0.84f, 0.36f);
        private static readonly Color ColText = Color.white;

        private int _y;

        private void Line(string text, Color color)
        {
            GUI.contentColor = color;
            GUI.Label(new Rect(22, _y, PanelW - 20, LineH), text);
            _y += LineH;
        }

        public override void OnGUI()
        {
            if (!_menu) return;

            int lines = _netBlocked ? 2 : (_toggles.Count + 6);
            if (!string.IsNullOrEmpty(_flash) && Time.realtimeSinceStartup < _flashUntil) lines++;
            int h = 16 + (lines + 1) * LineH;

            GUI.contentColor = ColText;
            GUI.Box(new Rect(12, 12, PanelW, h), "");

            _y = 20;
            Line("Go Next Trainer   (Insert to hide)", ColText);

            if (_netBlocked)
            {
                Line("Network session: cheats disabled", ColWarn);
            }
            else
            {
                foreach (var t in _toggles)
                    Line($"[{t.KeyName}] {t.Name} — {(t.On ? "ON" : "off")}", t.On ? ColOn : ColOff);

                Line($"Damage x{_damageMult}  ·  Speed x{_speedMult}  ·  Rate x{_fireRateMult}", ColText);
                Line("PgUp / PgDn — damage,  Ctrl + PgUp / PgDn — speed", ColText);
                Line("[F9] +10000 gold     [F10] +1 level", ColText);
                Line("[F11] kill all       [F12] full heal", ColText);
            }

            if (!string.IsNullOrEmpty(_flash) && Time.realtimeSinceStartup < _flashUntil)
                Line(_flash, ColHint);

            GUI.contentColor = ColText;
        }
    }
}
