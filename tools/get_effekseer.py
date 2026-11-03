"""Downloads the Effekseer for Godot 4 plugin (latest release, MIT) into ./addons/effekseer.
Run by the CI before `godot --import` on the experiment branch. The binaries are NOT committed to the repo."""
import json
import os
import shutil
import urllib.request
import zipfile

api = "https://api.github.com/repos/effekseer/EffekseerForGodot4/releases"
rel = json.loads(urllib.request.urlopen(api).read())[0]
url = rel["assets"][0]["browser_download_url"]
print("Effekseer release:", rel["tag_name"], url)
pkg, _ = urllib.request.urlretrieve(url)
if os.path.isdir("addons/effekseer"):
    shutil.rmtree("addons/effekseer")
with zipfile.ZipFile(pkg) as z:
    for f in z.infolist():
        if "addons/" not in f.filename:
            continue
        dest = f.filename[f.filename.index("addons/"):]
        if f.filename.endswith("/"):
            os.makedirs(dest, exist_ok=True)
        else:
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "wb") as o:
                o.write(z.read(f))
print("platform libs:", sorted(os.listdir("addons/effekseer/bin")) if os.path.isdir("addons/effekseer/bin") else "none")
