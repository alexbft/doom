version "4.10"

// Dev-only helper (loaded by tools/devrun.sh when SHOTS is set).
// Plays a short scripted scene after the map starts and takes screenshots.
// Requires enablescriptscreenshot=1.
//
// Scenes (cvar devshot_scene, set from SHOTS=<name>):
//   look   - turn around in the center: 4 shots at 0/90/180/270 degrees
//   button - walk up to the east switch, press it, look at the spawn area
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
		if (scene == "button") ButtonScene(pmo, t);
		else LookScene(pmo, t);
	}

	void LookScene(PlayerPawn pmo, int t)
	{
		static const double ANGLES[] = { 0, 90, 180, 270 };
		int i = t / 15;
		if (i >= ANGLES.Size()) return;
		if (t % 15 == 0) Face(pmo, ANGLES[i]);
		else if (t % 15 == 14) level.MakeScreenShot();
	}

	void ButtonScene(PlayerPawn pmo, int t)
	{
		switch (t)
		{
		case 0:   pmo.SetOrigin((860, 0, 0), false); Face(pmo, 0); break;
		case 10:  level.MakeScreenShot(); break;                 // the switch up close
		case 15:  PressSwitch(pmo); break;
		case 20:  level.MakeScreenShot(); break;                 // switch toggled
		case 25:  pmo.SetOrigin((0, 0, 0), false); Face(pmo, 180); break;
		case 30:  level.MakeScreenShot(); break;                 // teleport fog
		case 60:  level.MakeScreenShot(); break;                 // monsters
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
			if (ln.special == 135) // Thing_Spawn
			{
				ln.Activate(pmo, Line.front, SPAC_Use);
				return;
			}
		}
		Console.Printf("devshot: switch line not found");
	}
}
