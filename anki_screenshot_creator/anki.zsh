anki() {
  local mode="${1}"
  if [[ -z "$mode" ]]; then
    read "mode?Anki mode: "
  fi
  python ~/anki_watcher.py --mode "$mode"
}
