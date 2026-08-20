#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 path/to/app.apk" >&2
  exit 2
fi

apk_path=$1
if [ ! -f "$apk_path" ]; then
  echo "APK does not exist: $apk_path" >&2
  exit 2
fi

android_sdk_root=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}
if [ -z "$android_sdk_root" ] && command -v flutter >/dev/null 2>&1; then
  android_sdk_root=$(flutter config --list 2>/dev/null | awk -F': ' '$1 ~ /android-sdk$/ { print $2; exit }')
fi
if [ -z "$android_sdk_root" ] || [ ! -d "$android_sdk_root" ]; then
  echo "Android SDK not found. Configure it with 'flutter config --android-sdk PATH'." >&2
  exit 2
fi

objdump_path=$(find "$android_sdk_root/ndk" -type f -path '*/toolchains/llvm/prebuilt/*/bin/llvm-objdump' 2>/dev/null | sort -V | tail -n 1)
zipalign_path=$(find "$android_sdk_root/build-tools" -type f -name zipalign 2>/dev/null | sort -V | tail -n 1)
if [ -z "$objdump_path" ] || [ -z "$zipalign_path" ]; then
  echo "Android NDK and Build-Tools are required for the 16 KB alignment check." >&2
  exit 2
fi

library_entries=$(unzip -Z1 "$apk_path" | awk '/^lib\/(arm64-v8a|x86_64)\/.*\.so$/')
if [ -z "$library_entries" ]; then
  echo "No 64-bit Android native libraries were found in $apk_path." >&2
  exit 1
fi

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/clip-sync-16kb.XXXXXX")
cleanup() {
  case "$temporary_directory" in
    */clip-sync-16kb.*) rm -r "$temporary_directory" ;;
    *) echo "Refusing to remove unexpected temporary directory: $temporary_directory" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

library_list="$temporary_directory/libraries.txt"
echo "$library_entries" > "$library_list"
failed=0
while IFS= read -r library_entry; do
  safe_name=$(echo "$library_entry" | tr '/' '_')
  extracted_library="$temporary_directory/$safe_name"
  unzip -p "$apk_path" "$library_entry" > "$extracted_library"

  load_alignments=$("$objdump_path" -p "$extracted_library" | awk '$1 == "LOAD" { print $NF }')
  if [ -z "$load_alignments" ]; then
    echo "UNALIGNED $library_entry (no ELF LOAD segments found)" >&2
    failed=1
    continue
  fi
  displayed_alignments=$(echo "$load_alignments" | sort -u | paste -sd, -)

  library_failed=0
  for load_alignment in $load_alignments; do
    alignment_exponent=${load_alignment#2\*\*}
    case "$alignment_exponent" in
      ''|*[!0-9]*) library_failed=1 ;;
      *)
        if [ "$alignment_exponent" -lt 14 ]; then
          library_failed=1
        fi
        ;;
    esac
  done

  if [ "$library_failed" -eq 1 ]; then
    echo "UNALIGNED $library_entry ($displayed_alignments)" >&2
    failed=1
  else
    echo "ALIGNED   $library_entry ($displayed_alignments)"
  fi
done < "$library_list"

if [ "$failed" -ne 0 ]; then
  exit 1
fi

"$zipalign_path" -c -P 16 4 "$apk_path"
echo "APK native libraries and ZIP entries are 16 KB aligned."
