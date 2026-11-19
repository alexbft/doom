// Arena game loop: the wall switch starts the next level once the arena is clear.
//
// Pressing the switch (line id SWITCH_LINE_ID, see tools/build_arena.py):
//   * if monsters are alive -> refuse ("Kill all monsters first");
//   * otherwise level N+1 starts: "Level N" on screen, its monsters spawn away
//     from the player, items are scattered around, the weapon appears in the
//     arena center. Level contents come from ArenaLevelConfig (ARENALVL lump).
class ArenaHandler : EventHandler
{
	const SWITCH_LINE_ID = 1;
	const SPAWN_RADIUS = 860;       // arena octagon inner radius is ~946
	const ITEM_RADIUS = 700;
	const MONSTER_MIN_DIST = 640;   // from the player
	const SPAWN_TRIES = 64;
	const CLEAR_CHECK_TICS = 10;

	ArenaLevelConfig config;
	int arenaLevel;                 // last started level, 0 = none yet
	bool clearAnnounced;

	ArenaLevelConfig GetConfig()
	{
		if (!config) config = ArenaLevelConfig.Load();
		return config;
	}

	override void WorldLoaded(WorldEvent e)
	{
		if (!e.IsSaveGame) GetConfig();  // report config errors right at map start
	}

	override void WorldTick()
	{
		if (level.maptime == 5)
		{
			Announce("Press the switch\nto start");
		}
		else if (arenaLevel > 0 && !clearAnnounced && level.maptime % CLEAR_CHECK_TICS == 0
			&& CountAliveMonsters() == 0)
		{
			clearAnnounced = true;
			Announce(String.Format("Level %d cleared!\nPress the switch", arenaLevel));
		}
	}

	override void WorldLinePreActivated(WorldEvent e)
	{
		if (!IsArenaSwitch(e.ActivatedLine)) return;

		let pmo = e.Thing;
		if (!pmo || !pmo.player)
		{
			e.ShouldActivate = false;
			return;
		}

		int alive = CountAliveMonsters();
		if (alive > 0)
		{
			e.ShouldActivate = false;
			pmo.A_StartSound("*usefail", CHAN_VOICE);
			Announce(String.Format("Kill all monsters first\n%d left", alive));
			return;
		}
		StartLevel(arenaLevel + 1, pmo);
	}

	void StartLevel(int n, Actor pmo)
	{
		let cfg = GetConfig();
		let lv = cfg.Get(n);
		if (!lv) return;

		arenaLevel = n;
		clearAnnounced = false;
		Announce(String.Format("Level %d", n));

		double scale = cfg.Scale(n);
		Vector2 avoid = pmo.pos.xy;
		foreach (e : lv.monsters)
		{
			int cnt = ScaledCount(e.count, scale);
			for (int i = 0; i < cnt; i++)
			{
				let mo = SpawnRandom(e.cls, SPAWN_RADIUS, avoid, MONSTER_MIN_DIST);
				if (!mo) continue;
				mo.angle = mo.AngleTo(pmo);
				mo.SpawnTeleportFog(mo.pos, false, false);
			}
		}
		foreach (e : lv.items)
		{
			int cnt = ScaledCount(e.count, scale);
			for (int i = 0; i < cnt; i++)
			{
				let mo = SpawnRandom(e.cls, ITEM_RADIUS, avoid, 0);
				if (mo) Actor.Spawn("ItemFog", mo.pos);
			}
		}
		class<Weapon> w = cfg.WeaponFor(n);
		if (w)
		{
			let mo = Actor.Spawn(w, (0, 0, level.PointInSector((0, 0)).floorplane.ZAtPoint((0, 0))));
			if (mo) Actor.Spawn("ItemFog", mo.pos);
		}
	}

	static int ScaledCount(int count, double scale)
	{
		return count > 0 ? max(1, int(round(count * scale))) : 0;
	}

	// Spawns cls at a random free spot within `radius` of the arena center,
	// at least `minDist` from `avoid`. Returns null if no spot was found.
	static Actor SpawnRandom(class<Actor> cls, double radius, Vector2 avoid, double minDist)
	{
		for (int t = 0; t < SPAWN_TRIES; t++)
		{
			double a = FRandom(0, 360);
			double r = radius * sqrt(FRandom(0, 1));
			Vector2 p = (cos(a) * r, sin(a) * r);
			if ((p - avoid).Length() < minDist) continue;

			Vector3 pos = (p, level.PointInSector(p).floorplane.ZAtPoint(p));
			if (!level.IsPointInLevel(pos)) continue;

			let mo = Actor.Spawn(cls, pos, ALLOW_REPLACE);
			if (!mo) return null;
			if (mo.bSolid && !mo.TestMobjLocation())
			{
				mo.ClearCounters();
				mo.Destroy();
				continue;
			}
			return mo;
		}
		Console.Printf("\cgArena: no free spot for %s", cls.GetClassName());
		return null;
	}

	static bool IsArenaSwitch(Line ln)
	{
		if (!ln) return false;
		let it = level.CreateLineIdIterator(SWITCH_LINE_ID);
		int idx;
		while ((idx = it.Next()) >= 0)
		{
			if (idx == ln.Index()) return true;
		}
		return false;
	}

	static int CountAliveMonsters()
	{
		int n = 0;
		let it = ThinkerIterator.Create("Actor");
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (mo.bIsMonster && !mo.bFriendly && mo.health > 0) n++;
		}
		return n;
	}

	static void Announce(String msg)
	{
		Console.MidPrint(Font.GetFont("BIGFONT"), msg);
	}
}
