#!/usr/bin/env bash
set -u
major=$(awk '/nvidia-caps/{print $1}' /proc/devices)
mkdir -p /dev/nvidia-caps
if [ -n "${major:-}" ] && [ -d /proc/driver/nvidia/capabilities ]; then
  find /proc/driver/nvidia/capabilities -type f | while read -r f; do
    minor=$(awk -F': *' '/DeviceFileMinor/{print $2}' "$f")
    mode=$(awk  -F': *' '/DeviceFileMode/{print $2}'  "$f")
    [ -n "$minor" ] || continue
    n=/dev/nvidia-caps/nvidia-cap$minor
    [ -e "$n" ] || { mknod "$n" c "$major" "$minor"; [ -n "$mode" ] && chmod "$(printf '%o' "$mode")" "$n"; }
  done
fi

mkdir -p /etc/vulkan/icd.d /etc/vulkan/implicit_layer.d
icd=$(find /usr/share /usr/lib -name nvidia_icd.json 2>/dev/null | head -1)
lay=$(find /usr/share /usr/lib -name nvidia_layers.json 2>/dev/null | head -1)
[ -n "$icd" ] && ln -sf "$icd" /etc/vulkan/icd.d/nvidia_icd.json
[ -n "$lay" ] && ln -sf "$lay" /etc/vulkan/implicit_layer.d/nvidia_layers.json

mkdir -p /etc/cdi
nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml \
  --device-name-strategy=index --device-name-strategy=uuid
