#!/usr/bin/env python3
"""Generate mod/maps/ARENA01.wad: an octagonal open-sky arena (UDMF).

Layout (all rings are concentric octagons, corner 0 at +22.5 deg so edge 0
is the flat east wall):
  * flat main floor in the middle with an acid (nukage) pool at the center;
  * along the walls, colosseum-style spectator tiers: each rises STEP_H
    (still walkable) and the last, widest one is a walkway along the wall;
  * square pillars (holes in the main floor sector) give some cover;
  * a switch sits in a small niche in the middle of the east wall, at ledge
    level; the player starts on the steps in front of it, facing it;
  * the switch line has id SWITCH_LINE_ID; the game logic (ArenaHandler in
    mod/zscript/arena.zs) catches its activation and starts the next level.
    The line special itself is a no-op (sets the niche light to its own
    value) - it only exists so the switch is usable and toggles its texture.

UZDoom builds BSP nodes itself when they are missing, so the WAD only holds
the map marker, TEXTMAP and ENDMAP lumps.

Usage: python3 tools/build_arena.py
"""
import math
import struct
from pathlib import Path

MAP_NAME = "ARENA01"
MAIN_RADIUS = 1100     # vertex radius of the flat main floor (inside the tiers)
FLOOR_H, CEIL_H = 0, 448
WALL_TEX = "STONE2"
FLOOR_TEX = "FLOOR4_8"
CEIL_TEX = "F_SKY1"    # sky ceiling = open arena
LIGHT = 192

# Spectator tiers along the walls: depth of each tier (perpendicular to the
# wall), from the main floor outwards; the last one is the top walkway.
# STEP_H is the player's max step height, so the tiers can be walked up.
STEP_WIDTHS = [64] * 6 + [128]
STEP_H = 24
STEP_TEX = "MARBLE1"
STEP_FLAT = "FLAT5_4"

# Acid pool in the center
POOL_RADIUS = 192      # octagon vertex radius
POOL_DEPTH = 8
POOL_FLAT = "NUKAGE1"
POOL_EDGE_TEX = "NUKE24"
POOL_LIGHT = 224
POOL_DAMAGE, POOL_DAMAGE_INTERVAL = 5, 32   # classic nukage: 5 hp per 32 tics

# Pillars: (center x, center y, side). Keep the pool and the east path (y=0) to the switch clear.
PILLARS = [(-448, -448, 128), (-448, 448, 128), (448, -448, 128), (448, 448, 128),
           (0, -720, 96), (0, 720, 96), (-720, 0, 96)]
PILLAR_TEX = "SUPPORT3"

# Switch niche in the east wall
NICHE_W, NICHE_H, NICHE_D = 128, 128, 16
SWITCH_TEX = "SW1STON2"
NICHE_CEIL_TEX = "CEIL5_1"

# Switch wiring (must match ArenaHandler.SWITCH_LINE_ID in mod/zscript/arena.zs)
SWITCH_LINE_ID = 1
NICHE_TAG = 1
SPECIAL_LIGHT_CHANGE_TO_VALUE = 112  # Light_ChangeToValue(tag, value)

# Player start: this far in front of the switch, facing it (east)
PLAYER_DIST_FROM_SWITCH = 192
PLAYER_ANGLE = 0

# Doom editor numbers
ED_PLAYER1 = 1

OUT = Path(__file__).resolve().parent.parent / "mod" / "maps" / f"{MAP_NAME}.wad"

ALL_SKILLS = dict(skill1=True, skill2=True, skill3=True, skill4=True, skill5=True,
                  single=True, coop=True, dm=True)

COS_HALF = math.cos(math.radians(22.5))   # vertex radius -> wall distance
TIER_RADII = [MAIN_RADIUS]                # vertex radius of each tier's outer edge
for _w in STEP_WIDTHS:
    TIER_RADII.append(TIER_RADII[-1] + round(_w / COS_HALF))
RADIUS = TIER_RADII[-1]                   # outer wall


class MapBuilder:
    def __init__(self):
        self.vertices, self.lines, self.sides, self.sectors, self.things = [], [], [], [], []
        self._vidx = {}

    def vertex(self, x, y):
        key = (int(x), int(y))
        if key not in self._vidx:
            self._vidx[key] = len(self.vertices)
            self.vertices.append(key)
        return self._vidx[key]

    def sector(self, **fields):
        self.sectors.append(fields)
        return len(self.sectors) - 1

    def side(self, sector, **tex):
        self.sides.append(dict(sector=sector, **tex))
        return len(self.sides) - 1

    def line(self, a, b, front, back=None, **fields):
        """a -> b; the front side is on the right of the direction of travel."""
        ld = dict(v1=self.vertex(*a), v2=self.vertex(*b), sidefront=front, **fields)
        if back is None:
            ld["blocking"] = True
        else:
            ld["sideback"] = back
            ld["twosided"] = True
        self.lines.append(ld)

    def thing(self, **fields):
        self.things.append(fields)

    def textmap(self):
        out = ['namespace = "zdoom";\n']
        for x, y in self.vertices:
            out.append(block("vertex", x=float(x), y=float(y)))
        out += [block("linedef", **l) for l in self.lines]
        out += [block("sidedef", **s) for s in self.sides]
        out += [block("sector", **s) for s in self.sectors]
        out += [block("thing", **t) for t in self.things]
        return "".join(out).encode("ascii")


