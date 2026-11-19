// Level configuration: parsed from the ARENALVL text lump (mod/ARENALVL.txt).

class ArenaSpawnEntry
{
	class<Actor> cls;
	int count;
}

class ArenaLevel
{
	Array<ArenaSpawnEntry> monsters;
	Array<ArenaSpawnEntry> items;
	class<Weapon> weapon;
}

class ArenaLevelConfig
{
	const LUMP = "ARENALVL";

	Array<ArenaLevel> levels;
	double overflowScale;

	static ArenaLevelConfig Load()
	{
		let cfg = new("ArenaLevelConfig");
		cfg.overflowScale = 0.25;
		int lump = Wads.FindLump(LUMP);
		if (lump < 0)
		{
			Console.Printf("\cgArena: config lump %s not found", LUMP);
			return cfg;
		}
		cfg.Parse(Wads.ReadLump(lump));
		if (cfg.levels.Size() == 0) Console.Printf("\cgArena: %s defines no levels", LUMP);
		return cfg;
	}

	// Level n is 1-based. Past the end the last level repeats (see Scale).
	ArenaLevel Get(int n)
	{
		if (levels.Size() == 0) return null;
		return levels[clamp(n, 1, levels.Size()) - 1];
	}

	// Count multiplier for level n.
	double Scale(int n)
	{
		int extra = n - levels.Size();
		return extra > 0 ? 1.0 + overflowScale * extra : 1.0;
	}

	// The weapon is only given on its own level, not on repeats.
	class<Weapon> WeaponFor(int n)
	{
		return n <= levels.Size() ? Get(n).weapon : null;
	}

	private void Parse(String text)
	{
		Array<String> lines;
		text.Split(lines, "\n");
		ArenaLevel cur;
		for (int ln = 0; ln < lines.Size(); ln++)
		{
			String line = lines[ln];
			int c = line.IndexOf("//");
			if (c >= 0) line = line.Left(c);
			c = line.IndexOf("#");
			if (c >= 0) line = line.Left(c);
			line.Replace("\t", " ");
			line.Replace("\r", " ");

			Array<String> tok;
			line.Split(tok, " ", TOK_SKIPEMPTY);
			if (tok.Size() == 0) continue;

			String key = tok[0].MakeLower();
			if (key == "level")
			{
				cur = new("ArenaLevel");
				levels.Push(cur);
			}
			else if (key == "overflow_scale" && tok.Size() >= 2)
			{
				overflowScale = tok[1].ToDouble();
			}
			else if (!cur)
			{
				Error(ln, "'" .. tok[0] .. "' before the first 'level'");
			}
			else if (key == "monster" || key == "item")
			{
				if (tok.Size() < 3) { Error(ln, "expected: " .. key .. " <Class> <count>"); continue; }
				class<Actor> cls = tok[1];
				if (!cls) { Error(ln, "unknown class " .. tok[1]); continue; }
				let e = new("ArenaSpawnEntry");
				e.cls = cls;
				e.count = tok[2].ToInt();
				if (key == "monster") cur.monsters.Push(e);
				else cur.items.Push(e);
			}
			else if (key == "weapon" && tok.Size() >= 2)
			{
				class<Weapon> w = tok[1];
				if (!w) { Error(ln, "unknown weapon " .. tok[1]); continue; }
				cur.weapon = w;
			}
			else
			{
				Error(ln, "can't parse '" .. lines[ln] .. "'");
			}
		}
	}

	private static void Error(int ln, String msg)
	{
		Console.Printf("\cgArena: %s line %d: %s", LUMP, ln + 1, msg);
	}
}
