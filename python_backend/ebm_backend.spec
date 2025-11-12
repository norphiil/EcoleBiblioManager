# -*- mode: python ; coding: utf-8 -*-
import os
import sys
from pathlib import Path

# Trouver le chemin des DLLs de pyzbar
pyzbar_path = None
for path in sys.path:
    potential_path = Path(path) / 'pyzbar'
    if potential_path.exists():
        pyzbar_path = potential_path
        break

# Collecter les DLLs de pyzbar
pyzbar_binaries = []
if pyzbar_path:
    dll_files = ['libiconv.dll', 'libzbar-64.dll', 'libzbar.dll']
    for dll in dll_files:
        dll_path = pyzbar_path / dll
        if dll_path.exists():
            pyzbar_binaries.append((str(dll_path), 'pyzbar'))
            print(f'✓ Trouvé: {dll}')
        else:
            print(f'⚠ Non trouvé: {dll}')

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=pyzbar_binaries,
    datas=[('requirements.txt', '.')],
    hiddenimports=['cv2', 'PIL', 'pyzbar', 'numpy'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='ebm_backend',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