def block(kind, **fields):
    body = []
    for k, v in fields.items():
        if isinstance(v, bool):
            v = "true" if v else "false"
        elif isinstance(v, str):
            v = f'"{v}"'
        body.append(f"  {k} = {v};")
    return f"{kind}\n{{\n" + "\n".join(body) + "\n}\n"


def octagon(r):
    """Corners of an octagon with vertex radius r, clockwise from +22.5 deg."""
    pts = []
    for i in range(8):
        a = math.radians(22.5 - i * 45)
        pts.append((round(r * math.cos(a)), round(r * math.sin(a))))
    return pts


def build():
    m = MapBuilder()
    main = m.sector(heightfloor=FLOOR_H, heightceiling=CEIL_H,
                    texturefloor=FLOOR_TEX, textureceiling=CEIL_TEX, lightlevel=LIGHT)
    pool = m.sector(heightfloor=FLOOR_H - POOL_DEPTH, heightceiling=CEIL_H,
                    texturefloor=POOL_FLAT, textureceiling=CEIL_TEX, lightlevel=POOL_LIGHT,
                    damageamount=POOL_DAMAGE, damageinterval=POOL_DAMAGE_INTERVAL)

    # Tiers from the inside out; tier k sits between radii[k] and radii[k+1].
    radii = TIER_RADII
    tiers = [m.sector(heightfloor=FLOOR_H + STEP_H * (k + 1), heightceiling=CEIL_H,
                      texturefloor=STEP_FLAT, textureceiling=CEIL_TEX, lightlevel=LIGHT)
             for k in range(len(STEP_WIDTHS))]
    ledge = tiers[-1]
    ledge_h = FLOOR_H + STEP_H * len(STEP_WIDTHS)
    niche = m.sector(heightfloor=ledge_h, heightceiling=ledge_h + NICHE_H,
                     texturefloor=STEP_FLAT, textureceiling=NICHE_CEIL_TEX, lightlevel=LIGHT,
                     id=NICHE_TAG)

    # Acid pool edge: clockwise, so the front (right) side is the pool; the
    # pool side sees the main floor's step up as its lower texture.
    pc = octagon(POOL_RADIUS)
    for i in range(8):
        m.line(pc[i], pc[(i + 1) % 8], m.side(pool, texturebottom=POOL_EDGE_TEX), m.side(main))

    # Step risers: front = lower (inner) sector, which sees the riser.
    inner = [main] + tiers[:-1]
    for k, r in enumerate(radii[:-1]):
        c = octagon(r)
        for i in range(8):
            m.line(c[i], c[(i + 1) % 8], m.side(inner[k], texturebottom=STEP_TEX), m.side(tiers[k]))

    # Outer wall; the east edge (0) has the switch niche in the middle.
    corners = octagon(RADIUS)
    for i in range(8):
        a, b = corners[i], corners[(i + 1) % 8]
        if i != 0:
            m.line(a, b, m.side(ledge, texturemiddle=WALL_TEX))
            continue

        x = a[0]
        hw = NICHE_W // 2
        n_top, n_bot = (x, hw), (x, -hw)
        back_top, back_bot = (x + NICHE_D, hw), (x + NICHE_D, -hw)

        m.line(a, n_top, m.side(ledge, texturemiddle=WALL_TEX))
        # Opening into the niche: wall above it is the ledge side's upper texture.
        m.line(n_top, n_bot, m.side(ledge, texturetop=WALL_TEX), m.side(niche))
        m.line(n_bot, b, m.side(ledge, texturemiddle=WALL_TEX))

        # Niche walls (clockwise around the niche, front faces into it).
        m.line(n_top, back_top, m.side(niche, texturemiddle=WALL_TEX))
        m.line(back_top, back_bot, m.side(niche, texturemiddle=SWITCH_TEX),
               id=SWITCH_LINE_ID,
               special=SPECIAL_LIGHT_CHANGE_TO_VALUE, arg0=NICHE_TAG, arg1=LIGHT,
               playeruse=True, repeatspecial=True)
        m.line(back_bot, n_bot, m.side(niche, texturemiddle=WALL_TEX))

    # Pillars: one-sided lines around a hole in the main sector. Corners go
    # counterclockwise so the front (right) side faces out into the arena.
    for cx, cy, side in PILLARS:
        h = side // 2
        pts = [(cx - h, cy - h), (cx + h, cy - h), (cx + h, cy + h), (cx - h, cy + h)]
        for i in range(4):
            m.line(pts[i], pts[(i + 1) % 4], m.side(main, texturemiddle=PILLAR_TEX))

    switch_x = corners[0][0] + NICHE_D
    m.thing(x=float(switch_x - PLAYER_DIST_FROM_SWITCH), y=0.0, angle=PLAYER_ANGLE,
            type=ED_PLAYER1, **ALL_SKILLS)
    return m.textmap()


def write_wad(path, lumps):
    data = b""
    directory = []
    offset = 12
    for name, content in lumps:
        directory.append((offset, len(content), name))
        data += content
        offset += len(content)
    header = struct.pack("<4sii", b"PWAD", len(lumps), offset)
    dir_bytes = b"".join(struct.pack("<ii8s", o, s, n.encode("ascii")) for o, s, n in directory)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + data + dir_bytes)


if __name__ == "__main__":
    write_wad(OUT, [(MAP_NAME, b""), ("TEXTMAP", build()), ("ENDMAP", b"")])
    print(f"wrote {OUT}")
