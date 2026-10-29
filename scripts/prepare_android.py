"""Add native Android reminder/widget integration after `python3 scripts/generate_android.py`.

Idempotent; GitHub Actions runs this before flutter pub get/analyze/build.
"""
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
app = root / 'android/app/src/main'
manifest = app / 'AndroidManifest.xml'
if not manifest.is_file():
    raise RuntimeError('AndroidManifest.xml not found; run python3 scripts/generate_android.py first')

android_ns = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', android_ns)
a = lambda key: f'{{{android_ns}}}{key}'
xtree = ET.parse(manifest)
manifest_root = xtree.getroot()
for permission in ['android.permission.POST_NOTIFICATIONS', 'android.permission.RECEIVE_BOOT_COMPLETED', 'android.permission.SET_WALLPAPER', 'android.permission.INTERNET']:
    if not any(e.get(a('name')) == permission for e in manifest_root.findall('uses-permission')):
        manifest_root.insert(0, ET.Element('uses-permission', {a('name'): permission}))

application = manifest_root.find('application')
if application is None:
    raise RuntimeError('Missing application in generated AndroidManifest.xml')
application.set(a('label'), 'BetterSeed')
application.set(a('usesCleartextTraffic'), 'false')
# System-controlled Android Auto Backup (only Flutter's local progress prefs).
application.set(a('allowBackup'), 'true')
application.set(a('fullBackupContent'), '@xml/betterseed_backup_rules')
application.set(a('dataExtractionRules'), '@xml/betterseed_data_extraction_rules')
for receiver in list(application.findall('receiver')):
    if receiver.get(a('name')) in ['.ReminderReceiver', '.ReminderBootReceiver', '.BetterSeedWidget']:
        application.remove(receiver)

reminder = ET.SubElement(application, 'receiver', {
    a('name'): '.ReminderReceiver', a('enabled'): 'true', a('exported'): 'false'
})
boot = ET.SubElement(application, 'receiver', {
    a('name'): '.ReminderBootReceiver', a('enabled'): 'true', a('exported'): 'false'
})
boot_filter = ET.SubElement(boot, 'intent-filter')
for action in ['android.intent.action.BOOT_COMPLETED', 'android.intent.action.TIME_SET', 'android.intent.action.TIMEZONE_CHANGED']:
    ET.SubElement(boot_filter, 'action', {a('name'): action})
widget = ET.SubElement(application, 'receiver', {
    a('name'): '.BetterSeedWidget', a('enabled'): 'true', a('exported'): 'true'
})
widget_filter = ET.SubElement(widget, 'intent-filter')
ET.SubElement(widget_filter, 'action', {a('name'): 'android.appwidget.action.APPWIDGET_UPDATE'})
ET.SubElement(widget, 'meta-data', {
    a('name'): 'android.appwidget.provider', a('resource'): '@xml/betterseed_widget_info'
})

ET.indent(xtree, space='    ')
xtree.write(manifest, encoding='utf-8', xml_declaration=True)

# Copy legacy launcher icons AND adaptive-icon layers/XML.
# Android 8+ applies launcher-specific circular/squircle masks to foreground.
icon_root = root / 'assets/android_icons'
for icon in sorted(icon_root.rglob('*')):
    if not icon.is_file():
        continue
    target = app / 'res' / icon.relative_to(icon_root)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(icon, target)
application.set(a('icon'), '@mipmap/ic_launcher')
application.set(a('roundIcon'), '@mipmap/ic_launcher_round')
# The XML was already written above; persist manifest icon attributes too.
xtree.write(manifest, encoding='utf-8', xml_declaration=True)

native = root / 'native/android'
# Fail before writing an incomplete integration when native/android was ignored
# by an unanchored `android/` rule in a previous .gitignore.
required_kotlin = [
    'GardenWallpaper.kt', 'MainActivity.kt', 'ReminderScheduler.kt', 'ReminderReceiver.kt',
    'ReminderBootReceiver.kt', 'BetterSeedWidget.kt',
]
required_res = [
    'layout/betterseed_widget.xml', 'xml/betterseed_widget_info.xml',
    'drawable/widget_background.xml', 'drawable/ic_notification.xml',
    *[f'drawable-nodpi/widget_tree_{i}.webp' for i in range(6)],
    'drawable-nodpi/widget_preview.webp',
]
for file in [*(native / 'kotlin' / name for name in required_kotlin),
             *(native / 'res' / name for name in required_res)]:
    if not file.is_file():
        raise RuntimeError(
            f'Missing native Android file: {file}. Make sure native/android/ '
            'is committed; the .gitignore rule must be /android/, not android/.'
        )
for source in native.rglob('*'):
    if not source.is_file():
        continue
    relative = source.relative_to(native)
    if relative.parts[0] == 'kotlin':
        target = app / 'kotlin/com/betterseed/app' / relative.name
    elif relative.parts[0] == 'res':
        target = app / relative
    else:
        raise ValueError(f'Unexpected native asset {relative}')
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
print('Android reminder, widget, icons and permissions integrated successfully')
