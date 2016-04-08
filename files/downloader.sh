#!/usr/bin/env bash
# utility for downloading files with retries

# define default values for optional parameter
MAX_FETCH_RETRIES=8
CURL_TIMEOUT=30
DOWNLOAD_TIMEOUT=120
LOG_FILE="/dev/stderr"
DOWNLOAD_DIR_PREFIX="/tmp/opsworks-downloader"

usage(){
  cat << EOL
  Usage: $0 -c <CHECKSUM_URL> -d <DOWNLOAD_DIR_PREFIX> -l <LOG_FILE>
            -r <MAX_FETCH_RETRIES> -t <DOWNLOAD_TIMEOUT>
            -u <TARGET_DOWNLOAD_URL> -w <CURL_TIMEOUT>

   -c URL of the checksum file to download for checking file integrity. (optional)
   -d Optional prefix for the name of the directory to download the files into. A temporary directory
      created with mktemp will be created under this path. If not given mktemp will use \$TMPDIR
   -l Absolute path to the log file. (default = /dev/stderr)
   -r Maximum number of retries. (default = 8)
   -t Timeout for downloading files. (default = 120 seconds)
   -u URL of the file to download.
   -w curl timeout, value used for the --connect-timeout option of curl. (default = 30)
   -h Show this stuff.

   The script will try to download the given file and retry if it's size doesn't match
   expectations. For the instance agent the checksum file URL should be given. The script
   will fail if the SHA-1 of the downloaded file doesn't match the one in the checksum file.

   Per default a random directory in created with 'mktemp' will be used as the directory to download
   the files into. The directory name will look like '/tmp/opsworks-downloader.XXXXXXXX'.

EOL
}

gnu_cmd () {
  local _gnu_cmd=''
  local _cmd="$1"
  local _pattern=${2:-"GNU coreutils"}

  for alternative in $(which -a "${_cmd}" "g${_cmd}" "gnu${_cmd}" 2>/dev/null | uniq); do
    if [[ -x "${alternative}" ]] && "${alternative}" --version | grep -q "${_pattern}"; then
      _gnu_cmd="${alternative}"
    fi
  done

  if [[ "$_gnu_cmd" == '' ]]; then
    echo "[ERROR] GNU ${_cmd} is not installed or not found in \$PATH" >> "${LOG_FILE}"
  else
    echo "${_gnu_cmd}"
  fi
}

log () {
  local _msg="$*"

  if [[ -z "${gnu_date}" ]]; then
    gnu_date="$(gnu_cmd date)"
  fi

  echo "[$( ${gnu_date} -u --rfc-2822 )] downloader: ${_msg}" >> "${LOG_FILE}"
}

# takes the prefix for the template for the mktemp command as a parameter. This must be
# a valid path. It must not exist, but we need to have access to it.
download_dir () {
  if [[ -z "${gnu_mktemp}" ]]; then
    gnu_mktemp="$(gnu_cmd mktemp)"
  fi

  local _temp_dir
  _temp_dir=$( ${gnu_mktemp} -d "${DOWNLOAD_DIR_PREFIX}.XXXXXXXX" 2>&1 )

  if [[ "$(echo "${_temp_dir}" | egrep -c "${DOWNLOAD_DIR_PREFIX}")" -eq '1' ]]; then
    log "Successfully created temporary download directory. (${_temp_dir})"
  else
    # $_temp_dir has the output of mktemp.
    log "[ERROR] Failed to create temp directory. (${_temp_dir})"
    exit 1
  fi

  DOWNLOAD_DIR="${_temp_dir}"
}

validate_input () {
  if [[ -z "${PACKAGE_URL}" ]]; then
    log "[ERROR] Parameter missing."
    usage
    exit 1
  fi
}

initialize () {
  COUNTER=0
  STATUS=''

  download_dir
}

file_path () {
  local _file_url="$*"
  local _file_name
  _file_name="$( echo "${_file_url}" | awk -F'/' '{print $NF}' )"
  local _file_path="${DOWNLOAD_DIR}/${_file_name}"

  echo "${_file_path}"
}

verify_sha1sum() {
  if hash sha1sum 2>/dev/null; then
    sha1sum --check --status
  elif hash shasum 2>/dev/null; then
    shasum --status -a 1 --check
  else
    log "[ERROR] shasum is not installed or not found in \$PATH"
    exit 1
  fi
}

