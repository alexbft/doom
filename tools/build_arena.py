#!/usr/bin/env python3
"""Generate mod/maps/ARENA01.wad: an octagonal open-sky arena (UDMF).

Layout:
  * square pillars (holes in the arena sector) give some cover;
  * a switch sits in a small niche in the middle of the east wall;
  * player starts a few steps in front of it, facing the switch;
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
RADIUS = 1024          # distance from center to the octagon's vertices
FLOOR_H, CEIL_H = 0, 256
WALL_TEX = "STONE2"
FLOOR_TEX = "FLOOR4_8"
CEIL_TEX = "F_SKY1"    # sky ceiling = open arena
LIGHT = 192

# Pillars: (center x, center y, side). Keep the east path (y=0) to the switch
# and the arena center (weapon spawn) clear.
PILLARS = [(-384, -384, 128), (-384, 384, 128), (384, -384, 128), (384, 384, 128),
           (0, -640, 96), (0, 640, 96), (-640, 0, 96)]
PILLAR_TEX = "SUPPORT3"

# Switch niche in the east wall
NICHE_W, NICHE_H, NICHE_D = 128, 128, 16
SWITCH_TEX = "SW1STON2"
NICHE_CEIL_TEX = "CEIL5_1"

# Switch wiring (must match ArenaHandler.SWITCH_LINE_ID in mod/zscript/arena.zs)
SWITCH_LINE_ID = 1
NICHE_TAG = 1
SPECIAL_LIGHT_CHANGE_TO_VALUE = 112  # Light_ChangeToValue(tag, value)

# Player start: just in front of the switch, facing it (east)
PLAYER_START = (768, 0)
PLAYER_ANGLE = 0

# Doom editor numbers
ED_PLAYER1 = 1

OUT = Path(__file__).resolve().parent.parent / "mod" / "maps" / f"{MAP_NAME}.wad"

ALL_SKILLS = dict(skill1=True, skill2=True, skill3=True, skill4=True, skill5=True,
                  single=True, coop=True, dm=True)


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


def build():
    m = MapBuilder()
    arena = m.sector(heightfloor=FLOOR_H, heightceiling=CEIL_H,
                     texturefloor=FLOOR_TEX, textureceiling=CEIL_TEX, lightlevel=LIGHT)
    niche = m.sector(heightfloor=FLOOR_H, heightceiling=FLOOR_H + NICHE_H,
                     texturefloor=FLOOR_TEX, textureceiling=NICHE_CEIL_TEX, lightlevel=LIGHT,
                     id=NICHE_TAG)

    # Octagon corners, clockwise; corner 0 is at +22.5 deg so edge 0 is the
    # flat east wall running from north to south.
    corners = []
    for i in range(8):
        a = math.radians(22.5 - i * 45)
        corners.append((round(RADIUS * math.cos(a)), round(RADIUS * math.sin(a))))

    for i in range(8):
        a, b = corners[i], corners[(i + 1) % 8]
        if i != 0:
            m.line(a, b, m.side(arena, texturemiddle=WALL_TEX))
            continue

        # East wall with the switch niche in the middle.
        x = a[0]
        hw = NICHE_W // 2
        n_top, n_bot = (x, hw), (x, -hw)
        back_top, back_bot = (x + NICHE_D, hw), (x + NICHE_D, -hw)

        m.line(a, n_top, m.side(arena, texturemiddle=WALL_TEX))
        # Opening into the niche: wall above it is the arena side's upper texture.
        m.line(n_top, n_bot, m.side(arena, texturetop=WALL_TEX), m.side(niche))
        m.line(n_bot, b, m.side(arena, texturemiddle=WALL_TEX))

        # Niche walls (clockwise around the niche, front faces into it).
        m.line(n_top, back_top, m.side(niche, texturemiddle=WALL_TEX))
        m.line(back_top, back_bot, m.side(niche, texturemiddle=SWITCH_TEX),
               id=SWITCH_LINE_ID,
               special=SPECIAL_LIGHT_CHANGE_TO_VALUE, arg0=NICHE_TAG, arg1=LIGHT,
               playeruse=True, repeatspecial=True)
        m.line(back_bot, n_bot, m.side(niche, texturemiddle=WALL_TEX))

    # Pillars: one-sided lines around a hole in the arena sector. Corners go
    # counterclockwise so the front (right) side faces out into the arena.
    for cx, cy, side in PILLARS:
        h = side // 2
        pts = [(cx - h, cy - h), (cx + h, cy - h), (cx + h, cy + h), (cx - h, cy + h)]
        for i in range(4):
            m.line(pts[i], pts[(i + 1) % 4], m.side(arena, texturemiddle=PILLAR_TEX))

    m.thing(x=float(PLAYER_START[0]), y=float(PLAYER_START[1]), angle=PLAYER_ANGLE, type=ED_PLAYER1, **ALL_SKILLS)
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
