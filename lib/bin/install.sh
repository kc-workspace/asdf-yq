#!/usr/bin/env bash

kc_asdf_load_addon "install" \
  "system"

__asdf_bin() {
  # shellcheck disable=SC2034
  local ns="$1"
  shift

  local type="${ASDF_INSTALL_TYPE:?}"
  local version="${ASDF_INSTALL_VERSION:?}"
  local indir="${ASDF_DOWNLOAD_PATH:?}"
  local outdir="${ASDF_INSTALL_PATH:?}"
  # shellcheck disable=SC2034
  local concurrency="${ASDF_CONCURRENCY:-1}"
  kc_asdf_debug "$ns" "installing %s %s %s" \
    "$KC_ASDF_APP_NAME" "$type" "$version"
  kc_asdf_debug "$ns" "download location is %s" "$indir"
  kc_asdf_debug "$ns" "install location is %s" "$outdir"

  if kc_asdf_is_ref; then
    kc_asdf_error "$ns" "reference mode is not support by current plugin"
    return 1
  elif kc_asdf_is_ver; then
    kc_asdf_step "install" "$outdir" \
      kc_asdf_transfer 'copy' "$indir" "$outdir" ||
      return 1
    ## Transfer files recording install mapping
    local install_map
    install_map=(
      "yq:bin/yq"
    )
    local vars=("version=$version")
    [ -n "${KC_ASDF_OS:-}" ] && vars+=("os=$KC_ASDF_OS")
    [ -n "${KC_ASDF_ARCH:-}" ] && vars+=("arch=$KC_ASDF_ARCH")
    [ -n "${KC_ASDF_EXT:-}" ] && vars+=("ext=$KC_ASDF_EXT")
    if command -v kc_asdf_version_parser >/dev/null; then
      local major minor patch
      read -r major minor patch <<<"$(kc_asdf_version_parser "$version")"
      vars+=("major_version=$major" "minor_version=$minor" "patch_version=$patch")
    fi
    kc_asdf_debug "$ns" "template variables are '%s'" "${vars[*]}"

    local transfer_method="move"
    local raw key value
    for raw in "${install_map[@]}"; do
      key="$(kc_asdf_template "${raw%%:*}" "${vars[@]}")"
      value="$(kc_asdf_template "${raw##*:}" "${vars[@]}")"
      kc_asdf_step "$transfer_method" "$key -> $value" \
        kc_asdf_transfer "$transfer_method" "$outdir/$key" "$outdir/$value"
    done
  fi
  ## Chmod all bin files
  local bin bins=(bin)
  local file outpath
  for bin in "${bins[@]}"; do
    outpath="$outdir/$bin"
    [ -d "$outpath" ] ||
      continue

    kc_asdf_debug "$ns" "running chmod all files in %s" \
      "$outpath"
    for file in "$outpath"/*; do
      [ -f "$file" ] &&
        kc_asdf_exec chmod +x "$file"
    done
  done

  # shellcheck disable=SC2011
  kc_asdf_debug "$ns" "list '%s': [%s]" \
    "$outdir" "$(ls "$outdir" | xargs echo)"
  for bin in "${bins[@]}"; do
    outpath="$outdir/$bin"
    if kc_asdf_present_dir "$outpath"; then
      # shellcheck disable=SC2011
      kc_asdf_debug "$ns" "list '%s': [%s]" \
        "$bin" "$(ls "$outpath" | xargs echo)"
    else
      kc_asdf_error "$ns" "%s contains no executable file" \
        "$outpath"
      return 1
    fi
  done
}
