"""
Script de vérification des DLLs pyzbar pour PyInstaller
Vérifie que toutes les dépendances natives sont présentes avant le build
"""
import sys
from pathlib import Path

def find_pyzbar_dlls():
    """Trouve le chemin des DLLs pyzbar dans l'environnement Python"""
    print("🔍 Recherche des DLLs pyzbar...\n")
    
    pyzbar_path = None
    for path_str in sys.path:
        potential_path = Path(path_str) / 'pyzbar'
        if potential_path.exists():
            pyzbar_path = potential_path
            print(f"✓ Dossier pyzbar trouvé: {pyzbar_path}\n")
            break
    
    if not pyzbar_path:
        print("❌ Dossier pyzbar introuvable dans sys.path")
        print("\nVérifiez que pyzbar est bien installé:")
        print("  pip install pyzbar\n")
        return False
    
    # Vérifier les DLLs nécessaires
    required_dlls = {
        'libiconv.dll': False,
        'libzbar-64.dll': False,
        'libzbar.dll': False,
    }
    
    print("Vérification des DLLs natives:\n")
    for dll_name in required_dlls.keys():
        dll_path = pyzbar_path / dll_name
        if dll_path.exists():
            required_dlls[dll_name] = True
            print(f"  ✓ {dll_name}")
        else:
            print(f"  ❌ {dll_name} - MANQUANT")
    
    print()
    
    # Au moins une version de libzbar doit être présente
    has_libzbar = required_dlls['libzbar-64.dll'] or required_dlls['libzbar.dll']
    has_libiconv = required_dlls['libiconv.dll']
    
    if not has_libiconv:
        print("❌ libiconv.dll est REQUIS mais manquant")
        print("\nSolution:")
        print("  1. Réinstallez pyzbar: pip uninstall pyzbar && pip install pyzbar")
        print("  2. Ou téléchargez les DLLs depuis: https://github.com/NaturalHistoryMuseum/pyzbar#installation")
        print(f"  3. Placez-les dans: {pyzbar_path}\n")
        return False
    
    if not has_libzbar:
        print("❌ libzbar.dll ou libzbar-64.dll est REQUIS mais manquant")
        print("\nSolution: (voir instructions ci-dessus)\n")
        return False
    
    print("✅ Toutes les DLLs nécessaires sont présentes!")
    print(f"\nChemin pyzbar: {pyzbar_path}")
    print("\n📦 PyInstaller pourra inclure ces DLLs dans l'exécutable.\n")
    return True

if __name__ == "__main__":
    success = find_pyzbar_dlls()
    sys.exit(0 if success else 1)