match_checksum () {
  if [[ -z "${CHECKSUM_URL}" ]]; then
    log "Checksum proof skipped."
    return 0
  else
    local checksum
    checksum="$(grep "SHA-1" "$(file_path "${CHECKSUM_URL}")" | cut -d " " -f 2)"
    echo "$checksum  $(file_path "${PACKAGE_URL}")" | verify_sha1sum

    local _exitcode=$?

    if [[ "${_exitcode}" != 0 ]]; then
      log "[ERROR] Checksum mismatch. (exitcode=${_exitcode})"
    else
      log "Checksum proof passed."
    fi

    return "${_exitcode}"
  fi
}

check_size () {
  if [[ -e "$(file_path "${PACKAGE_URL}" )" ]]; then

    if [[ -z "${gnu_stat}" ]]; then
      gnu_stat="$(gnu_cmd 'stat')"
    fi

    local _actual_size _http_headers
    _actual_size=$(${gnu_stat} --format="%s" "$(file_path "${PACKAGE_URL}" )")
    _http_headers="$(curl -sI "${PACKAGE_URL}")"
    if [[ "$?" -ne 0 ]]; then
      log "[ERROR] Failed to fetch content length from ${PACKAGE_URL} - curl returned exitcode $?"
      return $?
    fi

    local _expected_size
    _expected_size="$(echo -n "${_http_headers}" | awk '/^Content-Length/ {print $2}' | tr -d '\r')"

    if [[ "${_expected_size}" -eq "${_actual_size}" ]]; then
      log "File size test passed."
      return 0
    else
      local _status_code
      _status_code=$(echo "${_http_headers}" | head -n 1 | tr -d '\r')
      log "[ERROR] File size test failed. ${_status_code} url: ${PACKAGE_URL}"
      return 1
    fi
  else
    log "[ERROR] File size test failed, no file to check."
    return 1
  fi
}

# call it with an URL as param to download files and store them in /tmp
curl_cmd () {
  local _url="$1"

  if [[ -z "${gnu_timeout}" ]]; then
    gnu_timeout="$(gnu_cmd 'timeout')"
  fi

  local _timeout_cmd="${gnu_timeout} --signal=SIGTERM"
  local _curl_params=(--silent --location --show-error --connect-timeout "${CURL_TIMEOUT}" --remote-name "${_url}")

  # download files, watch the download time using gnu timeout
  ( cd "${DOWNLOAD_DIR}" &&
    ${_timeout_cmd} "${DOWNLOAD_TIMEOUT}" "curl" "${_curl_params[@]}" >> "${LOG_FILE}" 2>&1
  )
}

fetch_packages () {
  curl_cmd "${PACKAGE_URL}"

  if [[ -n "${CHECKSUM_URL}" ]]; then
    curl_cmd "${CHECKSUM_URL}"
  fi
}

fetch_with_checksum () {
  if [[ "${COUNTER}" -lt "${MAX_FETCH_RETRIES}" ]]; then
    fetch_packages

    # if download failed, retry.
    local _seconds=0
    if check_size && match_checksum; then
     STATUS='success'
     log "Successfully downloaded ${PACKAGE_URL}"
    else
       _seconds=$(( COUNTER * 5 ))
       (( COUNTER++ ))
       log "Retrying download after ${_seconds} seconds"
       sleep "${_seconds}"

       log "Deleting content of directory ${DOWNLOAD_DIR}"
       rm -f "${DOWNLOAD_DIR}/*"

       # recursice call
       fetch_with_checksum
    fi
  fi
}

downloaded_file_path () {
  if [[ "${STATUS}" == 'success' ]]; then
    file_path "${PACKAGE_URL}"
  else
    log "[ERROR] No file was downloaded."
    return 1
  fi
}

######
##
## Main block

while getopts "c:d:r:l:t:u:hw:" optname
do
  case "$optname" in
    "c")
      # URL for the checksumm to download
      CHECKSUM_URL="${OPTARG:-''}"
      ;;
    "u")
      # URL for the package to download
      PACKAGE_URL="${OPTARG}"
      ;;
    "l")
      LOG_FILE="${OPTARG:-${LOG_FILE}}"
      ;;
    "r")
      MAX_FETCH_RETRIES="${OPTARG:-${MAX_FETCH_RETRIES}}"
      ;;
    "t")
      DOWNLOAD_TIMEOUT="${OPTARG:-${DOWNLOAD_TIMEOUT}}"
      ;;
    "d")
      DOWNLOAD_DIR_PREFIX="${OPTARG:-${DOWNLOAD_DIR_PREFIX}}"
      ;;
    "w")
      CURL_TIMEOUT="${OPTARG:-${CURL_TIMEOUT}}"
      ;;
    "h")
      usage
      exit 0
      ;;
    *)
      echo "Unknown error while processing options"
      usage
      exit 1
      ;;
  esac
done

validate_input
initialize
fetch_with_checksum
downloaded_file_path
