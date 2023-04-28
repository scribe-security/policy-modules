#!/bin/sh

is_command() {
  command -v "$1" >/dev/null
}

http_download_curl() {
  local_file=$1
  source_url=$2
  header=$3
  if [ -z "$header" ]; then
    code=$(curl -w '%{http_code}' -L -o "$local_file" "$source_url")
  else
    code=$(curl -w '%{http_code}' -L -H "$header" -o "$local_file" "$source_url")
  fi
  if [ "$code" != "200" ]; then
    log_debug "http_download_curl received HTTP status $code"
    return 1
  fi
  return 0
}

http_download_wget() {
  local_file=$1
  source_url=$2
  header=$3
  if [ -z "$header" ]; then
    wget -q -O "$local_file" "$source_url"
  else
    wget -q --header "$header" -O "$local_file" "$source_url"
  fi
}

http_download() {
  log_debug "http_download $2"
  if is_command curl; then
    http_download_curl "$@"
    return
  elif is_command wget; then
    http_download_wget "$@"
    return
  fi
  log_crit "http_download unable to find wget or curl"
  return 1
}

echoerr() {
  echo "$@" 1>&2
}

log_prefix() {
  echo "scribe"
}

_logp=6

log_set_priority() {
  _logp="$1"
}

log_priority() {
  if test -z "$1"; then
    echo "$_logp"
    return
  fi
  [ "$1" -le "$_logp" ]
}

log_tag() {
  case $1 in
    0) echo "emerg" ;;
    1) echo "alert" ;;
    2) echo "crit" ;;
    3) echo "err" ;;
    4) echo "warning" ;;
    5) echo "notice" ;;
    6) echo "info" ;;
    7) echo "debug" ;;
    *) echo "$1" ;;
  esac
}

log_debug() {
  log_priority 7 || return 0
  echoerr "$(log_prefix)" "$(log_tag 7)" "$@"
}

log_info() {
  log_priority 6 || return 0
  echoerr "$(log_prefix)" "$(log_tag 6)" "$@"
}

log_err() {
  log_priority 3 || return 0
  echoerr "$(log_prefix)" "$(log_tag 3)" "$@"
}

log_crit() {
  log_priority 2 || return 0
  echoerr "$(log_prefix)" "$(log_tag 2)" "$@"
}

# asset_file_exists [path]
#
# returns 1 if the given file does not exist
#
asset_file_exists() (
  path="$1"
  if [ ! -f "${path}" ]; then
      return 1
  fi
)

# search_for_asset [checksums-file-path] [name] [os] [arch] [format]
#
# outputs name of the asset to download
#
search_for_asset() (
  checksum_path="$1"
  name="$2"
  os="$3"
  arch="$4"
  format="$5"

  log_debug "search_for_asset(checksum-path=${checksum_path}, name=${name}, os=${os}, arch=${arch}, format=${format})"

  asset_glob="${name}_.*_${os}_${arch}.${format}"
  output_path=$(grep -o "${asset_glob}" "${checksum_path}" || true)

  log_debug "search_for_asset() returned '${output_path}'"

  echo "${output_path}"
)


# github_release_json [owner] [repo] [version]
#
# outputs release json string
#
github_release_json() (
  owner=$1
  repo=$2
  version=$3
  test -z "$version" && version="latest"
  giturl="https://github.com/${owner}/${repo}/releases/${version}"
  json=$(http_copy "$giturl" "Accept:application/json")
  log_info "Pulling, Url=${giturl}'"
  log_debug "github_release_json(owner=${owner}, repo=${repo}, version=${version}) returned '${json}'"

  test -z "$json" && return 1
  echo "${json}"
)

http_copy() (
  tmp=$(mktemp)
  http_download "${tmp}" "$1" "$2" || return 1
  body=$(cat "$tmp")
  rm -f "${tmp}"
  echo "$body"
)

# extract_value [key-value-pair]
#
# outputs value from a colon delimited key-value pair
#
extract_value() (
  key_value="$1"
  IFS=':' read -r _ value << EOF
${key_value}
EOF
  echo "$value"
)


# extract_json_value [json] [key]
#
# outputs value of the key from the given json string
#
extract_json_value() (
  json="$1"
  key="$2"
  key_value=$(echo "${json}" | grep  -o "\"$key\":[^,]*[,}]" | tr -d '",}')

  extract_value "$key_value"
)


# github_release_tag [release-json]
#
# outputs release tag string
#
github_release_tag() (
  json="$1"
  tag=$(extract_json_value "${json}" "tag_name")
  test -z "$tag" && return 1
  echo "$tag"
)

# get_release_tag [owner] [repo] [tag]
#
# outputs tag string
#
get_release_tag() (
  owner="$1"
  repo="$2"
  tag="$3"

  log_debug "get_release_tag(owner=${owner}, repo=${repo}, tag=${tag})"

  json=$(github_release_json "${owner}" "${repo}" "${tag}")
  real_tag=$(github_release_tag "${json}")
  if test -z "${real_tag}"; then
    return 1
  fi

  log_debug "get_release_tag() returned '${real_tag}'"

  echo "${real_tag}"
)

# tag_to_version [tag]
#
# outputs version string
#
tag_to_version() (
  tag="$1"
  value="${tag#v}"

  log_debug "tag_to_version(tag=${tag}) returned '${value}'"

  echo "$value"
)

