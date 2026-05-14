"""Unpack a Cache export XML file into individual class and routine files."""

import xml.etree.ElementTree as ET
from pathlib import Path

EXPORT_FILE = Path(__file__).parent / "cache_export" / "all_files_export.xml"
OUTPUT_DIR = Path(__file__).parent / "cache_export"


def main():
    tree = ET.parse(EXPORT_FILE)
    root = tree.getroot()

    export_attribs = " ".join(f'{k}="{v}"' for k, v in root.attrib.items())
    xml_header = f'<?xml version="1.0" encoding="UTF-8"?>\n<Export {export_attribs}>\n'

    counts = {"cls": 0, "mac": 0, "inc": 0}

    for cls in root.findall("Class"):
        name = cls.get("name")
        if not name:
            continue
        subdir = OUTPUT_DIR / "cls"
        subdir.mkdir(exist_ok=True)
        filename = subdir / f"{name}.xml"
        class_xml = ET.tostring(cls, encoding="unicode")
        with open(filename, "w", encoding="utf-8") as f:
            f.write(xml_header)
            f.write(class_xml)
            f.write("\n</Export>\n")
        counts["cls"] += 1

    for routine in root.findall("Routine"):
        name = routine.get("name")
        rtype = routine.get("type", "MAC").lower()
        if not name:
            continue
        subdir = OUTPUT_DIR / rtype
        subdir.mkdir(exist_ok=True)
        filename = subdir / f"{name}.xml"
        routine_xml = ET.tostring(routine, encoding="unicode")
        with open(filename, "w", encoding="utf-8") as f:
            f.write(xml_header)
            f.write(routine_xml)
            f.write("\n</Export>\n")
        counts[rtype] = counts.get(rtype, 0) + 1

    print(
        f"Extracted {counts['cls']} .cls, "
        f"{counts.get('mac', 0)} .mac, "
        f"{counts.get('inc', 0)} .inc files to {OUTPUT_DIR}"
    )


if __name__ == "__main__":
    main()
