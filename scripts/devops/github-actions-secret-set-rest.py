#!/usr/bin/env python3
"""
Set a GitHub Actions repository secret via the REST API.

Why this exists:
- Some operators prefer direct REST calls over the gh CLI.
- GitHub requires libsodium sealed-box encryption using the repo public key.

Dependencies:
- PyNaCl (libsodium bindings): pip install pynacl

Security notes:
- Avoid passing secret values via argv.
- Prefer --value-stdin or --value-env.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.request


def eprint(*a: object) -> None:
    print(*a, file=sys.stderr)


def require_env(name: str) -> str:
    v = os.environ.get(name, "")
    if not v:
        raise SystemExit(f"Missing env var: {name}")
    return v


def http_json(method: str, url: str, token: str, body: dict | None = None) -> tuple[int, dict]:
    data = None
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "auto-company-devops-secret-setter",
    }
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8") if resp.headers.get("Content-Type", "").startswith("application/json") else ""
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as ex:
        raw = ex.read().decode("utf-8", errors="replace")
        raise SystemExit(f"HTTP {ex.code} {method} {url}: {raw}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True, help="OWNER/REPO")
    ap.add_argument("--name", required=True, help="Secret name")

    vg = ap.add_mutually_exclusive_group(required=True)
    vg.add_argument("--value-env", help="Read secret value from this environment variable")
    vg.add_argument("--value-stdin", action="store_true", help="Read secret value from stdin")

    ap.add_argument("--token-env", default="GITHUB_TOKEN", help="Env var containing GitHub token (default: GITHUB_TOKEN)")

    args = ap.parse_args()

    token = require_env(args.token_env)
    owner_repo = args.repo
    name = args.name

    if args.value_env:
        value = require_env(args.value_env)
    else:
        value = sys.stdin.read()
        if value.endswith("\n"):
            value = value[:-1]
        if not value:
            raise SystemExit("Empty stdin; refusing to set empty secret value.")

    try:
        from nacl import encoding, public  # type: ignore
    except Exception:
        eprint("Missing dependency: PyNaCl")
        eprint("Install:")
        eprint("  python3 -m pip install --user pynacl")
        return 2

    api = "https://api.github.com"
    pk_url = f"{api}/repos/{owner_repo}/actions/secrets/public-key"
    status, pk = http_json("GET", pk_url, token)
    if status != 200 or "key" not in pk or "key_id" not in pk:
        raise SystemExit(f"Unexpected public-key response: HTTP {status} {pk}")

    public_key = public.PublicKey(pk["key"].encode("utf-8"), encoding.Base64Encoder())
    sealed_box = public.SealedBox(public_key)
    encrypted = sealed_box.encrypt(value.encode("utf-8"))
    encrypted_b64 = base64.b64encode(encrypted).decode("utf-8")

    put_url = f"{api}/repos/{owner_repo}/actions/secrets/{name}"
    put_body = {"encrypted_value": encrypted_b64, "key_id": pk["key_id"]}
    put_status, _ = http_json("PUT", put_url, token, put_body)
    if put_status not in (201, 204):
        raise SystemExit(f"Unexpected PUT status: {put_status}")

    eprint(f"Set secret (name only): {name} repo={owner_repo}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