# get_format_name [os] [arch] [default-format]
#
# outputs an adjusted file format
#
get_format_name() (
  os="$1"
  arch="$2"
  format="$3"
  original_format="${format}"

  case ${os} in
    windows) format=zip ;;
  esac

  log_debug "get_format_name(os=${os}, arch=${arch}, format=${original_format}) returned '${format}'"

  echo "${format}"
)

uname_arch() {
  arch=$(uname -m)
  case $arch in
    x86_64) arch="amd64" ;;
    x86) arch="386" ;;
    i686) arch="386" ;;
    i386) arch="386" ;;
    aarch64) arch="arm64" ;;
    armv5*) arch="armv5" ;;
    armv6*) arch="armv6" ;;
    armv7*) arch="armv7" ;;
  esac

  uname_arch_check "${arch}"

  echo ${arch}
}

uname_arch_check() {
  arch=$1
  case "$arch" in
    386) return 0 ;;
    amd64) return 0 ;;
    arm64) return 0 ;;
    armv5) return 0 ;;
    armv6) return 0 ;;
    armv7) return 0 ;;
    ppc64) return 0 ;;
    ppc64le) return 0 ;;
    mips) return 0 ;;
    mipsle) return 0 ;;
    mips64) return 0 ;;
    mips64le) return 0 ;;
    s390x) return 0 ;;
    amd64p32) return 0 ;;
  esac
  log_crit "uname_arch_check '$(uname -m)' got converted to '$arch' which is not a GOARCH value.  Please file bug report at https://github.com/client9/shlib"
  return 1
}

uname_os() {
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$os" in
    msys*) os="windows" ;;
    mingw*) os="windows" ;;
    cygwin*) os="windows" ;;
  esac

  uname_os_check "$os"
  echo "$os"
}

uname_os_check() {
  os=$1
  case "$os" in
    darwin) return 0 ;;
    dragonfly) return 0 ;;
    freebsd) return 0 ;;
    linux) return 0 ;;
    android) return 0 ;;
    nacl) return 0 ;;
    netbsd) return 0 ;;
    openbsd) return 0 ;;
    plan9) return 0 ;;
    solaris) return 0 ;;
    windows) return 0 ;;
  esac
  log_crit "uname_os_check '$(uname -s)' got converted to '$os' which is not a GOOS value. Please file bug at https://github.com/client9/shlib"
  return 1
}

usage() {
  this="install.sh"
  cat<<EOF
$this: Download ${project_name} ${tool}
Usage: $this [-b] install-dir [-d]
  -d install directory Default - "${install_dir}"
  -h usage

  Empty tag will choose latest
EOF
  exit 2
}


parse_args() {
  while getopts ":b:dh?xs" arg; do
    case "$arg" in
      b) install_dir="$OPTARG" ;;
      h | \?) usage;;
      d) log_set_priority 10 ;;
      s) static="true";;
      x) set -x ;;
    esac
  done
  shift $((OPTIND - 1))
}

get_tag() {
  owner="$1"
  repo="$2"
  tag="$3"

  if [ -z "${tag}" ]; then
    log_debug "checking github for the current release tag"
    tag=""
  else
    log_debug "checking github for release tag='${tag}'"
  fi
  set -u

  tag=$(get_release_tag "${owner}" "${repo}" "${tag}")
  log_info "Using tag: ${tag}"
  if [ "$?" != "0" ]; then
    log_err "unable to find tag='${tag}'"
    log_err "do not specify a version or select a valid version from https://github.com/${OWNER}/${REPO}/releases"
    return 1
  fi

  echo "${tag}"
}


opa_asset() {
  name="$1"
  os="$2"
  arch="$3"
  static="$4"

  asset_filename="${name}_${os}_${arch}"
  if [ ! -z "${static}" ]; then
    asset_filename="${asset_filename}_static"
  fi
  log_debug "opa_asset, Path: ${asset_filename}"
  echo "${asset_filename}"
}



pre_install_tool() {
  install_dir=".tmp"
  tool="opa"
  project_name="opa"
  repo="${project_name}"
  owner="open-policy-agent"
  assert_base_url=https://github.com/${owner}/${repo}/releases/download
}


post_install_tool() {
  rename_filename="opa"
  rename_filepath="${install_dir}/${rename_filename}"
  mv "${asset_filepath}" "${rename_filepath}"
  asset_filepath="${rename_filepath}"
  chmod u+x ${asset_filepath}
}

install_tool() {
  asset_filename=$(opa_asset "${project_name}" "${os}" "${arch}" "${static}")
  tag=$(get_tag "${owner}" "${repo}" "${tag}")
  version=$(tag_to_version "${tag}")
  asset_filepath="${install_dir}/${asset_filename}"
  mkdir -p $install_dir
  download_url="${assert_base_url}/${tag}"
  asset_url="${download_url}/${asset_filename}"
  http_download "${asset_filepath}" "${asset_url}" ""

}

os=$(uname_os)
arch=$(uname_arch)
format=$(get_format_name "${os}" "${arch}" "tar.gz")
pre_install_tool
parse_args "$@"
install_tool
post_install_tool
log_info "Success - $project_name, Downloaded, Path=${asset_filepath}"

