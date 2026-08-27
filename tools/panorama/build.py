#!/usr/bin/env python3
"""Re-encode the official AON 360° photography into the app's panorama assets.

The originals are 8192x4096 equirectangular JPEGs (~10 MB each, ~180 MB in
total) that live outside the repo. Shipping them untouched would blow the app
download and risk a decode OOM on older phones, so this tool produces the
4096x2048 q85 progressive JPEGs the bundle actually carries — the same
resolution the first tour already shipped at.

WHICH PLACES ARE IN: the published AON 2026 Program and Map is the source of
truth. A scene ships only if its venue is one of the map legend's A-I event
locations. That rule is why the MQ Journey set contributes Macquarie Theatre,
Mason Theatre, 17 Wally's Walk and three extra 14 Sir scenes but NOT its two
dozen Open Day buildings (1 WW, 10 Hadenfield, 23/25/27/29 WW) — the AON map
puts no event in any of them. The Jim Piper Centre (12 Wally's Walk) panorama
is held out for the same reason: the map letters no activity there, and
inventing one is not ours to do.

Not reproducible from a clean checkout — the sources are 180 MB and are not
vendored. SOURCE_SHA256 pins exactly which file each scene came from, so a
swapped or re-shot original is detectable.

    python3 tools/panorama/build.py --verify   # check sources, encode nothing
    python3 tools/panorama/build.py            # encode into assets/data/indoor
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys

# tools/panorama/build.py -> tools/panorama -> tools -> repo root.
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(REPO, "assets", "data", "indoor")

ASTRONOMY = "/Users/raoof.r12/Desktop/D1/Astronomy_Assets"
JOURNEY = "/Users/raoof.r12/Desktop/D1/Journey_Assets/3D pictures"

WIDTH, HEIGHT, QUALITY = 4096, 2048, 85

# venue-id -> [(scene-id, human label, source dir, source filename)]
# Order is tour order: the scene rail renders it as written.
TOURS: dict[str, list[tuple[str, str, str, str]]] = {
    # A - Physics magic show and Keynote Lecture
    "macquarie-theatre": [
        ("entrance", "Entrance", JOURNEY, "MQ-theater-entrnce.jpg"),
        ("foyer", "Theatre foyer", JOURNEY, "21-WW-MQ-theatre.jpg"),
    ],
    # B - Chemistry magic show. The photo is the foyer OUTSIDE the auditorium,
    # so it is labelled as such rather than claiming to be inside.
    "mason-theatre": [
        ("foyer", "Foyer outside Mason Theatre", JOURNEY,
         "14-christopher-Mason-theatre.jpg"),
    ],
    # D - Short talks and exhibitors
    "14-sir-christopher-ondaatje-avenue": [
        ("entrance", "Entrance", JOURNEY, "14-christopher-entrence.jpg"),
        ("lobby", "Lobby", JOURNEY, "14-christofer-Lobby.jpg"),
        ("exhibition-hall", "Exhibition Hall", ASTRONOMY,
         "14 Sir - Exhibition Hall.JPG"),
        ("theatre-100-door-a", "Theatre 100, Door A", ASTRONOMY,
         "14 Sir - Theatre 100 Door A.JPG"),
        ("theatre-100-door-b", "Theatre 100, Door B", ASTRONOMY,
         "14 Sir - Theatre 100 Door B.JPG"),
        ("theatres-3-4", "Theatres 3 and 4", JOURNEY,
         "T3&T4-14-christopher.jpg"),
    ],
    # E - Kids' space and science demos
    "1-central-courtyard": [
        ("entrance", "Entrance", ASTRONOMY, "1 CC entrance.JPG"),
        ("stairs", "Stairs", ASTRONOMY, "1 CC - Stairs.JPG"),
        ("downstairs", "Downstairs", ASTRONOMY, "1 CC- Downstairs.JPG"),
        ("lounge-108", "Lounge 108", ASTRONOMY, "1 CC - Lounge 108.JPG"),
        ("room-101", "Room 101", ASTRONOMY, "1 CC- Room 101.JPG"),
        ("room-105", "Room 105", ASTRONOMY, "1 CC - Room 105.JPG"),
        ("room-106", "Room 106", ASTRONOMY, "1 CC- Room 106.JPG"),
        ("room-107", "Room 107", ASTRONOMY, "1 CC- Room 107.JPG"),
        ("room-109", "Room 109", ASTRONOMY, "1 CC - Room 109.JPG"),
        ("room-112", "Room 112", ASTRONOMY, "1 CC - Room 112.JPG"),
        ("room-114", "Room 114", ASTRONOMY, "1 CC- room 114.JPG"),
        ("room-115", "Room 115", ASTRONOMY, "1 CC- room 115.JPG"),
        ("room-116", "Room 116", ASTRONOMY, "1 CC- Room 116.JPG"),
    ],
    # F - Planetariums, Macquarie University Sport and Aquatic Centre
    "sport-and-aquatic-centre": [
        ("centre", "Sport and Aquatic Centre", ASTRONOMY,
         "Sport and Aquatic center.JPG"),
        ("planetarium-approach", "Before the planetarium", ASTRONOMY,
         "Platiymrum before Entrance.JPG"),
        ("planetarium-entrance", "Planetarium entrance", ASTRONOMY,
         "Planetarium Entrance Gym.JPG"),
    ],
    # H - Laser challenge
    "11-wallys-walk": [
        ("entrance", "Entrance", ASTRONOMY, "11 WW - Entrance.JPG"),
        ("room-150", "Room 150", ASTRONOMY,
         "11 WW -Room 150- Laser challenge game.JPG"),
        ("room-160", "Room 160", ASTRONOMY,
         "11 WW - Room 160 - Laser Challange .JPG"),
    ],
    # I - Astrophotography Exhibition
    "17-wallys-walk": [
        ("entrance", "Entrance", JOURNEY, "17-WW-entrnce.jpg"),
        ("lobby", "Lobby", JOURNEY, "17-WW-Lobby.jpg"),
        ("john-theatre-g02", "John Theatre G02", JOURNEY,
         "G02-John-theatre-17-WW.jpg"),
        ("t2-theatre-g25", "T2 Theatre G25", JOURNEY,
         "g25-t2-theatre-17-WW.jpg"),
    ],
}

# sha256 of each ORIGINAL, so a re-shot or swapped source is detectable even
# though the originals are too large to vendor.
SOURCE_SHA256 = {
    "MQ-theater-entrnce.jpg": "701988c7b027978fd90d92ade4c118fb2755b7b30ad2c7935d2147fe069ebcb8",
    "21-WW-MQ-theatre.jpg": "c08964982b6e6aa357c400241eabc068ed0745006c99f647210b61b719e44b75",
    "14-christopher-Mason-theatre.jpg": "d04d7c19959f90e73d55a44eac06a481fd27caa86d58c45c55955cd6fbac4beb",
    "14-christopher-entrence.jpg": "15551b7685ac3b851242c9c70a4c981dbe91d054f85235df8733b8dd1f82a192",
    "14-christofer-Lobby.jpg": "77e419f5135a0f9b5c9576a31d384789194d50f2b459a6f6f4e64c4eb8e014b6",
    "14 Sir - Exhibition Hall.JPG": "23400547aec95c9e540ec84d635a20be4e0505a9dd0652b824b1345c1fa3754c",
    "14 Sir - Theatre 100 Door A.JPG": "898e7e8a2d429e0cda1bcea2ebc676fcb4c609daa5657f5f703329f7c8babc3d",
    "14 Sir - Theatre 100 Door B.JPG": "9baf33bf34250eb45ec7e3dcc52dd579ab26f26f2000c5e72cae109fe545bd36",
    "T3&T4-14-christopher.jpg": "c72ef2113893528419fea21948522ed561c09f672db5784fb9b8c299a163bafb",
    "1 CC entrance.JPG": "b31061324b8ab9d1fc9f5804a1abfa8bcc0cff5004be5dd21b9fb7deb6da5636",
    "1 CC - Stairs.JPG": "e1bc59f92c105673f5a45a4994beff3d9f2e9b5d594757541a39f6aaf27afc2c",
    "1 CC- Downstairs.JPG": "b295f9d9b497998a4f5d7fc50dd8970e740eb7d0034a1f853ac23c90a79f1f5d",
    "1 CC - Lounge 108.JPG": "4559c6a1b0230eef867d150eef6e7aae8e38b10914651a99b60add822d358fac",
    "1 CC- Room 101.JPG": "c4e90038d0a33868940efbc2dce06df9e207d5aebfaedef8aff1facf0ca11121",
    "1 CC - Room 105.JPG": "a7846f84eea021ed29ebef74a0443251df2dbef58f85724468a73e25f32c0f41",
    "1 CC- Room 106.JPG": "33f0282bb40c76568a2fd5a4efd0dfbddff08fad31eafa7a9331c7c68ef90ed5",
    "1 CC- Room 107.JPG": "422040bfded88e683322d65812b9eb2dde75846200e23e650e874bec651e65cc",
    "1 CC - Room 109.JPG": "8805e3fecc24bbfe5ce3e745f014a95f7adf1be446e7b79ed0531deb67925ec4",
    "1 CC - Room 112.JPG": "3018ff8c6ccecb175e351251ec29c518dc3b2b0c79f3d8b8455731d0ecc7b867",
    "1 CC- room 114.JPG": "42bf69383c24660491433746888c0ef21f4e4ca5f0635b35cbd0f0e79ba81997",
    "1 CC- room 115.JPG": "7751aabeff53f4a6e3b6688751d776b7d8b596c4f805033c51cda243f1c02c6a",
    "1 CC- Room 116.JPG": "0c6ee812fa5c99089bf729f5fedeec35003f5a6f8d69052f1e6656407fa1038a",
    "Sport and Aquatic center.JPG": "d3b5f3e335678b0875830fcba3b766005ae0bb306b0557ba499a507f4c879ab3",
    "Platiymrum before Entrance.JPG": "d586af86af6c4e24ddc7dd6ba6a479e1cf8da3cfc7cbf129ce2fe7ad75a18289",
    "Planetarium Entrance Gym.JPG": "fb1f2c2f14f0d1f6abf89a1db38b5825d0c500bcd5c086059f54e43db8a9ee04",
    "11 WW - Entrance.JPG": "83f26eb48b8fb5ffcd8808a22c72ebd3c255d5a79c9da7218e017d65b9c21b14",
    "11 WW -Room 150- Laser challenge game.JPG": "fbdb07db877fa103aead500680fb24eccd6bcf230a83e7534884452982b9583d",
    "11 WW - Room 160 - Laser Challange .JPG": "f09c807c3eaaebe31f5298466b26654d83130e52a0eb9a5ebcacb1808dd41e5e",
    "17-WW-entrnce.jpg": "c59e49e0ebb7efbb9a1e23ac2c2787451b1ea10617f4518479d035bb407dd409",
    "17-WW-Lobby.jpg": "1839071216c4c910353d8904d662bf985104b63e0961949f9a78da9dc2959f2b",
    "G02-John-theatre-17-WW.jpg": "6899b6b2e5620a7a7451229527697b46204f958f3c9331a3b2119a292fb59b27",
    "g25-t2-theatre-17-WW.jpg": "66ee67502bb30928b6d4d4772b2406cc8ce26b9abf0df3f9f9a3388a44b6db2e",
}


def asset_name(venue_id: str, scene_id: str) -> str:
    return f"{venue_id}_{scene_id}.jpg"


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def sources() -> list[tuple[str, str, str, str]]:
    """(venue_id, scene_id, label, absolute source path) in tour order."""
    out = []
    for venue_id, scenes in TOURS.items():
        for scene_id, label, directory, filename in scenes:
            out.append((venue_id, scene_id, label,
                        os.path.join(directory, filename)))
    return out


def write_manifests() -> None:
    """Emit one manifest per venue, generated from TOURS so the JSON and the
    encoded files can never disagree.

    No `neighbours`: the originals carry no pose metadata (XMP has
    ProjectionType and nothing else), so there is no honest way to know which
    direction any scene faces. Rather than draw arrows at invented bearings,
    tours are navigated by the scene rail, which needs no direction at all.
    """
    for venue_id, scenes in TOURS.items():
        nodes = [
            {
                "id": scene_id,
                "image": f"indoor/{asset_name(venue_id, scene_id)}",
                "description": label,
                "neighbours": [],
            }
            for scene_id, label, _, _ in scenes
        ]
        path = os.path.join(OUT_DIR, f"{venue_id}.json")
        with open(path, "w", encoding="utf-8") as fh:
            json.dump({"nodes": nodes}, fh, indent=2, ensure_ascii=False)
            fh.write("\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", action="store_true",
                    help="check every source exists; encode nothing")
    ap.add_argument("--print-shas", action="store_true",
                    help="print source sha256s for SOURCE_SHA256")
    ap.add_argument("--manifests-only", action="store_true",
                    help="rewrite the manifests without re-encoding")
    args = ap.parse_args()

    missing = [p for _, _, _, p in sources() if not os.path.exists(p)]
    if missing:
        print("MISSING SOURCES:", file=sys.stderr)
        for p in missing:
            print(f"  {p}", file=sys.stderr)
        return 1

    if args.print_shas:
        for _, _, _, p in sources():
            print(f'    "{os.path.basename(p)}": "{sha256(p)}",')
        return 0

    if args.verify:
        print(f"{len(sources())} sources present")
        return 0

    if args.manifests_only:
        write_manifests()
        print(f"{len(TOURS)} manifests written to {OUT_DIR}")
        return 0

    from PIL import Image  # imported late so --verify needs no Pillow

    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0
    for venue_id, scene_id, _, src in sources():
        dst = os.path.join(OUT_DIR, asset_name(venue_id, scene_id))
        with Image.open(src) as im:
            if im.size != (8192, 4096):
                print(f"WARNING {src}: {im.size}, expected 8192x4096",
                      file=sys.stderr)
            im.resize((WIDTH, HEIGHT), Image.LANCZOS).save(
                dst, "JPEG", quality=QUALITY, optimize=True, progressive=True)
        size = os.path.getsize(dst)
        total += size
        print(f"{os.path.basename(dst):52} {size / 1e6:5.2f} MB")
    write_manifests()
    print(f"\n{len(sources())} scenes, {total / 1e6:.1f} MB, "
          f"{len(TOURS)} manifests")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
