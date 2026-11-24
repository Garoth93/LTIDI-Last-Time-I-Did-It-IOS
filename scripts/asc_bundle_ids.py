#!/usr/bin/env python3
"""App ID diagnostics for testflight.yml.

For each bundle id: prints the enabled capabilities and the existing
provisioning profiles with their App Groups / iCloud containers. With
--delete-stale, deletes the profiles that miss the expected App Group
(--group) or iCloud container (--icloud), e.g. generated before the
capability was configured on developer.apple.com: Xcode's automatic
signing then creates fresh ones.

Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH.
Usage: asc_bundle_ids.py [--delete-stale] [--group <app group>] [--icloud <container>] <bundle id>...
"""
import base64
import plistlib
import sys
import urllib.parse

from asc_revoke_certs import call

VALUE_OPTIONS = ("--group", "--icloud")


def profile_entitlements(p):
    raw = base64.b64decode(p["attributes"].get("profileContent") or "")
    start, end = raw.find(b"<?xml"), raw.rfind(b"</plist>")
    if start < 0 or end < 0:
        return {}
    return plistlib.loads(raw[start:end + len(b"</plist>")]).get("Entitlements", {})


def option(args, name):
    return args[args.index(name) + 1] if name in args else None


def main(args):
    delete = "--delete-stale" in args
    group = option(args, "--group")
    icloud = option(args, "--icloud")
    ids = [a for i, a in enumerate(args) if not a.startswith("--") and (i == 0 or args[i - 1] not in VALUE_OPTIONS)]
    for ident in ids:
        q = urllib.parse.urlencode({"filter[identifier]": ident, "include": "bundleIdCapabilities", "limit": 20})
        r = call("GET", f"/bundleIds?{q}")
        match = [b for b in r.get("data", []) if b["attributes"]["identifier"] == ident]
        if not match:
            print(f"::warning::App ID {ident} non registrato (lo crea la firma automatica)")
            continue
        caps = sorted({i["attributes"]["capabilityType"] for i in r.get("included", []) if i["type"] == "bundleIdCapabilities"})
        print(f"{ident}: capability {', '.join(caps) or 'nessuna'}")
        if icloud and "ICLOUD" not in caps:
            print(f"::warning::{ident}: iCloud non attivo sull'App ID (developer.apple.com, Identifiers)")
        profiles = call("GET", f"/bundleIds/{match[0]['id']}/profiles?limit=50").get("data", [])
        for p in profiles:
            a = p["attributes"]
            ent = profile_entitlements(p)
            groups = ent.get("com.apple.security.application-groups", [])
            containers = ent.get("com.apple.developer.icloud-container-identifiers", [])
            print(f"  profilo «{a.get('name')}» ({a.get('profileType')}, {a.get('profileState')}, creato {a.get('createdDate')}): "
                  f"gruppi {groups or '—'}, iCloud {containers or '—'}")
            missing = [x for x, have in ((group, groups), (icloud, containers)) if x and x not in have]
            if delete and missing:
                try:
                    call("DELETE", f"/profiles/{p['id']}")
                    print(f"  → eliminato (senza {', '.join(missing)}): Xcode ne crea uno nuovo")
                except Exception as e:  # noqa: BLE001
                    print(f"::warning::Non riesco a eliminare «{a.get('name')}»: {e}")


if __name__ == "__main__":
    main(sys.argv[1:])
