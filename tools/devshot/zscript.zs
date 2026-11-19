version "4.10"

// Dev-only helper (loaded by tools/devrun.sh when SHOTS is set).
// Plays a short scripted scene after the map starts and takes screenshots.
// Requires enablescriptscreenshot=1.
//
// Scenes (cvar devshot_scene, set from SHOTS=<name>):
//   start  - from the player start: the switch, then turn around to the arena
//   look   - turn around near the center (east of the pool): 4 shots at 0/90/180/270 degrees
//   button - walk up to the east switch, press it, look at the spawn area
//   acid   - stand in the acid pool for 2 s, shot (health should drop)
//   spawncheck - spawn 300 random Barons/items, print how many overlap a
//            different floor height or the void (should be 0), one shot
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
		if (scene == "start") StartScene(pmo, t);
		else if (scene == "button") ButtonScene(pmo, t);
		else if (scene == "levels") LevelsScene(pmo, t);
		else if (scene == "acid") AcidScene(pmo, t);
		else if (scene == "spawncheck") SpawnCheckScene(pmo, t);
		else LookScene(pmo, t);
	}

	void StartScene(PlayerPawn pmo, int t)
	{
		if (t == 0) level.MakeScreenShot();
		else if (t == 5) Face(pmo, 180);
		else if (t == 10) level.MakeScreenShot();
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

	void SpawnCheckScene(PlayerPawn pmo, int t)
	{
		if (t == 0)
		{
			pmo.player.cheats |= CF_GODMODE;
			int bad, total;
			for (int i = 0; i < 300; i++)
			{
				// Baron: big radius (24), Clip: a non-solid item
				class<Actor> cls = (i % 2) ? "BaronOfHell" : "Clip";
				let mo = ArenaHandler.SpawnRandom(cls, ArenaHandler.SPAWN_RADIUS, pmo.pos.xy, 0);
				if (!mo) continue;
				total++;
				if (!FlatUnder(mo)) bad++;
				if (mo.bIsMonster) mo.bDormant = true;   // don't wander off before the check
			}
			Console.Printf("spawncheck: %d spawned, %d bad", total, bad);
		}
		else if (t == 10) level.MakeScreenShot();
	}

	// Center and the 4 box corners are all in the level at the same floor height.
	static bool FlatUnder(Actor mo)
	{
		double r = mo.radius;
		double z = mo.CurSector.floorplane.ZAtPoint(mo.pos.xy);
		static const double DX[] = { 0, -1, 1, -1, 1 };
		static const double DY[] = { 0, -1, -1, 1, 1 };
		for (int k = 0; k < 5; k++)
		{
			Vector2 p = mo.pos.xy + (DX[k] * r, DY[k] * r);
			if (!level.IsPointInLevel((p, z))) return false;
			if (abs(level.PointInSector(p).floorplane.ZAtPoint(p) - z) > 0.5) return false;
		}
		return true;
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
