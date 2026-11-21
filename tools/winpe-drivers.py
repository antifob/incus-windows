#!/usr/bin/env python3
#
# Stage WinPE drivers on the repacked ISO before Windows Setup partitions the disk.
#

import shutil
import sys
import xml.etree.ElementTree as ET

from pathlib import Path


NS = {'u': 'urn:schemas-microsoft-com:unattend'}
PE_PATHS = ("u:settings[@pass='windowsPE']/"
            "u:component[@name='Microsoft-Windows-PnpCustomizationsWinPE']/u:DriverPaths")


def has_marked_entries(xml):
    marked = False
    for node in xml.iter():
        if node.tag is ET.Comment:
            marker = node.text.strip()
            if marker in ('VIOSOCK_BEGIN', 'VIOSOCK_END'):
                marked = marker == 'VIOSOCK_BEGIN'
        elif marked:
            return True
    return False


def stage_drivers(answer, default, media):
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    xml = ET.parse(answer, parser)
    has_viosock = (media / 'viosock').is_dir()
    manifest = answer.with_suffix('.drivers')
    if not has_viosock and has_marked_entries(xml):
        raise ValueError(f'{answer}: this virtio ISO has no viosock directory. '
                         'VIOSOCK_BEGIN/VIOSOCK_END blocks are no longer stripped. '
                         'Remove the marked XML entry; to keep it optional, list its '
                         f'ISO-relative directory in {manifest}.')

    if not manifest.exists() and not manifest.is_symlink():
        if xml.find(PE_PATHS, NS) is not None:
            print('[+] Using WinPE DriverPaths from', answer)
            return
        manifest = default

    print('[+] WinPE driver list:', manifest)
    dest = media / '$WinPEDriver$'
    for n, line in enumerate(manifest.read_text(encoding='utf-8-sig').splitlines(), 1):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        path = Path(line)
        if not path.parts or path.is_absolute() or '..' in path.parts or path.parts[0] == dest.name:
            raise ValueError(f'{manifest}:{n}: invalid ISO-relative driver directory: {line}')
        if path.parts[0] == 'viosock' and not has_viosock:
            continue  # Older virtio ISOs do not ship viosock.
        source = media / path
        if media.resolve() not in source.resolve().parents:
            raise ValueError(f'{manifest}:{n}: driver directory outside ISO: {line}')
        shutil.copytree(source, dest / path, symlinks=True)


if __name__ == '__main__':
    try:
        stage_drivers(*map(Path, sys.argv[1:]))
    except (ET.ParseError, OSError, ValueError) as exc:
        sys.exit(f'WinPE drivers: {exc}')
