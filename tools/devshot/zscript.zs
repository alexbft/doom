version "4.10"

// Dev-only helper (loaded by tools/devrun.sh when SHOTS is set).
// Plays a short scripted scene after the map starts and takes screenshots.
// Requires enablescriptscreenshot=1.
//
// Scenes (cvar devshot_scene, set from SHOTS=<name>):
//   start  - one shot from the player start, untouched
//   look   - turn around near the center (east of the pool): 4 shots at 0/90/180/270 degrees
//   button - walk up to the east switch, press it, look at the spawn area
//   acid   - stand in the acid pool for 2 s, shot (health should drop)
//   levels - level 1, refused press, kill all, cleared message, level 2
class DevShotHandler : EventHandler
{
	const START = 35;   // let the level settle for a second

	override void WorldTick()
	{
		let pmo = players[consoleplayer].mo;
		if (!pmo) return;
		int t = level.maptime - START;
		if (t < 0) return;

		String scene = CVar.FindCVar('devshot_scene').GetString();
		if (scene == "start") { if (t == 0) level.MakeScreenShot(); }
		else if (scene == "button") ButtonScene(pmo, t);
		else if (scene == "levels") LevelsScene(pmo, t);
		else if (scene == "acid") AcidScene(pmo, t);
		else LookScene(pmo, t);
	}

	void LookScene(PlayerPawn pmo, int t)
	{
		static const double ANGLES[] = { 0, 90, 180, 270 };
		int i = t / 15;
		if (i >= ANGLES.Size()) return;
		if (t == 0) pmo.SetOrigin((480, 0, 0), false);   // just east of the acid pool
		if (t % 15 == 0) Face(pmo, ANGLES[i]);
		else if (t % 15 == 14) level.MakeScreenShot();
	}

	void ButtonScene(PlayerPawn pmo, int t)
	{
		switch (t)
		{
		case 0:   Face(pmo, 0); break;                           // player start is in front of the switch
		case 10:  level.MakeScreenShot(); break;                 // the switch up close
		case 15:  PressSwitch(pmo); break;
		case 20:  level.MakeScreenShot(); break;                 // switch toggled
		case 25:  pmo.SetOrigin((480, 0, 0), false); Face(pmo, 180); break;
		case 30:  level.MakeScreenShot(); break;                 // teleport fog
		case 60:  level.MakeScreenShot(); break;                 // monsters
		}
	}

	void LevelsScene(PlayerPawn pmo, int t)
	{
		switch (t)
		{
		case 0:   pmo.player.cheats |= CF_GODMODE; PressSwitch(pmo); break;
		case 5:   level.MakeScreenShot(); break;                 // "Level 1"
		case 10:  Face(pmo, 180); break;
		case 45:  level.MakeScreenShot(); break;                 // monsters, items, weapon
		case 50:  Face(pmo, 0); PressSwitch(pmo); break;
		case 55:  level.MakeScreenShot(); break;                 // "Kill all monsters first"
		case 60:  KillAll(); pmo.A_SetHealth(30); break;
		case 90:  level.MakeScreenShot(); break;                 // "Level 1 cleared!", 30% health
		case 120: PressSwitch(pmo); break;
		case 125: level.MakeScreenShot(); break;                 // "Level 2", healed to 100%
		}
	}

	void AcidScene(PlayerPawn pmo, int t)
	{
		if (t == 0) { pmo.SetOrigin((0, 0, 0), false); Face(pmo, 180); }
		else if (t == 70) level.MakeScreenShot();
	}

	static void KillAll()
	{
		let it = ThinkerIterator.Create("Actor");
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (mo.bIsMonster && mo.health > 0) mo.DamageMobj(null, null, 1000000, 'None');
		}
	}

	static void Face(PlayerPawn pmo, double ang)
	{
		pmo.A_SetAngle(ang);
		pmo.A_SetPitch(0);
	}

	static void PressSwitch(PlayerPawn pmo)
	{
		foreach (ln : level.Lines)
		{
			if (ArenaHandler.IsArenaSwitch(ln))
			{
				ln.Activate(pmo, Line.front, SPAC_Use);
				return;
			}
		}
		Console.Printf("devshot: switch line not found");
	}
}
