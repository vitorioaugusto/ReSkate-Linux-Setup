#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    print("Uso: embed.py INPUT OUTPUT", file=sys.stderr)
    raise SystemExit(1)

input_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
data = input_path.read_bytes()

with output_path.open("w", encoding="utf-8") as out:
    out.write("#ifndef RESKATE_EMBEDDED_SETUP_H\n")
    out.write("#define RESKATE_EMBEDDED_SETUP_H\n\n")
    out.write("static const unsigned char embedded_setup[] = {\n")
    for i in range(0, len(data), 16):
        chunk = data[i:i + 16]
        out.write("    " + ", ".join(str(b) for b in chunk) + ",\n")
    out.write("};\n\n")
    out.write("static const unsigned long embedded_setup_len = sizeof(embedded_setup);\n\n")
    out.write("#endif\n")
