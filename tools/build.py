"""Arma la carpeta Resources/ lista para copiar a la raíz de un servidor BeamMP.

Uso: python tools/build.py  ->  genera dist/Resources/{Client/CareerMP.zip, Server/CareerMP/}
"""
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist" / "Resources"


def main() -> None:
    if DIST.exists():
        shutil.rmtree(DIST)
    client_zip = DIST / "Client" / "CareerMP.zip"
    client_zip.parent.mkdir(parents=True)
    client_dir = ROOT / "client"
    with zipfile.ZipFile(client_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in sorted(client_dir.rglob("*")):
            if f.is_file():
                zf.write(f, f.relative_to(client_dir).as_posix())
    shutil.copytree(ROOT / "server" / "CareerMP", DIST / "Server" / "CareerMP",
                    ignore=shutil.ignore_patterns("config"))
    print(f"Listo: {DIST}")


if __name__ == "__main__":
    main()
