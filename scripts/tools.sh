#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tools
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case "$arch" in x86_64) arch=amd64;; aarch64|arm64) arch=arm64;; *) echo "Unsupported architecture: $arch" >&2; exit 2;; esac
case "$os/$arch" in
  darwin/arm64) kind_sha=0c8c7dbe5e23594a198b786c4bc13dacc101fa6196b0cb0b23a1ca44e61f4b4f; kubectl_sha=fd65982c97ddad3106754b69ffa196d0e543aa591930ae52aed1adfb92f8c77f;;
  darwin/amd64) kind_sha=5a99f26f57246dc9319dd294803313197a0f34d33c525b3ea8b655db5916ece0; kubectl_sha=6851381c486ff6edd691623e3d65c87cb9a5b02887ff8fbbb38d8a031b748387;;
  linux/arm64) kind_sha=20022bee6cfcd5086cb7234d218e3454e6090022f2a8f55d1fa7fcf42c3867a2; kubectl_sha=ff749f4b78d9c4f1ec87307df9b50119ed819e2094aa9810cb9acffc3286c8c7;;
  linux/amd64) kind_sha=aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d; kubectl_sha=65691ff77eb6fa44c908b77a1082c9f092c3b9733b5cefabec0d1104890e21a8;;
  *) echo "Unsupported OS: $os" >&2; exit 2;;
esac
checksum() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
fetch() {
  local name=$1 url=$2 expected=$3 tmp
  tmp=$(mktemp .tools/.download.XXXXXX)
  trap 'rm -f "$tmp"' RETURN
  curl -fsSL "$url" -o "$tmp"
  [[ "$(checksum "$tmp")" == "$expected" ]] || { echo "Checksum mismatch for $name" >&2; exit 1; }
  chmod +x "$tmp"
  mv "$tmp" ".tools/$name"
  trap - RETURN
}
fetch kind "https://kind.sigs.k8s.io/dl/v0.33.0/kind-$os-$arch" "$kind_sha"
fetch kubectl "https://dl.k8s.io/release/v1.37.1/bin/$os/$arch/kubectl" "$kubectl_sha"
printf 'Verified kind v0.33.0 and kubectl v1.37.1 in .tools/\n'
