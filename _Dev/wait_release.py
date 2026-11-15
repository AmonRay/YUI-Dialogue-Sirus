import json
import subprocess
import time
import urllib.request

REPO = "AmonRay/YUI-Dialogue-Sirus"
TARGET = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True).strip()
DEADLINE = time.time() + 540


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "dui-release-check"})
    with urllib.request.urlopen(request) as response:
        return json.load(response)


print("waiting for release built from", TARGET)

while time.time() < DEADLINE:
    try:
        release = get("https://api.github.com/repos/%s/releases/tags/v1.0.9" % REPO)
    except Exception:
        time.sleep(20)
        continue

    if release["target_commitish"].startswith(TARGET):
        body = release.get("body") or ""
        print("published:", release["published_at"], "| target:", release["target_commitish"][:7])
        for name, value in {
            "any client window": "любое окно клиента" in body,
            "camera once": "двойного отъезда" in body,
            "transmog": "трансмогрификации" in body,
        }.items():
            print("%-20s %s" % (name + ":", value))
        for asset in release["assets"]:
            print("asset:", asset["name"], asset["size"], "bytes")
        break

    time.sleep(20)
else:
    print("timed out")
