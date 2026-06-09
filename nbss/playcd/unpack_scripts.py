"""Unpack a Cache export XML file into individual class and routine files."""

import xml.etree.ElementTree as ET
from pathlib import Path

EXPORT_FILE = Path(__file__).parent / "cache_scripts_export" / "all_files_export.xml"
OUTPUT_DIR = Path(__file__).parent / "cache_scripts_export"


def write_element(
    element: ET.Element, subtype: str, xml_header: str, counts: dict
) -> None:
    name = element.get("name")
    subdir = OUTPUT_DIR / subtype
    subdir.mkdir(exist_ok=True)
    filename = subdir / f"{name}.xml"
    with open(filename, "w", encoding="utf-8") as f:
        f.write(xml_header)
        f.write(ET.tostring(element, encoding="unicode"))
        f.write("\n</Export>\n")
    counts[subtype] = counts.get(subtype, 0) + 1


def main():
    tree = ET.parse(EXPORT_FILE)
    root = tree.getroot()

    export_attribs = " ".join(f'{k}="{v}"' for k, v in root.attrib.items())
    xml_header = f'<?xml version="1.0" encoding="UTF-8"?>\n<Export {export_attribs}>\n'

    counts = {"cls": 0, "mac": 0, "inc": 0}

    for cls in root.findall("Class"):
        write_element(cls, "cls", xml_header, counts)

    for routine in root.findall("Routine"):
        name = routine.get("name")
        raw_type = routine.get("type")
        if not raw_type:
            print(f"Warning: Routine '{name}' has no type attribute, skipping.")
            continue
        write_element(routine, raw_type.lower(), xml_header, counts)

    known = {"cls", "mac", "inc"}
    other = sum(v for k, v in counts.items() if k not in known)
    print(
        f"Extracted {counts['cls']} .cls, "
        f"{counts.get('mac', 0)} .mac, "
        f"{counts.get('inc', 0)} .inc, "
        f"{other} other files to {OUTPUT_DIR}"
    )


if __name__ == "__main__":
    main()
