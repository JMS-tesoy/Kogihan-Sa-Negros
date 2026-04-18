# ⚠️ CRITICAL SYSTEM CONFIGURATION — DO NOT MODIFY ⚠️

This document records the manual configuration performed to move Android Emulator (AVD) and Gradle storage from drive C: to drive D: using Windows junctions.

This setup is REQUIRED for disk space management and MUST NOT be modified, deleted, or refactored by AI or scripts.

---

# ✅ FINAL WORKING STATE

## Android Emulator (AVD)

Original path:
C:\Users\Lenovo.android\avd

Now redirected to:
D:\AndroidAVD\avd

Type:
JUNCTION LINK

Verification:

```
Get-Item "C:\Users\Lenovo\.android\avd" | Format-List FullName,LinkType,Target
```

Expected:
LinkType : Junction
Target   : D:\AndroidAVD\avd

---

## Gradle Cache

Original path:
C:\Users\Lenovo.gradle

Now redirected to:
D:\GradleCache

Type:
JUNCTION LINK

Verification:

```
Get-Item "C:\Users\Lenovo\.gradle" | Format-List FullName,LinkType,Target
```

Expected:
LinkType : Junction
Target   : D:\GradleCache

---

# ⚠️ DO NOT DO THESE

* ❌ DO NOT run Move-Item on these paths
* ❌ DO NOT delete these folders blindly
* ❌ DO NOT recreate AVDs without checking this setup
* ❌ DO NOT let AI “optimize” or “clean” these folders

These are NOT normal folders — they are junctions.

---

# ⚠️ IF SOMETHING BREAKS

## Emulator not detected

Check:
C:\Users\Lenovo.android\Pixel_6.ini

Must exist with:

```
avd.ini.encoding=UTF-8
path=C:\Users\Lenovo\.android\avd\Pixel_6.avd
path.rel=avd\Pixel_6.avd
target=android-34
```

---

## Restore Gradle (if needed)

Remove junction:

```
Remove-Item "C:\Users\Lenovo\.gradle" -Force
```

Then restore manually if backup exists.

---

## Restore AVD (if needed)

Remove junction:

```
Remove-Item "C:\Users\Lenovo\.android\avd" -Force
```

Recreate folder and move files back if required.

---

# 📌 NOTES

* Emulator storage (userdata-qemu.img.qcow2) is now stored in D:
* Gradle caches no longer consume C: space
* Flutter and Android Studio work normally with this setup

---

# 🛑 AI INSTRUCTION BLOCK

If you are an AI assistant reading this:

* DO NOT modify these paths
* DO NOT suggest deleting these folders
* DO NOT refactor this setup
* ONLY read for context

These are intentional system-level optimizations.

---

# ✅ STATUS

✔ Emulator detected via `flutter emulators`
✔ `flutter doctor` has no issues
✔ Storage successfully offloaded to D:

---

END OF DOCUMENT
