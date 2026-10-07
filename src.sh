#!/bin/sh
# shellcheck enable=avoid-nullary-conditions,check-unassigned-uppercase

#__LICENSE_HERE__

#set -x

#__INNOEXTRACT_BINARY_START__
INNOEXTRACT_BINARY_B64=0
#__INNOEXTRACT_BINARY_END__

INSTALLER_VERSION="DEV"
REPO_PATH="https://github.com/DarthSidiousPT/zoom-platform-darth.sh"
# Identifies this fork in the logs of the servers it contacts
HTTP_USER_AGENT="zoom-platform-darth.sh/$INSTALLER_VERSION (+$REPO_PATH)"
# Per-game fixes: game-fixes/<GUID>.ini in this repo (see game-fixes/README.md)
GAME_FIXES_URL="https://raw.githubusercontent.com/DarthSidiousPT/zoom-platform-darth.sh/main/game-fixes"
INNOEXT_BIN="/tmp/innoextract_zoom"
LAUNCH_SCRIPTS_PATH="$HOME"/.local/share/zoom-platform
APPLICATIONS_ROOT="$HOME"/.local/share/applications/zoom-platform
# Wine's own menu folders, one per icon group. Not ours: the uninstaller only removes empty ones
WINE_MENU_ROOT="$HOME"/.local/share/applications/wine/Programs
UMU_BIN=umu-run
CACHE_DIR="$HOME"/.cache/zoom-platform
# Where umu looks for Proton builds; a game's pinned build is unpacked here
PROTON_COMPAT_DIR="$HOME"/.local/share/Steam/compatibilitytools.d
# File inside a build's folder, written when this script downloaded it. Also baked into uninstall.sh
PROTON_NOTE=.zoom-platform-downloaded
PROTON_GE_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download"
# The pinned Proton build's folder, empty when the game isn't pinned (umu then picks its own)
ZOOM_PROTONPATH=''

# Fallback if xdg-utils is missing. Also baked into uninstall.sh
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2> /dev/null)"
[ -d "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME/Desktop"

CAN_USE_DIALOGS=0
USE_ZENITY=1
(command -v kdialog >/dev/null || command -v zenity >/dev/null) && [ -n "$DISPLAY" ] && CAN_USE_DIALOGS=1
[ $CAN_USE_DIALOGS -eq 1 ] && ! command -v zenity >/dev/null && USE_ZENITY=0

mkdir -p "$CACHE_DIR"

# ShellCheck chokes on the base64 blob, so DEV mode loads the binary from the working dir
get_innoext_string() {
    if [ $INSTALLER_VERSION = "DEV" ]; then
        printf '%s' "$(base64 -w 0 innoextract)"
    else
        printf '%s' "$INNOEXTRACT_BINARY_B64"
    fi
}

dialog_installer_select() {
    if [ $USE_ZENITY -eq 1 ]; then
        zenity --file-selection --title="Select a ZOOM Platform installer"
        return $?
    else
        kdialog --getopenfilename . "ZOOM Platform Windows installer(*.exe)" --title "Select a ZOOM Platform installer"
        return $?
    fi
}

dialog_install_dir_select() {
    if [ $USE_ZENITY -eq 1 ]; then
        zenity --file-selection --directory --title="Select an installation directory"
        return $?
    else
        kdialog --getexistingdirectory . --title "Select an installation directory"
        return $?
    fi
}

# zenity/kdialog simple dialogs ignore --width, so one long line stretches the window.
# Folding to 78 columns first avoids that (--no-wrap then keeps those breaks).
wrap_dialog_msg() {
    if command -v fold > /dev/null; then
        printf '%s\n' "$1" | fold -s -w 78
    else
        printf '%s' "$1"
    fi
}

dialog_msgbox() {
    _type=$1
    _title=$2
    _msg=$(wrap_dialog_msg "$3")

    [ -z "$_title" ] && _title=""

    _param=''
    case $_type in
        "info") [ $USE_ZENITY -eq 1 ] && _param='info' || _param='msgbox' ;;
        "warning") [ $USE_ZENITY -eq 1 ] && _param='warning' || _param='sorry' ;;
        "error") _param='error' ;;
    esac

    if [ $USE_ZENITY -eq 1 ]; then
        zenity --no-wrap --$_param --text="$_msg" --title="$_title"
        return $?
    else
        kdialog --$_param "$_msg" --title "$_title"
        return $?
    fi
}

log_error() {
    printf "\033[31;1mERROR:\033[0m %s\n" "$*" >&2
}

log_warning() {
    printf "\033[33;1mWARNING:\033[0m %s\n" "$*" >&2
}

# Yes/no question, default no. Reads /dev/tty because stdin may be the piped script.
# Returns 0 only to continue.
ask_continue() {
    _ac_title=$1
    _ac_msg=$2

    log_warning "$_ac_title"
    printf '%s\n' "$_ac_msg" >&2

    if [ $CAN_USE_DIALOGS -eq 1 ]; then
        _ac_wrapped=$(wrap_dialog_msg "$_ac_msg")
        if [ $USE_ZENITY -eq 1 ]; then
            zenity --question --no-wrap --title="$_ac_title" --text="$_ac_wrapped" \
                --ok-label="Continue" --cancel-label="Cancel"
        else
            kdialog --warningcontinuecancel "$_ac_wrapped" --title "$_ac_title"
        fi
        return $?
    fi

    # Test the redirect in a subshell: a failing one can kill the shell
    if ( : < /dev/tty ) 2> /dev/null; then
        printf 'Continue anyway? [y/N] ' >&2
        read -r _ac_answer < /dev/tty
        case $_ac_answer in
            [yY] | [yY][eE][sS]) return 0 ;;
        esac
    else
        log_warning "No terminal to ask on, so not continuing."
    fi
    return 1
}

# Prints a byte count like ZOOM's download page (1024-based)
format_size() {
    awk -v _b="$1" 'BEGIN {
        if (_b >= 1073741824) printf "%.2f GB", _b / 1073741824
        else if (_b >= 1048576) printf "%.2f MB", _b / 1048576
        else printf "%.0f KB", _b / 1024
    }'
}

# Shows the error (dialog if possible) and exits. $1: message, $2: dialog title
fatal_error() {
    [ $CAN_USE_DIALOGS -eq 1 ] && dialog_msgbox error "$2" "$1"
    log_error "$1"
    exit 1
}

log_info() {
    printf "\033[33m[\033[35mzoom-platform-darth.sh\033[33m]\033[0m: %s\n" "$*"
}

base64_dec() {
    _input="$1"
    if command -v base64 > /dev/null; then
        printf '%s' "$_input" | base64 -d 2>/dev/null || return 1
    elif command -v openssl > /dev/null; then
        printf '%s' "$_input" | openssl enc -d -base64 -A 2>/dev/null || return 1
    elif command -v python3 > /dev/null; then
        printf '%s' "$_input" | python3 -m base64 -d 2>/dev/null || return 1
    else
        return 1
    fi
}

validate_uuid() {
    _input="$1"
    _uuid_pattern="^[0-9a-fA-F]\{8\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{12\}$"
    expr "$_input" : "$_uuid_pattern" > /dev/null && return 0
    return 1
}

trim_string() {
    awk '{$1=$1;print}'
}

# ZOOM GUID listed for an Inno AppId in game-fixes/known-guids.ini, for installers that carry no
# ZOOM game ID. Returns 0 found, 1 not listed, 2 couldn't get the list. ZOOM_KNOWN_GUIDS_FILE
# reads a local file instead.
fetch_known_guid() {
    _kg_appid=$1
    _kg_file="$CACHE_DIR/known-guids.ini"
    if [ -n "${ZOOM_KNOWN_GUIDS_FILE:-}" ]; then
        _kg_file=$ZOOM_KNOWN_GUIDS_FILE
        [ -r "$_kg_file" ] || return 2
    else
        rm -f "$_kg_file"
        # Not even a 404 is fine: the file always exists on main
        _kg_code=$(curl -Ls --max-time 15 -o "$_kg_file" -w '%{http_code}' \
            -H "User-Agent: $HTTP_USER_AGENT" "$GAME_FIXES_URL/known-guids.ini")
        _kg_exit=$?
        if [ $_kg_exit -ne 0 ] || [ "$_kg_code" != 200 ]; then
            rm -f "$_kg_file"
            return 2
        fi
    fi
    # The file comes off the network, so the value must be a UUID to be used
    _kg_guid=$(awk -v id="$(printf '%s' "$_kg_appid" | tr '[:upper:]' '[:lower:]')" '
        { sub(/\r$/, ""); sub(/[ \t]*[#;].*/, "") }
        NF == 0 { next }
        {
            split($0, kv, "=")
            gsub(/[ \t]/, "", kv[1]); gsub(/[ \t]/, "", kv[2])
            if (tolower(kv[1]) == id) { print tolower(kv[2]); exit }
        }
    ' "$_kg_file")
    validate_uuid "$_kg_guid" || return 1
    printf '%s\n' "$_kg_guid"
}

# Sets GAME_GUID and GAME_GUID_FROM for an installer: "installer" (its own Site GUID), "list"
# (known-guids.ini, for old installers without one), "appid" (the Inno AppId, when the list has
# no entry) or "offline" (no Site GUID and the list couldn't be fetched, GAME_GUID empty).
# Returns 1 when it isn't a ZOOM installer.
resolve_game_guid() {
    _rg_installer=$1
    GAME_GUID=''
    GAME_GUID_FROM=''
    _rg_out=$($INNOEXT_BIN -s --zoom-game-id "$_rg_installer" 2> /dev/null | trim_string)
    if validate_uuid "$_rg_out"; then
        GAME_GUID=$_rg_out
        GAME_GUID_FROM=installer
        return 0
    fi
    # Nothing at all: no ZOOM key in the installer
    [ -n "$_rg_out" ] || return 1

    # A ZOOM key without a Site GUID (older installers): the Inno AppId is all that identifies it.
    # get_header_val doesn't exist yet at this point
    _rg_appid=$($INNOEXT_BIN -s --print-headers "$_rg_installer" 2> /dev/null \
        | sed -n 's/^app_id: "\(.*\)"/\1/p' | sed 's/[{}]//g' | trim_string)
    validate_uuid "$_rg_appid" || return 1
    _rg_appid=$(printf '%s' "$_rg_appid" | tr '[:upper:]' '[:lower:]')

    _rg_listed=$(fetch_known_guid "$_rg_appid")
    case $? in
        0) GAME_GUID=$_rg_listed; GAME_GUID_FROM=list ;;
        1) GAME_GUID=$_rg_appid; GAME_GUID_FROM=appid ;;
        *) GAME_GUID_FROM=offline ;;
    esac
    return 0
}

# Escapes ' as '\'' for a single-quoted literal, so values baked into uninstall.sh can't break it
quote_sq() {
    printf '%s' "$1" | sed "s/'/'\\\\''/g"
}

download_umu_zipapp() {
    _url="$1"
    _url_resp=$(curl -o "$CACHE_DIR"/umu-launcher.tar.xz "$_url" -Ls -H "User-Agent: $HTTP_USER_AGENT")
    _url_exit=$?
    if [ $_url_exit -ne 0 ]; then
        fatal_error "Could not download umu-launcher. Please install it manually."
    fi

    if ! command -v tar > /dev/null; then
        fatal_error "tar was not found on this system."
    fi

    tar --overwrite-dir -C "$CACHE_DIR" -xf "$CACHE_DIR"/umu-launcher.tar.xz umu/umu-run
    rm -f "$CACHE_DIR"/umu-launcher.tar.xz
    chmod +x "$CACHE_DIR"/umu/umu-run
    UMU_BIN="$CACHE_DIR"/umu/umu-run
}

# Get umu-launcher's url from lutris' runtime api
get_umu_url() {
    _api_resp=$(curl -Ls -H "User-Agent: $HTTP_USER_AGENT" \
                    'https://lutris.net/api/runtimes?format=json')
    _api_exit=$?
    if [ $_api_exit -eq 0 ]; then
        _parsed_str="$(printf '%s' "$_api_resp" | awk -F'"name":"umu"' '{ split($2, urls, "url\":\""); print substr(urls[2], 1, index(urls[2], "\"")-1) }')"
        case $_parsed_str in
            *"umu-launcher"*)
                printf '%s' "$_parsed_str"
                exit 0
                ;;
            *)
                exit 1
                ;;
        esac
    fi
    exit 1
}

get_umu_id() {
    _guid="$1"
    _api_resp=$(curl -Ls -H "User-Agent: $HTTP_USER_AGENT" \
                    "https://umu.openwinecomponents.org/umu_api.php?store=zoomplatform&codename=$_guid")
    _api_exit=$?
    if [ $_api_exit -eq 0 ]; then
        _parsed_str="$(printf '%s' "$_api_resp" | awk -F'"umu_id":"' '{print substr($2, 1, index($2, "\"")-1)}')"
        case $_parsed_str in
            "umu-"*)
                printf '%s' "$_parsed_str"
                exit 0
                ;;
            *)
                exit 1
                ;;
        esac
    fi
    exit 1
}

get_desktop_value() {
    _key=$1
    _desktopfile=$2
    sed -n -e "/^$_key=/s/^$_key=//p" "$_desktopfile"
}

# Generate command to launch umu with
umu_launch_command() {
    if [ "$UMU_BIN" = "FLATPAK" ]; then
        # shellcheck disable=SC2016
        printf '%s' 'flatpak run --env=GAMEID="$GAMEID" --env=WINEPREFIX="$WINEPREFIX" --env=STORE="$STORE"'
        # PROTONPATH is only set in a pinned game's launch script while its folder exists, and umu
        # rejects an empty one
        # shellcheck disable=SC2016
        [ -n "$ZOOM_PROTONPATH" ] && printf '%s' ' ${PROTONPATH:+--env=PROTONPATH=$PROTONPATH}'
        printf '%s' ' org.openwinecomponents.umu.umu-launcher'
    else
        printf '%s' "$UMU_BIN"
    fi
}

umu_launch() {
    if [ "$UMU_BIN" = "FLATPAK" ]; then
        [ -z "$PROTON_VERB" ] && PROTON_VERB=waitforexitandrun
        # The Flatpak only sees --env vars. A caller needing extra ones for one call lists their names
        # in ZOOM_FORWARD_ENV (forwarding everything would leak the user's own WINEDLLOVERRIDES into
        # every call). Each --env goes before the app id, which keeps values with spaces intact.
        set -- org.openwinecomponents.umu.umu-launcher "$@"
        for _fwd_name in $ZOOM_FORWARD_ENV; do
            _fwd_val=""
            eval "_fwd_val=\${$_fwd_name}"
            set -- "--env=$_fwd_name=$_fwd_val" "$@"
        done
        # Only a pinned game gets PROTONPATH, so the user's own one is never passed in
        [ -n "$ZOOM_PROTONPATH" ] && set -- "--env=PROTONPATH=$ZOOM_PROTONPATH" "$@"
        flatpak run --env=GAMEID="$GAMEID" --env=WINEPREFIX="$WINEPREFIX" --env=PROTON_VERB="$PROTON_VERB" "$@"
    else
        "$UMU_BIN" "$@"
    fi
}

# Permission check; runs inside the Flatpak when that's the umu in use
test_file_perms() {
    _mode=$1 # r or w
    _target=$2

    case $_mode in
        "r" | "w") ;;
        *)
            fatal_error "Invalid test_file_perms pararm: $_mode. Must be r or w"
    esac

    if [ "$UMU_BIN" = "FLATPAK" ]; then
        flatpak run --command=sh org.openwinecomponents.umu.umu-launcher -c "test -$_mode \"$_target\""
        return $?
    else
        test -"$_mode" "$_target"
        return $?
    fi
}

# Checks the install destination is writable even if it doesn't exist yet (tests the nearest
# existing parent) and prints that folder. Runs inside the Flatpak when used, since its paths
# can differ from the host's.
test_dest_writable() {
    # Path passed as $1, not spliced in, so quotes and $ can't break the script
    # shellcheck disable=SC2016
    _tdw_script='
        _p=$1
        # Walk up to the first existing parent (dirname of "." and "/" is itself, so stop there)
        while [ ! -e "$_p" ]; do
            _parent=$(dirname "$_p")
            [ "$_parent" = "$_p" ] && break
            _p=$_parent
        done
        printf "%s\n" "$_p"
        test -w "$_p"
    '
    if [ "$UMU_BIN" = "FLATPAK" ]; then
        flatpak run --command=sh org.openwinecomponents.umu.umu-launcher -c "$_tdw_script" sh "$1"
        return $?
    else
        sh -c "$_tdw_script" sh "$1"
        return $?
    fi
}

# Prints the size a slice (.bin) says it has. Header: 8-byte magic, then the size little-endian:
# idska16/idska32 -> 4 bytes (offset 8), idskb32 -> 8 bytes (offset 8). Returns 1 on an
# unknown magic.
get_slice_size() {
    _gss_file=$1

    # First 8 bytes as hex
    _gss_magic=$(od -A n -t x1 -N 8 "$_gss_file" 2> /dev/null | tr -d ' \n')
    case $_gss_magic in
        6964736b6131361a | 6964736b6133321a) _gss_len=4 ;; # idska16, idska32
        6964736b6233321a) _gss_len=8 ;;                    # idskb32
        *) return 1 ;;
    esac

    # od prints one number per byte, least significant first. %.0f, not %d: some awks clamp %d
    # to 32 bits and slices are over 2GB.
    od -A n -t u1 -j 8 -N "$_gss_len" "$_gss_file" 2> /dev/null |
        awk 'BEGIN { m = 1 } { for (i = 1; i <= NF; i++) { s += $i * m; m *= 256 } } END { if (NR == 0) exit 1; printf "%.0f", s }'
}

# Prints what's wrong with a slice file (only if shorter than its header says), else nothing
describe_slice_problem() {
    _dsp_file=$1

    # wc pads its output with spaces on some systems
    _dsp_have=$(wc -c < "$_dsp_file" | tr -d ' ')
    if ! _dsp_want=$(get_slice_size "$_dsp_file"); then
        printf 'not an installer data file'
    elif [ "$_dsp_have" -lt "$_dsp_want" ]; then
        printf 'incomplete, %s of %s' "$(format_size "$_dsp_have")" "$(format_size "$_dsp_want")"
    fi
}

# Big installers come as <installer name>-1.bin, -2.bin, ... next to the .exe, and Inno only
# looks for each when it reaches it. Checking up front sorts problems into:
# - misnamed (a browser's "(1)" suffix) or unreadable: fatal, says what to rename or chmod.
#   Inno's own "next disk" prompt can't help, it only accepts the exact name.
# - not found under any name, or shorter than its header says: a warning the user may
#   continue past. For a missing part, Inno's "Setup Needs the Next Disk" dialog lets them
#   browse to the folder that holds it.
# Needs slice_count from the fork's --print-headers; without it there's nothing to check.
check_installer_slices() {
    # Parts Setup will still ask for ("- Part N of M: name.bin" lines), read by the caller
    SLICES_NOT_FOUND=''

    _cis_count=$(get_header_val 'slice_count')
    case $_cis_count in
        '' | 0 | *[!0-9]*) return 0 ;;
    esac

    # Not handled (no ZOOM installer uses them): names stored in the headers before 4.1.7, and
    # a letter suffix with more than one slice per disk
    _cis_spd=$(get_header_val 'slices_per_disk')
    _cis_ver=$(get_header_val 'setup_version')
    _cis_ver=${_cis_ver%% *} # "6.6.0 (unicode)" -> "6.6.0"
    case $_cis_ver in
        [1-3].* | 4.0.* | 4.1.[0-6])
            log_info "Old Inno Setup ($_cis_ver), not checking the .bin files"
            return 0 ;;
    esac
    if [ -n "$_cis_spd" ] && [ "$_cis_spd" != 1 ]; then
        log_info "Installer uses $_cis_spd slices per disk, not checking the .bin files"
        return 0
    fi

    _cis_dir=$(dirname "$INPUT_INSTALLER")
    _cis_exe=${INPUT_INSTALLER##*/}
    _cis_stem=${_cis_exe%.*}
    # The name without a duplicate counter a browser may have added: "Setup (1)" -> "Setup"
    _cis_orig=$(printf '%s' "$_cis_stem" | sed 's/ \{0,1\}([0-9]\{1,\})$//')

    _cis_nl='
'
    _cis_missing=''    # Lines about parts that are misnamed or unreadable: always fatal
    _cis_absent=''     # Lines about parts not found under any name: a warning, see above
    _cis_incomplete='' # Lines about parts that are there but look cut short: a warning too

    _cis_n=1
    while [ "$_cis_n" -le "$_cis_count" ]; do
        # The name Inno Setup will look for
        _cis_want="$_cis_dir/$_cis_stem-$_cis_n.bin"

        if [ -f "$_cis_want" ]; then
            if ! test_file_perms r "$_cis_want"; then
                _cis_missing="$_cis_missing$_cis_nl- Part $_cis_n of $_cis_count can't be read by the installer (permissions): ${_cis_want##*/}"
            else
                _cis_problem=$(describe_slice_problem "$_cis_want")
                [ -n "$_cis_problem" ] && _cis_incomplete="$_cis_incomplete$_cis_nl- ${_cis_want##*/}: $_cis_problem"
            fi
        else
            _cis_found=0
            # Same part under browser counter names, or under the installer's name without its counter
            for _cis_cand in \
                "$_cis_dir/$_cis_orig-$_cis_n.bin" \
                "$_cis_dir/$_cis_stem-$_cis_n ("[0-9]*").bin" \
                "$_cis_dir/$_cis_stem-$_cis_n("[0-9]*").bin" \
                "$_cis_dir/$_cis_orig-$_cis_n ("[0-9]*").bin" \
                "$_cis_dir/$_cis_orig-$_cis_n("[0-9]*").bin"
            do
                # A pattern that matched nothing stays as text, and -f skips it
                [ -f "$_cis_cand" ] || continue
                # The same file can match more than one pattern when stem and orig are the same
                case $_cis_missing in *"\"${_cis_cand##*/}\""*) continue ;; esac
                _cis_found=1
                _cis_problem=$(describe_slice_problem "$_cis_cand")
                _cis_note=''
                [ -n "$_cis_problem" ] && _cis_note=" ($_cis_problem)"
                _cis_missing="$_cis_missing$_cis_nl- Part $_cis_n of $_cis_count: rename \"${_cis_cand##*/}\"$_cis_note to \"${_cis_want##*/}\""
            done
            [ $_cis_found -eq 0 ] && _cis_absent="$_cis_absent$_cis_nl- Part $_cis_n of $_cis_count: ${_cis_want##*/}"
        fi
        _cis_n=$((_cis_n+1))
    done

    if [ -n "$_cis_missing" ]; then
        _cis_msg="This installer comes in $_cis_count data files (.bin) that must be in the same folder, with names that start with the installer's:$_cis_nl$_cis_dir$_cis_nl$_cis_missing"
        [ -n "$_cis_incomplete" ] && _cis_msg="$_cis_msg$_cis_nl${_cis_nl}These also look wrong:$_cis_incomplete"
        [ -n "$_cis_absent" ] && _cis_msg="$_cis_msg$_cis_nl${_cis_nl}These weren't found anywhere either (fix the problems above first, then run the script again to see if Setup can ask for these itself):$_cis_absent"
        # If the installer itself was renamed, renaming it back is an alternative
        if [ "$_cis_stem" != "$_cis_orig" ]; then
            _cis_msg="$_cis_msg$_cis_nl${_cis_nl}The installer's own name has a download counter too. If the .bin files have the original names, renaming the installer back to \"$_cis_orig${_cis_exe#"$_cis_stem"}\" is enough."
        fi
        fatal_error "$_cis_msg${_cis_nl}${_cis_nl}Fix the names and run the script again." "Installer files missing"
    fi

    if [ -n "$_cis_absent" ] || [ -n "$_cis_incomplete" ]; then
        if [ -n "$_cis_absent" ] && [ -n "$_cis_incomplete" ]; then
            _cis_title="Installer files not found or incomplete"
        elif [ -n "$_cis_absent" ]; then
            _cis_title="Installer files not found"
        else
            _cis_title="Installer files look damaged or incomplete"
        fi

        _cis_msg=''
        if [ -n "$_cis_absent" ]; then
            _cis_msg="These data files (.bin) weren't found next to the installer:$_cis_absent${_cis_nl}${_cis_nl}Setup has its own way to handle this: it will ask for each one by name during install (a \"Setup Needs the Next Disk\" dialog).${_cis_nl}When it does, point it at whatever folder, disc or drive actually holds that file.${_cis_nl}The folder doesn't matter, but the file must keep the exact name shown above."
        fi
        if [ -n "$_cis_incomplete" ]; then
            [ -n "$_cis_msg" ] && _cis_msg="$_cis_msg$_cis_nl$_cis_nl"
            _cis_msg="${_cis_msg}These files don't look right, their download probably didn't finish:$_cis_incomplete${_cis_nl}${_cis_nl}The installation will most likely fail partway through."
        fi

        ask_continue "$_cis_title" "$_cis_msg" ||
            fatal_error "Cancelled. Fix the files listed above and run the script again." "Cancelled"

        SLICES_NOT_FOUND=$_cis_absent
    else
        log_info "Found all $_cis_count installer data files"
    fi
}

# Loose check if dir is a wine prefix
is_valid_prefix() {
    _wine_prefix="$1"

    [ ! -d "$_wine_prefix" ] && return 1

    _required_dirs="drive_c dosdevices"
    _required_files="system.reg user.reg"
    for dir in $_required_dirs; do
        [ ! -d "$_wine_prefix/$dir" ] && return 1
    done

    for f in $_required_files; do
        [ ! -f "$_wine_prefix/$f" ] && return 1
    done

    return 0
}

# Values of the zoom keys in the registry. Deliberately loose: several lines come back when
# more than one game is installed.
get_prefix_reg_val() {
    _wine_prefix="$1"
    _key="$2"
    _res="$(awk -v key="$_key" '
        BEGIN { in_section = 0; }
        {
            if ($0 ~ ("^\\[Software\\\\\\\\ZOOM PLATFORM\\\\\\\\")) {
                in_section = 1;
            } else if (in_section && match($0, "^\"" key "\"=")) {
                print $0;
            }
        }
    ' "$_wine_prefix/system.reg" | awk -F'"' '{print $4}')"

    printf '%s\n' "$_res" # the line break is required for while read
}

# Check if wine prefix has a specific zoom game installed. $3 (optional): the installer's Inno
# AppId, because old installers never write a Site GUID; Inno's uninstall key is the only trace
prefix_has_game() {
    _wine_prefix="$1"
    _guid="$2"
    _appid="${3:-}"

    if ! is_valid_prefix "$_wine_prefix"; then
        return 1
    else
        _r=1
        _tmp=$(mktemp)
        get_prefix_reg_val "$_wine_prefix" "Site GUID" > "$_tmp"
        while read -r line; do
            if [ "$line" = "$_guid" ]; then
                _r=0
                break
            fi
        done < "$_tmp"
        rm -f "$_tmp"
        if [ $_r -ne 0 ] && [ -n "$_appid" ] && [ -r "$_wine_prefix/system.reg" ] &&
            awk -v id="$_appid" '
                BEGIN { want = tolower("\\Uninstall\\\\{" id "}_is1]") }
                index(tolower($0), want) { found = 1; exit }
                END { exit !found }
            ' "$_wine_prefix/system.reg"; then
            _r=0
        fi
        return $_r
    fi
}

# Check if wine prefix has any zoom game installed
prefix_has_any_game() {
    _wine_prefix="$1"

    _r=1
    _tmp=$(mktemp)
    get_prefix_reg_val "$_wine_prefix" "InstallPath" > "$_tmp"

    # More than one is valid when DLC is installed
    while read -r line; do
        if [ -d "$(PROTON_VERB=getnativepath umu_launch "$line")" ]; then
            _r=0
            break
        fi
    done < "$_tmp"
    rm -f "$_tmp"
    return $_r
}

_lnk_read_block() {
    _lnkpath=$1
    _offset=$2
    _length=$3
    od --endian=little -tdI -An -j "$_offset" -N "$_length" "$_lnkpath" | tr -d '\n '
}

_lnk_readstr_utf16() {
    _lnkpath=$1
    _offset=$2
    _length=$3
    _unicode=$4
    _result=''
    if [ "$_unicode" = 1 ]; then
        # stop at first \0 by getting offset and overriding _length
        _nul_offset=$(od -w2 -v -t x2 -Ad -j "$_offset" -N "$_length" "$_lnkpath" | awk '$2 == "0000" {print $1+0;exit}')
        [ -n "$_nul_offset" ] && _length=$((_nul_offset-_offset))

        _result=$(dd skip="$_offset" count="$_length" if="$_lnkpath" bs=1 status=none | iconv -f UTF-16LE -t UTF-8)
    else
        _result=$(od -S1 -An -j "$_offset" -N "$_length" "$_lnkpath")
    fi
    printf '%s' "$_result" | sed 's/\\/\\\\/g'
}

# Parses a Windows .lnk. Spec:
# - https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-shllink/16cb4ca1-9339-4d0c-a68d-bf1d6cc0f943
# - https://github.com/libyal/liblnk/tree/main/documentation
parse_lnk() {
    _lnkpath="$1"

    # https://github.com/libyal/liblnk/blob/main/documentation/Windows%20Shortcut%20File%20(LNK)%20format.asciidoc#21-data-flags
    _flags_oct=$(od -An -j 20 -N 1 "$_lnkpath" | tr -d '\n ')
    _flags=$(printf '%s\n' "$_flags_oct" | dd status=none)

    # https://github.com/libyal/liblnk/blob/main/documentation/Windows%20Shortcut%20File%20(LNK)%20format.asciidoc#3-link-target-identifier
    _itemlist_count=$(_lnk_read_block "$_lnkpath" 76 2)

    # LinkInfo
    # https://github.com/libyal/liblnk/blob/main/documentation/Windows%20Shortcut%20File%20(LNK)%20format.asciidoc#4-location-information
    _location_offset=$((_itemlist_count+78)) # skip guid
    _link_info_length=$(_lnk_read_block "$_lnkpath" $_location_offset 4)            # LinkInfoSize
    _link_info_header_size=$(_lnk_read_block "$_lnkpath" $((_location_offset+4)) 4) # LinkInfoHeaderSize
    _link_info_flags=$(_lnk_read_block "$_lnkpath" $((_location_offset+8)) 4)       # LinkInfoFlags
    _basepath_offset=$(_lnk_read_block "$_lnkpath" $((_location_offset+16)) 4)      # LocalBasePathOffset

    _basepath_is_unicode=0
    # Use unicode offset instead
    if [ "$_link_info_header_size" -gt 28 ]; then
        _basepath_offset=$(_lnk_read_block "$_lnkpath" $((_location_offset+28)) 4) # LocalBasePathOffsetUnicode
        _basepath_is_unicode=1
    fi

    _localpath_offset=$((_location_offset+_basepath_offset))
    _localpath_end=$((_location_offset+_link_info_length))
    _localpath_length=$((_localpath_end-_localpath_offset))

    _localpath=$(_lnk_readstr_utf16 "$_lnkpath" $_localpath_offset $_localpath_length $_basepath_is_unicode) # LocalBasePath or LocalBasePathUnicode

    printf 'LocalBasePath:%s\n' "$_localpath"

    # StringData
    # STRING_DATA = [NAME_STRING] [RELATIVE_PATH] [WORKING_DIR] [COMMAND_LINE_ARGUMENTS] [ICON_LOCATION]
    # https://github.com/libyal/liblnk/blob/main/documentation/Windows%20Shortcut%20File%20(LNK)%20format.asciidoc#5-data-strings
    
    _stringdata_is_unicode=0
    # IsUnicode
    [ "$((_flags & 0x00000080))" -ne 0 ] && _stringdata_is_unicode=1

    _stringdata_offset=$_localpath_end
    # HasName HasRelativePath HasWorkingDir HasArguments HasIconLocation
    for i in 0x00000004 0x00000008 0x00000010 0x00000020 0x00000040 ; do
        if [ "$((_flags & i))" -ne 0 ]; then
            _stringdata_length=$(_lnk_read_block "$_lnkpath" "$_stringdata_offset" 2) # CountCharacters
            [ "$_stringdata_is_unicode" = 1 ] && _stringdata_length=$((_stringdata_length*2))

            _stringdata_value=''
            [ "$_stringdata_length" -gt 0 ] && \
                _stringdata_value="$(_lnk_readstr_utf16 "$_lnkpath" $((_stringdata_offset+2)) "$_stringdata_length" "$_stringdata_is_unicode")"

            _stringdata_offset=$((_stringdata_offset+_stringdata_length))
            [ $_stringdata_is_unicode = 1 ] && _stringdata_offset=$((_stringdata_offset+2))

            if [ -n "$_stringdata_value" ]; then
                case "$i" in
                    0x00000004) printf 'NAME_STRING:';;
                    0x00000008) printf 'RELATIVE_PATH:';;
                    0x00000010) printf 'WORKING_DIR:';;
                    0x00000020) printf 'COMMAND_LINE_ARGUMENTS:';;
                    0x00000040) printf 'ICON_LOCATION:';;
                esac
                printf '%s\n' "$_stringdata_value"
            fi
        fi
    done
}

# Whether a shortcut gets no launcher (uninstaller, PDFs, HTML manuals).
# $1: target exe or document (wine's StartupWMClass is lowercase, parse_lnk's isn't, so both
#     are lowercased here), $2: shortcut name. Returns 0 to skip.
is_skipped_shortcut() {
    _skip_target=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    _skip_name=$2
    case $_skip_target in
        # Skip uninstaller and PDFs
        "unins000.exe" | *".pdf")
            return 0
            ;;
        # Skip HTML manuals
        *".html" | *".htm")
            case $_skip_name in
                *"Manual"*)
                    return 0
                    ;;
            esac
            ;;
    esac
    return 1
}

# Prints the Windows path of every shortcut (.lnk) this install created, from Inno's log
# ("-- Icon entry --", then "Dest filename: C:\...\Game.lnk"). The log is recreated each run,
# so in a shared prefix this only gives the shortcuts of the install that just ran.
get_install_lnks() {
    # CRLF endings. "Icon entry" arms the flag, the next "Dest filename:" is the shortcut, and any
    # other "-- Xxx entry --" disarms it (so a File entry isn't mistaken for one).
    awk '
        { sub("\r$", "") }
        /-- Icon entry --$/ { icon = 1; next }
        /-- [A-Za-z]+ entry --$/ { icon = 0; next }
        icon && /Dest filename: / {
            sub(/^.*Dest filename: /, "")
            if (tolower($0) ~ /\.lnk$/) print
            icon = 0
        }
    ' "$INSTALL_PATH/drive_c/zoom_installer.log"
}

# Prints the native path of every .lnk in the Start Menus and the Public Desktop. A shared
# prefix holds every install's, so this run's are told apart by age: zoom_install_started is
# touched right before the installer launches.
# $1: "new" for those written since then, "old" for the rest
# (Newlines in shortcut names aren't handled; Windows doesn't allow them.)
list_lnks_on_disk() {
    _ll_drive_c="$INSTALL_PATH/drive_c"
    _ll_marker="$_ll_drive_c/zoom_install_started"
    # Without the marker there's no telling which run wrote what
    [ -f "$_ll_marker" ] || return 0
    if [ "$1" = "new" ]; then
        set -- -newer "$_ll_marker"
    else
        set -- ! -newer "$_ll_marker"
    fi
    find "$_ll_drive_c/ProgramData/Microsoft/Windows/Start Menu" \
         "$_ll_drive_c"/users/*/AppData/Roaming/Microsoft/Windows/"Start Menu" \
         "$_ll_drive_c/users/Public/Desktop" \
         -iname '*.lnk' "$@" 2> /dev/null
}

# Fallback for get_install_lnks: this run's .lnk files found on disk (also finds Desktop-only
# shortcuts). Prints Windows paths.
find_install_lnks() {
    _fl_drive_c="$INSTALL_PATH/drive_c"
    list_lnks_on_disk new | while IFS= read -r _fl_lnk; do
        # Strip the quoted prefix up to drive_c, turn / into \ (octal 134) and put C:\ back
        _fl_win=$(printf '%s' "${_fl_lnk#"$_fl_drive_c/"}" | tr '/' '\134')
        printf '%s\n' "C:\\$_fl_win"
    done
}

# What a shortcut launches: target, working dir, arguments. Empty if it can't be parsed.
# $1: native path of the .lnk
lnk_launch_signature() {
    parse_lnk "$1" 2> /dev/null | grep -E '^(LocalBasePath|WORKING_DIR|COMMAND_LINE_ARGUMENTS):'
}

# For a DLC's shortcut: compares it with same-named .lnk files from before this run (usually
# the base game's). Returns 0 if one launches exactly the same thing (nothing to add), 2 if
# there are same-named ones but this launches something else (the DLC's own), 1 if none.
# $1: native path of this run's .lnk, $2: shortcut name
compare_with_existing_lnk() {
    _cw_sig=$(lnk_launch_signature "$1")
    _cw_name=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
    _cw_result=1
    # Compared by name here, not find -name: names can hold glob characters. Case-insensitive,
    # like wine.
    while IFS= read -r _cw_other; do
        [ -n "$_cw_other" ] || continue
        _cw_base=${_cw_other##*/}
        _cw_base=$(printf '%s' "${_cw_base%.[lL][nN][kK]}" | tr '[:upper:]' '[:lower:]')
        [ "$_cw_base" = "$_cw_name" ] || continue
        _cw_result=2
        # An unreadable .lnk (empty signature) is never "the same"
        if [ -n "$_cw_sig" ] && [ "$(lnk_launch_signature "$_cw_other")" = "$_cw_sig" ]; then
            _cw_result=0
            break
        fi
    done <<EOL
$(list_lnks_on_disk old)
EOL
    return $_cw_result
}

# Whether a proton_shortcuts .desktop was written by wine during this run. Wine keeps one per
# shortcut name for the whole prefix, so an old one (say the base game's, same name as a DLC's
# shortcut) mustn't be taken for this run's. Wine rewrites it every run, so older than
# zoom_install_started means not this run's.
# $1: path of the .desktop
is_desktop_from_this_run() {
    _fr_marker="$INSTALL_PATH/drive_c/zoom_install_started"
    # Without the marker there's no telling, so trust what's there
    [ -f "$_fr_marker" ] || return 0
    [ -n "$(find "$1" -newer "$_fr_marker" 2> /dev/null)" ]
}

# Shortcut name from its Windows path (filename without .lnk); wine names the .desktop after it
get_lnk_name() {
    _gl_name=${1##*\\}
    printf '%s' "${_gl_name%.[lL][nN][kK]}"
}

# Makes sure every shortcut this install created has a proton_shortcuts/*.desktop.
#
# Wine's winemenubuilder writes those in the background, but it waits for the installer to
# exit and the installer is killed first, so it rarely finishes. It's also disabled by
# WINEDLLOVERRIDES="winemenubuilder.exe=d". So step 2 is the normal path, not a fallback.
# 1. Any default-verb umu launch runs "wineserver -w" first, which waits for every process
#    in the prefix.
# 2. Shortcuts still without a .desktop from this run (is_desktop_from_this_run) get
#    winemenubuilder run by hand, with the DLL override forced on for that call only.
# 3. Whatever is still missing is reported by name (not fatal).
#
# Only this run's shortcuts are looked at (the installer's log, else .lnk files newer than the
# start marker), never the rest of a shared prefix.
# Sets SHORTCUTS_KEPT (how many get a launcher), INSTALL_SHORTCUTS and
# INSTALL_DESKTOP_SHORTCUTS (names as "|name|name|": all of them, and the Desktop ones). An
# empty list means nothing to make.
# Output of the umu calls goes to drive_c/zoom_menubuilder.log.
# Idea from upstream's 672c694 ("Run winemenubuilder manually").
ensure_proton_shortcuts() {
    _sc_log="$INSTALL_PATH/drive_c/zoom_menubuilder.log"
    SHORTCUTS_KEPT=0
    INSTALL_SHORTCUTS='|'
    INSTALL_DESKTOP_SHORTCUTS='|'

    _sc_links=$(get_install_lnks)
    [ -n "$_sc_links" ] || _sc_links=$(find_install_lnks)
    if [ -z "$_sc_links" ]; then
        _sc_icon_count=$(get_header_val 'icon_count')
        # Start Menu entries can't be disabled in the installer, so having none is worth reporting
        [ "${_sc_icon_count:-0}" -gt 0 ] && \
            log_error "The installer defines ${_sc_icon_count} shortcut(s) but none were created, so there are no launchers. The game is installed in \"$INSTALL_PATH\"."
    fi

    # Sync point, see (1) above. Any cheap command works, hostname has no side effects.
    # UMU_CONTAINER_NSENTER would switch umu to a verb that doesn't wait.
    ( unset UMU_CONTAINER_NSENTER; umu_launch hostname ) >> "$_sc_log" 2>&1 < /dev/null

    _sc_missing=''
    _sc_nl='
'
    # Fed by a here-doc, not a pipe, so the counters survive (dash runs a pipe's right side in a
    # subshell). umu calls get </dev/null so they can't swallow it.
    while IFS= read -r _sc_win; do
        [ -n "$_sc_win" ] || continue
        _sc_name=$(get_lnk_name "$_sc_win")

        # Record the Desktop ones before the check below drops the Desktop copy of a name
        case $_sc_win in
            *\\[Dd]esktop\\*) INSTALL_DESKTOP_SHORTCUTS="$INSTALL_DESKTOP_SHORTCUTS$_sc_name|" ;;
        esac

        # The Desktop and Start Menu copies of a shortcut share one .desktop, only handle it once
        case $INSTALL_SHORTCUTS in
            *"|$_sc_name|"*) continue ;;
        esac
        INSTALL_SHORTCUTS="$INSTALL_SHORTCUTS$_sc_name|"

        _sc_desktop="$PROTON_SHORTCUTS_PATH/$_sc_name.desktop"
        if [ -f "$_sc_desktop" ] && is_desktop_from_this_run "$_sc_desktop"; then
            # Wine made it (one from an earlier install doesn't count, see below). The skip rules apply
            # to the target wine recorded.
            is_skipped_shortcut "$(get_desktop_value "StartupWMClass" "$_sc_desktop")" "$_sc_name" && continue
            SHORTCUTS_KEPT=$((SHORTCUTS_KEPT+1))
            continue
        fi

        # No .desktop: read the .lnk to skip the uninstaller and manuals without launching umu.
        # C:\a\b.lnk -> <prefix>/drive_c/a/b.lnk; if the case differs (wine ignores case, the
        # filesystem doesn't) ask wine for the real path.
        _sc_rel=${_sc_win#?:\\}
        _sc_native="$INSTALL_PATH/drive_c/$(printf '%s' "$_sc_rel" | tr '\134' '/')" # \134 is a backslash
        if [ ! -f "$_sc_native" ]; then
            _sc_native=$( (PROTON_VERB=getnativepath umu_launch "$_sc_win" < /dev/null) 2> /dev/null | head -n 1)
        fi
        if [ ! -f "$_sc_native" ]; then
            log_error "Can't find the shortcut file for \"$_sc_name\" ($_sc_win), so it won't get a launcher."
            continue
        fi
        # LocalBasePath is the target exe (backslashes doubled): keep just the exe name. A corrupt
        # .lnk gives nothing, so it isn't skipped and winemenubuilder gets a go (reported if it fails).
        _sc_exe=$(parse_lnk "$_sc_native" 2> /dev/null | sed -n 's/^LocalBasePath://p')
        _sc_exe=${_sc_exe##*\\}
        is_skipped_shortcut "$_sc_exe" "$_sc_name" && continue

        SHORTCUTS_KEPT=$((SHORTCUTS_KEPT+1))
        _sc_missing="$_sc_missing$_sc_win$_sc_nl"
    done <<EOL
$_sc_links
EOL

    [ -n "$_sc_missing" ] || return 0

    printf '=== winemenubuilder for shortcuts wine did not create:\n%s' "$_sc_missing" >> "$_sc_log"
    # Proton hides wine's messages unless PROTON_LOG is set; turn it on for this call only so a
    # winemenubuilder failure ends up in our log.
    _sc_wine_log_dir="$INSTALL_PATH/drive_c/zoom_menubuilder_tmp"
    mkdir -p "$_sc_wine_log_dir"
    (
        # One call for all of them, each .lnk its own argument, so odd names need no escaping
        set --
        while IFS= read -r _sc_win; do
            [ -n "$_sc_win" ] && set -- "$@" "$_sc_win"
        done <<EOL
$_sc_missing
EOL
        # Force the DLL on for this call only (later entries win over a user's "=d"). It stays in
        # this subshell.
        WINEDLLOVERRIDES="${WINEDLLOVERRIDES:+$WINEDLLOVERRIDES;}winemenubuilder.exe=b"
        PROTON_LOG=1
        PROTON_LOG_DIR="$_sc_wine_log_dir"
        WINEDEBUG="err+menubuilder,warn+menubuilder"
        export WINEDLLOVERRIDES PROTON_LOG PROTON_LOG_DIR WINEDEBUG
        ZOOM_FORWARD_ENV="WINEDLLOVERRIDES PROTON_LOG PROTON_LOG_DIR WINEDEBUG"
        umu_launch winemenubuilder "$@"
    ) >> "$_sc_log" 2>&1 < /dev/null
    # Keep just wine's winemenubuilder lines, and drop the rest of Proton's log
    cat "$_sc_wine_log_dir"/*.log 2> /dev/null | grep -a 'menubuilder:' >> "$_sc_log"
    rm -rf "$_sc_wine_log_dir"

    # winemenubuilder exits 0 even when it fails to write an entry, so check for the files
    while IFS= read -r _sc_win; do
        [ -n "$_sc_win" ] || continue
        _sc_name=$(get_lnk_name "$_sc_win")
        { [ -f "$PROTON_SHORTCUTS_PATH/$_sc_name.desktop" ] && is_desktop_from_this_run "$PROTON_SHORTCUTS_PATH/$_sc_name.desktop"; } || \
            log_error "Couldn't create a launcher for the shortcut \"$_sc_name\" ($_sc_win). See $_sc_log"
    done <<EOL
$_sc_missing
EOL
}

# Reads a game-fixes file and prints one line per launcher: name|replaces|exe|workdir|args,
# or !|name|reason for an unusable one. The file comes off the network and ends up in a
# generated shell script, so every value is checked against allowed characters (none can hold
# the | separator). Keys before the first [section] apply to the whole game; the three that
# pin a Proton build come out as one line with an empty first field:
#   |proton|tag|asset|sha512      or      !|proton|reason
# The [wine registry] section holds one value per line, "HKCU\Software\...\name = dword:1" or
# "= sz:text"; each comes out as @|key|name|type|data, or !|<line>|reason.
# $1: the file
parse_game_fixes() {
    awk '
        function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
        # Does s hold any of the characters in set?
        function has_any(s, set,    i) {
            for (i = 1; i <= length(set); i++)
                if (index(s, substr(set, i, 1))) return 1
            return 0
        }
        # Is every character of s in set?
        function only(s, set,    i) {
            for (i = 1; i <= length(s); i++)
                if (!index(set, substr(s, i, 1))) return 0
            return 1
        }
        # Names end up in file names, in .desktop files and in the lines printed below
        function bad_name(s) { return s == "" || s ~ /^[.]/ || has_any(s, "/|\\\"$`\t\r") }
        # A Windows path below the game folder: no drive, no "..", no empty parts
        function bad_path(p,    q) {
            if (!only(p, ALNUM " ._()+,-\\")) return "has characters that are not allowed"
            q = p
            gsub(/\\/, "/", q) # from here on a plain / separates the parts
            if (q ~ /^\// || q ~ /\/$/ || q ~ /\/\// || q ~ /(^|\/)[.][.](\/|$)/) return "is not a plain relative path"
            return ""
        }
        # One line of the [registry] section: "<root>\Software\<key>\<name> = <type>:<data>". Wine is
        # no sandbox, so this is a best-effort block list of the keys that start programs or
        # register code. A 32-bit game reads HKLM\Software\WOW6432Node, so the file names that
        # path itself.
        function registry_line(line,    eq, path, spec, n, p, q, i, c, root, type, data, key, name, r) {
            eq = index(line, "=")
            if (eq == 0) return "!|" safe(line) "|a registry line must be: path = type:data"
            path = trim(substr(line, 1, eq - 1))
            spec = trim(substr(line, eq + 1))
            r = bad_path(path)
            if (r != "") return "!|" safe(path) "|the path " r
            q = path
            gsub(/\\/, "/", q) # a plain / separates the parts, as in bad_path
            n = split(q, p, "/")
            root = toupper(p[1])
            if (root != "HKCU" && root != "HKLM") return "!|" safe(path) "|the path must start with HKCU\\ or HKLM\\"
            if (n < 4 || tolower(p[2]) != "software") return "!|" safe(path) "|the path must be <root>\\Software\\<key>\\<value name>"
            for (i = 2; i < n; i++) {
                c = tolower(p[i])
                if (c ~ /^(run|runonce|runonceex|runservices|runservicesonce|winlogon|classes|policies|explorer|app paths|aedebug|command processor|shell folders|user shell folders|image file execution options)$/)
                    return "!|" safe(path) "|the key " p[i] " is not allowed"
                # Wine at any depth (WOW6432Node\Wine too): only DllOverrides below it
                if (c == "wine" && (tolower(p[i + 1]) != "dlloverrides" || i + 1 == n))
                    return "!|" safe(path) "|under Wine only DllOverrides is allowed"
            }
            name = p[n]
            if (tolower(name) ~ /^(appinit_dlls|loadappinit_dlls)$/) return "!|" safe(path) "|the value " name " is not allowed"
            if (index(spec, ":") == 0) return "!|" safe(path) "|the value must be dword:<number> or sz:<text>"
            type = substr(spec, 1, index(spec, ":") - 1)
            data = substr(spec, index(spec, ":") + 1)
            if (type == "dword") {
                if (data == "" || length(data) > 10 || !only(data, "0123456789") || data + 0 > 4294967295)
                    return "!|" safe(path) "|a dword must be a number from 0 to 4294967295"
                data = sprintf("%.0f", data + 0) # reg.exe reads a leading 0 as octal
            } else if (type == "sz") {
                if (!only(data, ALNUM " ._,=:/-+()\\")) return "!|" safe(path) "|the sz text has characters that are not allowed"
                if (data ~ /\\$/) return "!|" safe(path) "|the sz text can not end with a backslash"
            } else return "!|" safe(path) "|the type must be dword or sz"
            key = substr(path, 1, length(path) - length(name) - 1)
            sub(/^[^\\]*/, root, key)
            return "@|" key "|" name "|" type "|" data
        }
        # A name or line for a message: it can not hold the | separator
        function safe(s) { gsub(/[|]/, "?", s); return s }
        # Prints the launcher collected so far, if there is one
        function finish(    why, r, n) {
            if (!open) return
            why = ""
            if (bad_name(name)) why = "the launcher name is empty or has characters that are not allowed"
            if (why == "" && bad_name(replaces)) why = "replaces is missing or has characters that are not allowed"
            if (why == "" && exe == "") why = "exe is missing"
            if (why == "") { r = bad_path(exe); if (r != "") why = "exe " r }
            if (why == "" && workdir != "") { r = bad_path(workdir); if (r != "") why = "workdir " r }
            if (why == "" && !only(args, ALNUM " +._,=:/-")) why = "args has characters that are not allowed"
            n = name
            gsub(/[|]/, "?", n)
            if (why != "") print "!|" n "|" why
            else print name "|" replaces "|" exe "|" workdir "|" args
        }
        # Prints the pinned Proton build from the keys before the first section. Tag and asset end
        # up in a URL and a path, so they must follow GloriousEggroll naming; the checksum is what
        # makes the download trustworthy.
        function game_wide(    why) {
            if (g_tag == "" && g_asset == "" && g_sha == "") return
            why = ""
            if (g_tag == "" || g_asset == "" || g_sha == "") why = "proton, proton_asset and proton_sha512 must all be given"
            else if (g_tag !~ /^GE-Proton[0-9]+-[0-9]+$/) why = "proton must look like GE-Proton11-7"
            else if (g_asset != (g_tag ".tar.gz") && g_asset != (g_tag "-x86_64.tar.gz")) why = "proton_asset must be the proton value followed by .tar.gz or -x86_64.tar.gz"
            else if (length(g_sha) != 128 || !only(g_sha, "0123456789abcdef")) why = "proton_sha512 must be 128 lowercase hex characters"
            if (why != "") print "!|proton|" why
            else print "|proton|" g_tag "|" g_asset "|" g_sha
        }
        BEGIN {
            ALNUM = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        }
        { sub(/\r$/, "") } # a file saved on Windows
        /^[ \t]*[#;]/ || /^[ \t]*$/ { next }
        /^[ \t]*\[.*\][ \t]*$/ { # [launcher name] starts a launcher, [wine registry] the registry values
            finish()
            h = trim($0)
            name = trim(substr(h, 2, length(h) - 2))
            in_reg = (tolower(name) == "wine registry")
            open = !in_reg
            replaces = exe = workdir = args = ""
            next
        }
        in_reg { print registry_line(trim($0)); next }
        !open && index($0, "=") { # before the first section: keys for the whole game
            k = trim(substr($0, 1, index($0, "=") - 1))
            v = trim(substr($0, index($0, "=") + 1))
            if (k == "proton") g_tag = v
            else if (k == "proton_asset") g_asset = v
            else if (k == "proton_sha512") g_sha = v
            next
        }
        open && index($0, "=") {
            k = trim(substr($0, 1, index($0, "=") - 1))
            v = trim(substr($0, index($0, "=") + 1))
            if (k == "replaces") replaces = v
            else if (k == "exe") exe = v
            else if (k == "workdir") workdir = v
            else if (k == "args") args = v
            # any other key is ignored, so an older script can read a newer file
            next
        }
        END { finish(); game_wide() }
    ' "$1"
}

# Looks for this game's file in game-fixes/ (named after its GUID) and puts the usable
# launchers in GAME_FIXES ("name|replaces|exe|workdir|args" per line). The file is optional, so
# failing to get it never stops the install. ZOOM_GAME_FIXES_FILE reads a local file instead.
load_game_fixes() {
    GAME_FIXES=''
    GAME_FIXES_REGISTRY='' # "key|name|type|data" per value
    GAME_FIXES_PROTON=''
    GAME_FIXES_PROTON_ASSET=''
    GAME_FIXES_PROTON_SHA512=''
    _gf_nl='
'
    _gf_file="$CACHE_DIR/game-fixes.ini"
    if [ -n "${ZOOM_GAME_FIXES_FILE:-}" ]; then
        _gf_file=$ZOOM_GAME_FIXES_FILE
        log_info "Game fixes: reading \"$_gf_file\" (from ZOOM_GAME_FIXES_FILE)"
        if [ ! -r "$_gf_file" ]; then
            log_warning "Game fixes: can't read \"$_gf_file\", going on without them"
            return 0
        fi
    else
        # Lowercase GUID (raw.githubusercontent.com is case sensitive)
        _gf_url="$GAME_FIXES_URL/$(printf '%s' "$ZOOM_GUID" | tr '[:upper:]' '[:lower:]').ini"
        log_info "Game fixes: looking for a fixes file for this game at $_gf_url"
        rm -f "$_gf_file"
        # No -f, so the status code tells "no file for this game" (404) from a real failure
        _gf_code=$(curl -Ls --max-time 15 -o "$_gf_file" -w '%{http_code}' \
            -H "User-Agent: $HTTP_USER_AGENT" "$_gf_url")
        _gf_exit=$?
        case "$_gf_exit:$_gf_code" in
            0:200)
                log_info "Game fixes: got the file"
                ;;
            0:404)
                rm -f "$_gf_file"
                log_info "Game fixes: none for this game"
                return 0
                ;;
            *)
                rm -f "$_gf_file"
                log_info "Game fixes: couldn't get the file (curl exit $_gf_exit, HTTP $_gf_code), going on without them"
                return 0
                ;;
        esac
    fi

    _gf_parsed=$(parse_game_fixes "$_gf_file")
    _gf_count=0
    _gf_names=''
    _gf_reg_count=0
    while IFS='|' read -r _gf_a _gf_b _gf_c _gf_d _gf_e; do
        # The pinned Proton build has an empty first field (see parse_game_fixes)
        if [ -z "$_gf_a" ] && [ "$_gf_b" = 'proton' ]; then
            GAME_FIXES_PROTON=$_gf_c
            GAME_FIXES_PROTON_ASSET=$_gf_d
            GAME_FIXES_PROTON_SHA512=$_gf_e
            continue
        fi
        [ -n "$_gf_a" ] || continue
        if [ "$_gf_a" = '!' ]; then
            log_warning "Game fixes: ignoring \"$_gf_b\": $_gf_c"
            continue
        fi
        if [ "$_gf_a" = '@' ]; then
            GAME_FIXES_REGISTRY="$GAME_FIXES_REGISTRY$_gf_b|$_gf_c|$_gf_d|$_gf_e$_gf_nl"
            _gf_reg_count=$((_gf_reg_count+1))
            continue
        fi
        GAME_FIXES="$GAME_FIXES$_gf_a|$_gf_b|$_gf_c|$_gf_d|$_gf_e$_gf_nl"
        _gf_count=$((_gf_count+1))
        _gf_names="${_gf_names:+$_gf_names, }\"$_gf_a\""
    done <<EOL
$_gf_parsed
EOL
    if [ $_gf_count -gt 0 ]; then
        log_info "Game fixes: $_gf_count launcher(s) for this game: $_gf_names"
    elif [ -z "$GAME_FIXES_PROTON" ] && [ $_gf_reg_count -eq 0 ]; then
        log_info "Game fixes: nothing usable in the file"
    fi
    if [ $_gf_reg_count -gt 0 ]; then
        log_info "Game fixes: $_gf_reg_count registry value(s) for this game"
    fi
    if [ -n "$GAME_FIXES_PROTON" ]; then
        log_info "Game fixes: this game is pinned to $GAME_FIXES_PROTON"
    fi
}

# Sets the registry values of the game's fixes file. It runs after the installer, whose own
# [Registry] entries (the game's key and paths) are written during the install. One umu call
# runs a .bat of "reg add" lines. Every value passed parse_game_fixes, so none can break a line.
apply_game_fix_registry() {
    [ -n "$GAME_FIXES_REGISTRY" ] || return 0
    _rg_bat="$INSTALL_PATH/drive_c/zoom_gamefixes.bat"
    _rg_count=0
    if ! printf '@echo off\n' > "$_rg_bat"; then
        log_warning "Game fixes: couldn't write $_rg_bat, the registry values are not set"
        return 0
    fi
    while IFS='|' read -r _rg_key _rg_name _rg_type _rg_data; do
        [ -n "$_rg_key" ] || continue
        case $_rg_type in
            dword) _rg_regtype=REG_DWORD ;;
            *) _rg_regtype=REG_SZ ;;
        esac
        printf 'reg add "%s" /v "%s" /t %s /d "%s" /f\n' "$_rg_key" "$_rg_name" "$_rg_regtype" "$_rg_data" >> "$_rg_bat"
        _rg_count=$((_rg_count+1))
    done <<EOL
$GAME_FIXES_REGISTRY
EOL
    log_info "Game fixes: setting $_rg_count registry value(s)..."
    if ! umu_launch start "C:\\zoom_gamefixes.bat"; then
        log_warning "Game fixes: setting the registry values failed"
    fi
}

# Prints the SHA-512 of a file, with whichever tool the system has
get_sha512() {
    if command -v sha512sum > /dev/null; then
        sha512sum "$1" | cut -d ' ' -f1
    elif command -v openssl > /dev/null; then
        openssl dgst -sha512 "$1" | sed 's/^.*= //'
    else
        return 1
    fi
}

# Downloads a pinned Proton build into $PROTON_COMPAT_DIR, checked against the SHA-512 from
# the fixes file. Unpacked next to its final place and moved in whole, so a half-unpacked
# folder is never taken for a finished one. Warns and returns 1 if it can't be had.
# $1: release tag, $2: asset (tarball name), $3: its SHA-512
download_pinned_proton() {
    _dp_tag=$1
    _dp_asset=$2
    _dp_sha=$3
    # GE-Proton tarballs hold one folder named after the tarball (also umu's own naming)
    _dp_name=${_dp_asset%.tar.gz}
    _dp_dir="$PROTON_COMPAT_DIR/$_dp_name"
    _dp_file="$CACHE_DIR/$_dp_asset"

    if ! command -v tar > /dev/null; then
        log_warning "Pinned Proton: tar was not found on this system"
        return 1
    fi
    if ! mkdir -p "$CACHE_DIR" "$PROTON_COMPAT_DIR"; then
        log_warning "Pinned Proton: couldn't create $PROTON_COMPAT_DIR"
        return 1
    fi

    log_info "Pinned Proton: downloading $_dp_asset (only needed the first time)..."
    rm -f "$_dp_file"
    # --fail so an error page isn't saved as the tarball; the speed limit gives up on a stalled
    # connection (there's no overall time limit on a big download)
    if ! curl -L --fail --progress-bar --connect-timeout 15 --speed-limit 1024 --speed-time 60 \
            -H "User-Agent: $HTTP_USER_AGENT" -o "$_dp_file" "$PROTON_GE_URL/$_dp_tag/$_dp_asset"; then
        rm -f "$_dp_file"
        log_warning "Pinned Proton: couldn't download $PROTON_GE_URL/$_dp_tag/$_dp_asset"
        return 1
    fi
    if [ "$(get_sha512 "$_dp_file")" != "$_dp_sha" ]; then
        rm -f "$_dp_file"
        log_warning "Pinned Proton: $_dp_asset doesn't match the checksum in the game fixes file, not using it"
        return 1
    fi

    log_info "Pinned Proton: checksum OK, unpacking..."
    _dp_tmp=$(mktemp -d "$PROTON_COMPAT_DIR/.zoom-unpack.XXXXXX") || {
        rm -f "$_dp_file"
        log_warning "Pinned Proton: couldn't create a folder in $PROTON_COMPAT_DIR"
        return 1
    }
    if ! tar -xzf "$_dp_file" -C "$_dp_tmp" || [ ! -f "$_dp_tmp/$_dp_name/toolmanifest.vdf" ]; then
        rm -rf "$_dp_tmp" "$_dp_file"
        log_warning "Pinned Proton: couldn't unpack $_dp_asset"
        return 1
    fi
    rm -f "$_dp_file"
    # Marks the build as ours, so the cleanup never touches a copy someone else installed
    # (ProtonUp-Qt, a Steam game). Written before the mv: the note and the folder appear together.
    printf '%s\n' "Downloaded by zoom-platform-darth.sh $INSTALLER_VERSION" > "$_dp_tmp/$_dp_name/$PROTON_NOTE"

    # Another install may have finished this build meanwhile, then use its copy. mv would put
    # ours inside an existing folder, so remove that if the race happens.
    if [ ! -e "$_dp_dir" ]; then
        mv "$_dp_tmp/$_dp_name" "$_dp_dir" 2> /dev/null
        [ -d "$_dp_dir/$_dp_name" ] && rm -rf "${_dp_dir:?}/$_dp_name"
    fi
    rm -rf "$_dp_tmp"
    if [ ! -f "$_dp_dir/toolmanifest.vdf" ]; then
        log_warning "Pinned Proton: couldn't move $_dp_name into $PROTON_COMPAT_DIR"
        return 1
    fi
    return 0
}

# Picks the Proton build for this game and makes sure it's there: the fixes file's, else the
# prefix's (drive_c/zoom_proton, so a DLC or reinstall keeps the base game's), else none (umu
# decides). Sets ZOOM_PROTONPATH and exports PROTONPATH when pinned. Failing to get it is
# never fatal.
ensure_pinned_proton() {
    ZOOM_PROTONPATH=''
    _pp_marker="$INSTALL_PATH/drive_c/zoom_proton"
    _pp_name=''
    _pp_sha=''

    if [ -n "$GAME_FIXES_PROTON" ]; then
        _pp_name=${GAME_FIXES_PROTON_ASSET%.tar.gz}
        _pp_sha=$GAME_FIXES_PROTON_SHA512
    elif [ -f "$_pp_marker" ]; then
        read -r _pp_name _pp_sha < "$_pp_marker"
        # The name ends up in a path, so same check as in the fixes file (no regex group: expr exits
        # 1 when the group matches nothing)
        _pp_base=${_pp_name%-x86_64}
        if ! expr "$_pp_base" : '^GE-Proton[0-9][0-9]*-[0-9][0-9]*$' > /dev/null; then
            _pp_name=''
        fi
    fi
    [ -n "$_pp_name" ] || return 0

    # The path goes into launch scripts and the Flatpak, which can't carry spaces or shell chars
    case $PROTON_COMPAT_DIR in
        *[!A-Za-z0-9._/+-]*)
            log_warning "Pinned Proton: $PROTON_COMPAT_DIR has characters that can't be used, going on with umu's own Proton"
            return 0
            ;;
    esac

    _pp_path="$PROTON_COMPAT_DIR/$_pp_name"
    if [ -f "$_pp_path/toolmanifest.vdf" ]; then
        log_info "Pinned Proton: $_pp_name is already installed"
    elif [ -n "$GAME_FIXES_PROTON" ]; then
        if ! download_pinned_proton "$GAME_FIXES_PROTON" "$GAME_FIXES_PROTON_ASSET" "$GAME_FIXES_PROTON_SHA512"; then
            log_warning "Pinned Proton: going on with umu's own Proton"
            return 0
        fi
    else
        log_warning "Pinned Proton: this prefix was made with $_pp_name, which isn't installed any more. Going on with umu's own Proton"
        return 0
    fi

    ZOOM_PROTONPATH=$_pp_path
    export PROTONPATH="$ZOOM_PROTONPATH"
    mkdir -p "$INSTALL_PATH/drive_c"
    printf '%s %s\n' "$_pp_name" "$_pp_sha" > "$_pp_marker"
    log_info "Pinned Proton: this game runs on $_pp_name"
}

# Prints the GE-Proton builds that this script downloaded (they hold the $PROTON_NOTE file) and
# that no game needs any more, one folder name per line. $1: a prefix to leave out, the one
# being uninstalled. A build is kept when a ZOOM game's prefix names it in drive_c/zoom_proton,
# or when Steam's config.vdf mentions it (read only; the shared folder may hold a Steam game's
# build). A launcher link that leads nowhere may be a game on a disk that isn't mounted and
# could need any build, so then nothing is printed. Same text in uninstall.sh: keep them equal.
find_unused_protons() {
    # Physical path, so a trailing slash or a symlink in the path still matches
    _fu_skip=''
    if [ -n "$1" ]; then
        _fu_skip=$(cd "$1" 2> /dev/null && pwd -P)
    fi
    _fu_used=''
    for _fu_link in "$LAUNCH_SCRIPTS_PATH"/*/*.sh; do
        [ -L "$_fu_link" ] || continue
        _fu_target=$(readlink "$_fu_link")
        _fu_prefix=${_fu_target%/drive_c/zoom_shortcuts/*}
        if [ -n "$_fu_skip" ] && [ "$(cd "$_fu_prefix" 2> /dev/null && pwd -P)" = "$_fu_skip" ]; then
            continue
        fi
        if [ "$_fu_prefix" = "$_fu_target" ] || [ ! -e "$_fu_target" ]; then
            return 0
        fi
        if [ -f "$_fu_prefix/drive_c/zoom_proton" ]; then
            _fu_name=$(head -n 1 "$_fu_prefix/drive_c/zoom_proton" | cut -d ' ' -f1)
            _fu_used="$_fu_used $_fu_name"
        fi
    done

    _fu_vdf=${PROTON_COMPAT_DIR%/compatibilitytools.d}/config/config.vdf
    for _fu_dir in "$PROTON_COMPAT_DIR"/GE-Proton*; do
        if [ -L "$_fu_dir" ] || [ ! -f "$_fu_dir/$PROTON_NOTE" ]; then
            continue
        fi
        _fu_name=${_fu_dir##*/}
        case $_fu_name in
            *[!A-Za-z0-9._+-]*) continue ;;
        esac
        case "$_fu_used " in
            *" $_fu_name "*) continue ;;
        esac
        if [ -f "$_fu_vdf" ]; then
            # The tool's internal name, the first quoted word after compat_tools
            _fu_int=$(awk '/"compat_tools"/ {f = 1; next} f && match($0, /"[^"]+"/) {print substr($0, RSTART + 1, RLENGTH - 2); exit}' "$_fu_dir/compatibilitytool.vdf" 2> /dev/null)
            if grep -F -q "\"$_fu_name\"" "$_fu_vdf" 2> /dev/null; then
                continue
            fi
            if [ -n "$_fu_int" ] && grep -F -q "\"$_fu_int\"" "$_fu_vdf" 2> /dev/null; then
                continue
            fi
        fi
        printf '%s\n' "$_fu_name"
    done
}

# Prints the launch script lines for a pinned game (nothing otherwise). The folder is shared
# and tools like ProtonUp-Qt can delete it, so the script checks it's still there, else starts
# on umu's own Proton and says so. A launch never downloads anything.
pinned_proton_launch_lines() {
    [ -n "$ZOOM_PROTONPATH" ] || return 0
    _pl_msg=$(quote_sq "${ZOOM_PROTONPATH##*/} (pinned for $GAME_NAME_SAFE) was removed, so the default Proton is used. Reinstall the game (it needs internet) to get it back.")
    _pl_title=$(quote_sq "$GAME_NAME_SAFE")
    # Build name without the architecture, to keep the notification short
    _pl_ver=${ZOOM_PROTONPATH##*/}
    _pl_note=$(quote_sq "${_pl_ver%-x86_64} removed. Reinstall the game.")
    # The terminal message goes unseen when launched from the menu, so it's also shown on the
    # desktop with the first tool that works (Pop!_OS has no notify-send): notify-send, gdbus,
    # dbus-send, kdialog, zenity (backgrounded, so it doesn't hold up the game). Notifications
    # get a short text since GNOME shows about 40 characters; only zenity shows the full message.
    printf '%s\n' \
        "# This game is pinned to a tested Proton build. If that folder was removed, umu's own" \
        "# Proton is used instead. Nothing is downloaded here." \
        "if [ -f '$ZOOM_PROTONPATH/toolmanifest.vdf' ]; then" \
        "    export PROTONPATH='$ZOOM_PROTONPATH'" \
        "else" \
        "    msg='$_pl_msg'" \
        "    title='$_pl_title'" \
        "    note='$_pl_note'" \
        "    printf '%s\\n' \"\$msg\" >&2" \
        "    { command -v notify-send > /dev/null 2>&1 && notify-send \"\$title\" \"\$note\" > /dev/null 2>&1; } ||" \
        "    { command -v gdbus > /dev/null 2>&1 && gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify zoom-platform 0 '' \"\$title\" \"\$note\" '[]' '{}' 15000 > /dev/null 2>&1; } ||" \
        "    { command -v dbus-send > /dev/null 2>&1 && dbus-send --session --dest=org.freedesktop.Notifications --type=method_call /org/freedesktop/Notifications org.freedesktop.Notifications.Notify string:zoom-platform uint32:0 string: \"string:\$title\" \"string:\$note\" array:string: dict:string:string: int32:15000 > /dev/null 2>&1; } ||" \
        "    { command -v kdialog > /dev/null 2>&1 && kdialog --title \"\$title\" --passivepopup \"\$note\" 15 > /dev/null 2>&1; } ||" \
        "    { command -v zenity > /dev/null 2>&1 && zenity --warning --title=\"\$title\" --no-wrap --timeout=20 --text=\"\$(printf '%s' \"\$msg\" | fold -s -w 70)\" > /dev/null 2>&1 & }" \
        "fi"
}

# Writes a launch script and, unless desktop entries are off, its menu entry.
# $1 launcher name (file name), $2 menu entry name, $3 working dir, $4 exe (Windows paths
# with doubled backslashes, since they sit between double quotes), $5 args (unquoted in the
# script), $6 icon file (may be empty), $7 StartupWMClass, $8 the installer shortcut this is
# for (Desktop link)
make_launcher() {
    _ml_filename=$1
    _ml_name=$2
    _ml_workingdir=$3
    _ml_exe=$4
    _ml_args=$5
    _ml_iconpath=$6
    _ml_wmclass=$7
    _ml_shortcut=$8

    # Empty unless the game is pinned to a Proton build
    _ml_pin=$(pinned_proton_launch_lines)
    _ml_nl='
'
    cat >"$ZOOM_SHORTCUTS_PATH/$_ml_filename.sh" <<EOL
#!/bin/sh
export GAMEID="$UMU_ID"
export WINEPREFIX="$INSTALL_PATH"
export STORE="zoomplatform"
${_ml_pin:+$_ml_pin$_ml_nl}$(umu_launch_command) start /b /d "$_ml_workingdir" "$_ml_exe" $_ml_args
EOL
    chmod +x "$ZOOM_SHORTCUTS_PATH/$_ml_filename.sh"
    LAUNCHERS_MADE=$((LAUNCHERS_MADE+1))
    LAUNCHER_MAP="$LAUNCHER_MAP$_ml_shortcut|$_ml_filename$_nl"

    # Desktop entries handle special characters badly, so the entry points at a script symlinked
    # under a plain path
    if [ "$CREATE_DESKTOP_ENTRIES" -eq 1 ]; then
        _ml_desktopfile="$ZOOM_SHORTCUTS_PATH/$_ml_filename.desktop"
        _ml_fsum=$(printf '%s' "$_ml_filename" | cksum | cut -d ' ' -f1)

        mkdir -p "$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID/"
        ln -sf "$ZOOM_SHORTCUTS_PATH/$_ml_filename.sh" "$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID/$_ml_fsum.sh"

        cat >"$_ml_desktopfile" <<EOL
[Desktop Entry]
Name=$_ml_name
Exec=$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID/$_ml_fsum.sh
${_ml_iconpath:+Icon=$_ml_iconpath}
StartupWMClass=$_ml_wmclass
Terminal=false
Type=Application
Categories=Game
X-KDE-RunOnDiscreteGpu=true
EOL
        log_info "Creating \"$APPLICATIONS_PATH/$_ml_name.desktop\""
        desktop-file-install --delete-original --dir="$APPLICATIONS_PATH" "$_ml_desktopfile"
        chmod +x "$APPLICATIONS_PATH/$_ml_name.desktop"
    fi
}

# Makes the launchers a game's fixes file has for an installer shortcut, in its place.
# Returns 0 if any were made; 1 if none apply or none could be made (say the exe isn't where
# the file expects), and then the caller makes the shortcut's own launcher.
# $1 shortcut name, $2 its target as parse_lnk prints it (the file's exe and workdir start
# from it), $3 icon file (may be empty)
make_fixed_launchers() {
    _fx_shortcut=$1
    _fx_target=$(printf '%s' "$2" | sed 's/\\\\/\\/g') # plain backslashes, for umu
    _fx_icon=$3
    _fx_base=${_fx_target%\\*} # the folder of the shortcut's target
    _fx_matched=0
    _fx_made=0

    while IFS='|' read -r _fx_name _fx_replaces _fx_exe _fx_workdir _fx_args; do
        [ -n "$_fx_name" ] || continue
        [ "$_fx_replaces" = "$_fx_shortcut" ] || continue
        _fx_matched=$((_fx_matched+1))

        # Skip launchers for missing files. umu gets /dev/null so it can't swallow the rest of the fixes.
        _fx_winexe="$_fx_base\\$_fx_exe"
        _fx_native=$( (PROTON_VERB=getnativepath umu_launch "$_fx_winexe" < /dev/null) 2> /dev/null | head -n 1)
        if [ ! -f "$_fx_native" ]; then
            log_warning "Game fix \"$_fx_name\": \"$_fx_winexe\" isn't there, skipping it"
            continue
        fi
        _fx_winworkdir=$_fx_base
        [ -n "$_fx_workdir" ] && _fx_winworkdir="$_fx_base\\$_fx_workdir"
        # What wine calls the game's window, which is what the menu entry has to match
        _fx_exename=${_fx_exe##*\\}
        _fx_wmclass=$(printf '%s' "$_fx_exename" | tr '[:upper:]' '[:lower:]')

        log_info "Game fix: making \"$_fx_name\" in place of \"$_fx_shortcut\""
        make_launcher "$_fx_name" "$_fx_name" \
            "$(printf '%s' "$_fx_winworkdir" | sed 's/\\/\\\\/g')" \
            "$(printf '%s' "$_fx_winexe" | sed 's/\\/\\\\/g')" \
            "$_fx_args" "$_fx_icon" "$_fx_wmclass" "$_fx_shortcut"
        _fx_made=$((_fx_made+1))
    done <<EOL
$GAME_FIXES
EOL

    if [ $_fx_made -gt 0 ]; then
        return 0
    fi
    if [ $_fx_matched -gt 0 ]; then
        log_warning "Game fixes: none of the launchers for \"$_fx_shortcut\" could be made, keeping its own"
    fi
    return 1
}

# Writes uninstall.sh: a preamble of single-quoted assignments baking in this install's paths
# (via quote_sq, so odd characters can't break it) and a static quoted heredoc that does the
# work.
# $1: every applications-menu group ever installed into this prefix, one per line
write_uninstaller() {
    _wu_groups=$1

    # A non-DLC install's name titles the uninstaller (DLC installs never touch this marker)
    if [ "$IS_DLC" -eq 0 ]; then
        printf '%s\n' "$GAME_NAME_SAFE" > "$INSTALL_PATH/drive_c/zoom_base_game"
    fi

    _wu_title=""
    if [ -r "$INSTALL_PATH/drive_c/zoom_base_game" ]; then
        _wu_title=$(head -n 1 "$INSTALL_PATH/drive_c/zoom_base_game")
    elif [ "$IS_DLC" -eq 0 ]; then
        _wu_title=$GAME_NAME_SAFE
    else
        # A DLC over an older prefix has no marker: if exactly one other group exists, it's the base game
        _wu_other=""
        _wu_other_count=0
        while IFS= read -r _wu_g; do
            [ -n "$_wu_g" ] || continue
            [ "$_wu_g" = "$GAME_NAME_SAFE" ] && continue
            _wu_other=$_wu_g
            _wu_other_count=$((_wu_other_count + 1))
        done <<EOL
$_wu_groups
EOL
        [ "$_wu_other_count" -eq 1 ] && _wu_title=$_wu_other
    fi

    mkdir -p "$INSTALL_PATH/drive_c"
    {
        printf '#!/bin/sh\n'
        printf '# Generated by zoom-platform-darth.sh %s. Deleted along with everything else.\n' "$INSTALLER_VERSION"
        printf "GAME_TITLE='%s'\n" "$(quote_sq "$_wu_title")"
        printf "ICON_GROUPS='%s'\n" "$(quote_sq "$_wu_groups")"
        printf "DESKTOP_DIR='%s'\n" "$(quote_sq "$DESKTOP_DIR")"
        printf "APPLICATIONS_ROOT='%s'\n" "$(quote_sq "$APPLICATIONS_ROOT")"
        printf "WINE_MENU_ROOT='%s'\n" "$(quote_sq "$WINE_MENU_ROOT")"
        printf "LAUNCH_SCRIPTS_PATH='%s'\n" "$(quote_sq "$LAUNCH_SCRIPTS_PATH")"
        printf "PROTON_COMPAT_DIR='%s'\n" "$(quote_sq "$PROTON_COMPAT_DIR")"
        printf "PROTON_NOTE='%s'\n" "$(quote_sq "$PROTON_NOTE")"
        printf "ZOOM_GUID='%s'\n" "$(quote_sq "$ZOOM_GUID")"
        printf "INSTALL_PATH='%s'\n" "$(quote_sq "$INSTALL_PATH")"
        # Everything below is static, so the heredoc is quoted
        cat <<'EOL'
uninstall_usage() {
    printf 'Usage: sh uninstall.sh [-y | --yes] [--remove-unused-proton]\n\n'
    printf '  -y, --yes                Remove the game without asking. Its GE-Proton version is kept\n'
    printf '                           unless --remove-unused-proton is also given.\n'
    printf '  --remove-unused-proton   Also remove the GE-Proton version this game uses, without\n'
    printf '                           asking, when no other game uses it.\n'
    printf '  -h, --help               Show this help.\n'
}

_opt_yes=0
_opt_remove_proton=0
for _arg in "$@"; do
    case $_arg in
        -y | --yes) _opt_yes=1 ;;
        --remove-unused-proton) _opt_remove_proton=1 ;;
        -h | --help)
            uninstall_usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$_arg" >&2
            uninstall_usage >&2
            exit 2
            ;;
    esac
done

cd / 2>/dev/null || true

# Colours only on a terminal, unless NO_COLOR is set
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    _c_ok=$(printf '\033[32m')
    _c_title=$(printf '\033[32;1m')
    _c_warn=$(printf '\033[33;1m')
    _c_err=$(printf '\033[31;1m')
    _c_off=$(printf '\033[0m')
else
    _c_ok=''
    _c_title=''
    _c_warn=''
    _c_err=''
    _c_off=''
fi

# Replaces a leading $HOME with ~ for display. Built from two printf args so ShellCheck
# doesn't expand the ~
show_path() {
    case "$1" in
        "$HOME"/*) printf '%s/%s' '~' "${1#"$HOME"/}" ;;
        "$HOME") printf '~' ;;
        *) printf '%s' "$1" ;;
    esac
}

_failures=0
say_removed() { printf '  %sremoved%s  %s\n' "$_c_ok" "$_c_off" "$(show_path "$1")"; }
say_kept()    { printf '  %skept%s     %s (%s)\n' "$_c_warn" "$_c_off" "$(show_path "$1")" "$2"; }
say_failed()  { printf '  %sFAILED%s   %s\n' "$_c_err" "$_c_off" "$(show_path "$1")"; _failures=$((_failures + 1)); }

# Waits for a keypress so a file manager's terminal window doesn't close before the result can
# be read, only when stdin is a terminal. Ctrl+C still works; a trap restores the terminal.
wait_for_key() {
    [ -t 0 ] || return 0
    printf 'Press any key to close...'
    if ! _wfk_tty=$(stty -g 2>/dev/null); then
        read -r _wfk_dummy
        printf '\n'
        return 0
    fi
    trap 'stty "$_wfk_tty" 2>/dev/null; exit 130' INT TERM
    stty -icanon -echo min 1 time 0 2>/dev/null
    dd bs=1 count=1 2>/dev/null >/dev/null
    # Drain the rest of a multi-byte key (arrows) so it doesn't reach the shell prompt
    stty min 0 time 1 2>/dev/null
    dd bs=1 count=8 2>/dev/null >/dev/null
    stty "$_wfk_tty" 2>/dev/null
    trap - INT TERM
    printf '\n'
}

# Prints the GE-Proton builds that this script downloaded (they hold the $PROTON_NOTE file) and
# that no game needs any more, one folder name per line. $1: a prefix to leave out, the one
# being uninstalled. A build is kept when a ZOOM game's prefix names it in drive_c/zoom_proton,
# or when Steam's config.vdf mentions it (read only; the shared folder may hold a Steam game's
# build). A launcher link that leads nowhere may be a game on a disk that isn't mounted and
# could need any build, so then nothing is printed. Same text in uninstall.sh: keep them equal.
find_unused_protons() {
    # Physical path, so a trailing slash or a symlink in the path still matches
    _fu_skip=''
    if [ -n "$1" ]; then
        _fu_skip=$(cd "$1" 2> /dev/null && pwd -P)
    fi
    _fu_used=''
    for _fu_link in "$LAUNCH_SCRIPTS_PATH"/*/*.sh; do
        [ -L "$_fu_link" ] || continue
        _fu_target=$(readlink "$_fu_link")
        _fu_prefix=${_fu_target%/drive_c/zoom_shortcuts/*}
        if [ -n "$_fu_skip" ] && [ "$(cd "$_fu_prefix" 2> /dev/null && pwd -P)" = "$_fu_skip" ]; then
            continue
        fi
        if [ "$_fu_prefix" = "$_fu_target" ] || [ ! -e "$_fu_target" ]; then
            return 0
        fi
        if [ -f "$_fu_prefix/drive_c/zoom_proton" ]; then
            _fu_name=$(head -n 1 "$_fu_prefix/drive_c/zoom_proton" | cut -d ' ' -f1)
            _fu_used="$_fu_used $_fu_name"
        fi
    done

    _fu_vdf=${PROTON_COMPAT_DIR%/compatibilitytools.d}/config/config.vdf
    for _fu_dir in "$PROTON_COMPAT_DIR"/GE-Proton*; do
        if [ -L "$_fu_dir" ] || [ ! -f "$_fu_dir/$PROTON_NOTE" ]; then
            continue
        fi
        _fu_name=${_fu_dir##*/}
        case $_fu_name in
            *[!A-Za-z0-9._+-]*) continue ;;
        esac
        case "$_fu_used " in
            *" $_fu_name "*) continue ;;
        esac
        if [ -f "$_fu_vdf" ]; then
            # The tool's internal name, the first quoted word after compat_tools
            _fu_int=$(awk '/"compat_tools"/ {f = 1; next} f && match($0, /"[^"]+"/) {print substr($0, RSTART + 1, RLENGTH - 2); exit}' "$_fu_dir/compatibilitytool.vdf" 2> /dev/null)
            if grep -F -q "\"$_fu_name\"" "$_fu_vdf" 2> /dev/null; then
                continue
            fi
            if [ -n "$_fu_int" ] && grep -F -q "\"$_fu_int\"" "$_fu_vdf" 2> /dev/null; then
                continue
            fi
        fi
        printf '%s\n' "$_fu_name"
    done
}

if [ -n "$GAME_TITLE" ]; then
    _title_line="$GAME_TITLE - Uninstall"
else
    _title_line="Uninstall"
fi
printf '%s%s%s\n' "$_c_title" "$_title_line" "$_c_off"
printf '%s\n' "$(printf '%s' "$_title_line" | sed 's/./=/g')"
printf '\n'

# Other groups in this prefix (base game + DLC), so the user sees what else goes
_other_groups=''
while IFS= read -r _g; do
    [ -n "$_g" ] || continue
    [ "$_g" = "$GAME_TITLE" ] && continue
    _other_groups="$_other_groups$_g
"
done <<GRPEOF
$ICON_GROUPS
GRPEOF

if [ -n "$_other_groups" ]; then
    if [ -n "$GAME_TITLE" ]; then
        printf 'Also removes, same prefix:\n'
    else
        printf 'Removes, same prefix:\n'
    fi
    while IFS= read -r _g; do
        [ -n "$_g" ] && printf '  %s\n' "$_g"
    done <<GRPEOF
$_other_groups
GRPEOF
    printf '\n'
fi

# Preview of what exists, buffered to choose between "This will delete:" and "Nothing left"
_preview=''
_savegames_needed=0
if [ -d "$INSTALL_PATH" ]; then
    _du_kb=$(du -sk "$INSTALL_PATH" 2>/dev/null | cut -f1)
    _size=$(awk -v k="${_du_kb:-0}" 'BEGIN {
        b = k * 1024
        if (b >= 1073741824) printf "%.2f GB", b / 1073741824
        else if (b >= 1048576) printf "%.2f MB", b / 1048576
        else printf "%.0f KB", b / 1024
    }')
    _preview="$_preview$(printf '  %-17s%s (%s)' 'Install folder' "$(show_path "$INSTALL_PATH")" "$_size")
"
    _savegames_needed=1
fi
while IFS= read -r _group; do
    [ -n "$_group" ] || continue
    if [ -d "$APPLICATIONS_ROOT/$_group" ]; then
        _preview="$_preview$(printf '  %-17s%s' 'Menu entries' "$(show_path "$APPLICATIONS_ROOT/$_group")")
"
    fi
done <<GRPEOF
$ICON_GROUPS
GRPEOF
while IFS= read -r _group; do
    [ -n "$_group" ] || continue
    for _desktopfile in "$DESKTOP_DIR"/*.desktop; do
        [ -L "$_desktopfile" ] || continue
        case "$(readlink "$_desktopfile")" in
            "$APPLICATIONS_ROOT/$_group"/*)
                _preview="$_preview$(printf '  %-17s%s' 'Desktop link' "$(show_path "$_desktopfile")")
"
                ;;
        esac
    done
done <<GRPEOF
$ICON_GROUPS
GRPEOF
if [ -d "$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID" ]; then
    _preview="$_preview$(printf '  %-17s%s' 'Launch scripts' "$(show_path "$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID")")
"
fi

# The GE-Proton build this game runs on is offered separately (after the game's own y/N), but
# only when this script downloaded it and no other game needs it
_proton_name=''
_pn=''
if [ -f "$INSTALL_PATH/drive_c/zoom_proton" ]; then
    _pn=$(head -n 1 "$INSTALL_PATH/drive_c/zoom_proton" | cut -d ' ' -f1)
    _unused=$(find_unused_protons "$INSTALL_PATH" | tr '\n' ' ')
    case " $_unused" in
        *" $_pn "*) [ -n "$_pn" ] && _proton_name=$_pn ;;
    esac
fi
_proton_mb=0
_proton_label=$_proton_name
if [ -n "$_proton_name" ]; then
    _du_kb=$(du -sk "$PROTON_COMPAT_DIR/$_proton_name" 2>/dev/null | cut -f1)
    _proton_mb=$(( ${_du_kb:-0} / 1024 ))
    # Without the architecture, to read better: GE-Proton11-7
    _proton_label=${_proton_name%-x86_64}
fi

if [ -z "$_preview" ]; then
    printf 'Nothing left to remove.\n'
    wait_for_key
    exit 0
fi

printf 'This will delete:\n'
printf '%s' "$_preview"
printf '\n'
[ "$_savegames_needed" -eq 1 ] && printf 'Save games stored inside the install folder are deleted too.\n'
if [ -n "$_proton_name" ]; then
    if [ "$_opt_remove_proton" -eq 1 ]; then
        printf '%s (%s MB) will be removed too, since no other game uses it.\n' "$_proton_label" "$_proton_mb"
    elif [ "$_opt_yes" -eq 1 ]; then
        printf '%s (%s MB) is kept. Add --remove-unused-proton to remove it too.\n' "$_proton_label" "$_proton_mb"
    else
        printf 'You will be asked separately about %s (%s MB), which no other game uses.\n' "$_proton_label" "$_proton_mb"
    fi
fi
if [ "$_opt_yes" -eq 1 ]; then
    printf 'Continue? [y/N] y (--yes)\n'
else
    printf 'Continue? [y/N] '
    read -r _in
    case $_in in
        [yY] | [yY][eE][sS]) ;;
        *)
            printf 'Cancelled, nothing was removed.\n'
            wait_for_key
            exit 0
            ;;
    esac
fi
printf '\n'

# Its own question, so the build can stay while the game goes. Anything but y, or no answer at
# all (piped input that ran out), keeps it.
_remove_proton=0
_keep_why='you chose to keep it'
if [ -n "$_proton_name" ]; then
    if [ "$_opt_remove_proton" -eq 1 ]; then
        _remove_proton=1
    elif [ "$_opt_yes" -eq 1 ]; then
        _keep_why='kept, add --remove-unused-proton to remove it'
    else
        printf 'No other game uses %s, and this script downloaded it.\n' "$_proton_label"
        printf 'Remove the remaining %s (%s MB)? [y/N] ' "$_proton_label" "$_proton_mb"
        _in=''
        read -r _in || :
        case $_in in
            [yY] | [yY][eE][sS]) _remove_proton=1 ;;
        esac
        printf '\n'
    fi
fi

while IFS= read -r _group; do
    [ -n "$_group" ] || continue
    for _desktopfile in "$DESKTOP_DIR"/*.desktop; do
        [ -L "$_desktopfile" ] || continue
        case "$(readlink "$_desktopfile")" in
            "$APPLICATIONS_ROOT/$_group"/*)
                rm -f "$_desktopfile" 2>/dev/null
                if [ -e "$_desktopfile" ] || [ -L "$_desktopfile" ]; then
                    say_failed "$_desktopfile"
                else
                    say_removed "$_desktopfile"
                fi
                ;;
        esac
    done
    if [ -e "$APPLICATIONS_ROOT/$_group" ]; then
        rm -rf "${APPLICATIONS_ROOT:?}/$_group" 2>/dev/null
        if [ -e "$APPLICATIONS_ROOT/$_group" ]; then
            say_failed "$APPLICATIONS_ROOT/$_group"
        else
            say_removed "$APPLICATIONS_ROOT/$_group"
        fi
    fi
    # Wine's own folder for this group is shared with other wine programs: only removed while empty
    if [ -d "$WINE_MENU_ROOT/$_group" ]; then
        rmdir "$WINE_MENU_ROOT/$_group" 2>/dev/null
        if [ -d "$WINE_MENU_ROOT/$_group" ]; then
            say_kept "$WINE_MENU_ROOT/$_group" "not empty"
        else
            say_removed "$WINE_MENU_ROOT/$_group"
        fi
    fi
done <<GRPEOF
$ICON_GROUPS
GRPEOF

if [ -d "$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID" ]; then
    rm -rf "${LAUNCH_SCRIPTS_PATH:?}/$ZOOM_GUID" 2>/dev/null
    if [ -e "$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID" ]; then
        say_failed "$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID"
    else
        say_removed "$LAUNCH_SCRIPTS_PATH/$ZOOM_GUID"
    fi
fi

if [ -e "$INSTALL_PATH" ]; then
    rm -rf "$INSTALL_PATH" 2>/dev/null
    if [ -e "$INSTALL_PATH" ]; then
        say_failed "$INSTALL_PATH"
    else
        say_removed "$INSTALL_PATH"
    fi
fi

if [ -n "$_proton_name" ] && [ -d "$PROTON_COMPAT_DIR/$_proton_name" ]; then
    if [ "$_remove_proton" -eq 1 ]; then
        rm -rf "${PROTON_COMPAT_DIR:?}/$_proton_name" 2>/dev/null
        if [ -e "$PROTON_COMPAT_DIR/$_proton_name" ]; then
            say_failed "$PROTON_COMPAT_DIR/$_proton_name"
        else
            say_removed "$PROTON_COMPAT_DIR/$_proton_name"
        fi
    else
        say_kept "$PROTON_COMPAT_DIR/$_proton_name" "$_keep_why"
    fi
elif [ "$_opt_remove_proton" -eq 1 ]; then
    # Asked for, but the rules say it stays: say so, or it would look like the option was ignored
    if [ -n "$_pn" ] && [ -d "$PROTON_COMPAT_DIR/$_pn" ]; then
        say_kept "$PROTON_COMPAT_DIR/$_pn" "still used by another game, or not downloaded by this script"
    else
        printf '  No GE-Proton version to remove for this game.\n'
    fi
fi

# Remove the now empty parents. Fails harmlessly while other games are installed.
rmdir "$APPLICATIONS_ROOT" "$LAUNCH_SCRIPTS_PATH" 2>/dev/null

printf '\n'
if [ "$_failures" -eq 0 ]; then
    if [ -n "$GAME_TITLE" ]; then
        printf 'Done: %s was uninstalled.\n' "$GAME_TITLE"
    else
        printf 'Done: everything was uninstalled.\n'
    fi
    wait_for_key
    exit 0
else
    printf '%sFinished with %d error(s)%s: the items marked FAILED are still there.\n' "$_c_err" "$_failures" "$_c_off"
    wait_for_key
    exit 1
fi
EOL
    } > "$INSTALL_PATH/uninstall.sh"
    chmod +x "$INSTALL_PATH/uninstall.sh"
}

show_usage() {
    printf 'Usage: zoom-platform-darth.sh [OPTIONS] INSTALLER DEST

Description:
  zoom-platform-darth.sh - Install Windows games from ZOOM Platform using umu and Proton.

Options:
  -h, --help           Display this help message and exit.
  -v, --version        Display the version information and exit.
  -i, --installer      Path to a ZOOM Platform installer .exe.
  -d, --dest           Path to where you want the game to install to.
  -o, --output         Alias for -d.
  -g, --guid INSTALLER Print the game ID (GUID) of an installer and exit. Installs nothing.
      --remove-unused-proton
                       Remove the GE-Proton versions this script downloaded that no
                       installed game uses any more, then exit. Asks first.
  -y, --yes            With --remove-unused-proton: do not ask, just remove them.

Arguments:
  INSTALLER            Path to a ZOOM Platform installer .exe.
  DEST                 Path to where you want the game to install to.

Examples:
  zoom-platform-darth.sh "Game-English-Setup-1.33.7.exe" ~/Games/new_game_dir
  zoom-platform-darth.sh -i "Game-English-Setup-1.33.7.exe" -d ~/Games/new_game_dir
  zoom-platform-darth.sh --guid "Game-English-Setup-1.33.7.exe"
  zoom-platform-darth.sh --remove-unused-proton
  zoom-platform-darth.sh --remove-unused-proton --yes

Note:
  - INSTALLER and DEST are optional if your environment can use KDialog or Zenity.
  - When the -i or -d options are used, they take priority over the arguments.
  - If updating a game or installing DLC, DEST should be the same path that the
    base game was installed in.
  - If you tick "Create a desktop shortcut" during setup, Desktop entries will be
    placed in: %s

Source & issues: %s
' "$DESKTOP_DIR" "$REPO_PATH"
}

INPUT_INSTALLER=""
INSTALL_PATH=""
GUID_INSTALLER=""
REMOVE_UNUSED_PROTON=0
ASSUME_YES=0

options=$(getopt -o hvi:d:o:g:y --long help,version,installer:,dest:,output:,guid:,remove-unused-proton,yes -n 'zoom-platform-darth.sh' -- "$@")

eval set -- "$options"

while true; do
  case "$1" in
    -h | --help )
        show_usage
        exit 0
        ;;
    -v | --version )
        printf '%s\n' $INSTALLER_VERSION
        exit 0
        ;;
    -i | --installer )
        INPUT_INSTALLER="$2" 
        shift 2
        ;;
    -d | --dest | -o | --output )
        INSTALL_PATH="$2"
        shift 2
        ;;
    -g | --guid )
        GUID_INSTALLER="$2"
        shift 2
        ;;
    --remove-unused-proton )
        REMOVE_UNUSED_PROTON=1
        shift
        ;;
    -y | --yes )
        ASSUME_YES=1
        shift
        ;;
    --) shift; break ;;
    *)
        fatal_error "Invalid option: $1"
    ;;
  esac
done

[ -z "$INPUT_INSTALLER" ] && INPUT_INSTALLER=$1

[ -z "$INSTALL_PATH" ] && INSTALL_PATH=$2

# --remove-unused-proton: lists the GE-Proton builds nothing needs any more and removes them after
# a y/N (--yes skips it, for scripts and cron: the question is read from the terminal itself, so
# piped input can't answer it). Needs no innoextract, umu or network. Terminal only, so errors
# are log_error + exit 1.
if [ "$REMOVE_UNUSED_PROTON" -eq 1 ]; then
    _rp_list=$(find_unused_protons '')
    if [ -z "$_rp_list" ]; then
        log_info "No GE-Proton version to remove: none that this script downloaded is unused."
        exit 0
    fi
    printf 'These GE-Proton versions were downloaded by this script and no game uses them:\n'
    while IFS= read -r _rp_name; do
        _rp_kb=$(du -sk "$PROTON_COMPAT_DIR/$_rp_name" 2> /dev/null | cut -f1)
        printf '  %s (%s MB)\n' "$PROTON_COMPAT_DIR/$_rp_name" "$(( ${_rp_kb:-0} / 1024 ))"
    done <<EOL
$_rp_list
EOL
    if [ "$ASSUME_YES" -eq 1 ]; then
        printf 'Removing them (--yes).\n'
    else
        # The terminal itself, so this also works when the script is piped into sh
        printf 'Remove them? [y/N] '
        _rp_in=''
        if ! read -r _rp_in 2> /dev/null < /dev/tty; then
            printf '\nNo terminal to ask on. Add --yes to remove them without asking.\n'
        fi
        case $_rp_in in
            [yY] | [yY][eE][sS]) ;;
            *)
                printf 'Cancelled, nothing was removed.\n'
                exit 0
                ;;
        esac
    fi
    _rp_failed=0
    while IFS= read -r _rp_name; do
        rm -rf "${PROTON_COMPAT_DIR:?}/$_rp_name" 2> /dev/null
        if [ -e "$PROTON_COMPAT_DIR/$_rp_name" ]; then
            log_error "Couldn't remove $PROTON_COMPAT_DIR/$_rp_name"
            _rp_failed=1
        else
            log_info "Removed $PROTON_COMPAT_DIR/$_rp_name"
        fi
    done <<EOL
$_rp_list
EOL
    exit $_rp_failed
fi

# Unpack innoextract into tmp
base64_dec "$(get_innoext_string)" > $INNOEXT_BIN
PAYLOAD_DECODED_STATUS=$?
[ $PAYLOAD_DECODED_STATUS -ne 0 ] && fatal_error "Could not decode base64." "Error unpacking innoextract"
if [ -s "$INNOEXT_BIN" ]; then
    chmod +x $INNOEXT_BIN
    $INNOEXT_BIN --version > /dev/null 2>&1 || fatal_error "Cannot launch $INNOEXT_BIN"
else
    fatal_error "Could not decode base64." "Error unpacking innoextract"
fi

# --guid: print the installer's game ID (lowercase, as fix files are named) and stop, before
# umu or any writes. The network is used only for an installer that has no ZOOM game ID. Only
# the ID goes to stdout.
if [ -n "$GUID_INSTALLER" ]; then
    if [ ! -r "$GUID_INSTALLER" ]; then
        log_error "Can't read \"$GUID_INSTALLER\"."
        exit 1
    fi
    if ! resolve_game_guid "$GUID_INSTALLER"; then
        log_error "\"$GUID_INSTALLER\" doesn't seem to be a ZOOM Platform installer."
        exit 1
    fi
    case $GAME_GUID_FROM in
        offline)
            log_error "\"$GUID_INSTALLER\" has no ZOOM Platform game ID inside, and the list of known ones couldn't be downloaded. Check the connection and try again."
            exit 1
            ;;
        appid)
            log_warning "\"$GUID_INSTALLER\" has no ZOOM Platform game ID inside and isn't in the list of known ones, so its Inno Setup AppId is printed. Please report the game: $REPO_PATH/issues"
            ;;
    esac
    printf '%s\n' "$GAME_GUID" | tr '[:upper:]' '[:lower:]'
    exit 0
fi

# Check if UMU is installed
if command -v umu-run > /dev/null; then
    UMU_BIN=umu-run
    log_info "Using umu native"
elif command -v "$HOME"/.local/share/umu/umu-run > /dev/null; then
    UMU_BIN="$HOME"/.local/share/umu/umu-run
    log_info "Using $HOME/.local/share/umu/umu-run"
elif command -v /usr/bin/umu-run > /dev/null; then
    UMU_BIN=/usr/bin/umu-run
    log_info "Using /usr/bin/umu-run"
elif flatpak info org.openwinecomponents.umu.umu-launcher >/dev/null 2>&1; then
    UMU_BIN="FLATPAK"
    log_info "Using umu Flatpak"
else
    _umu_url="$(get_umu_url)"
    download_umu_zipapp "$_umu_url"
fi

# If dialogs are usable and installer wasn't specified, show a dialog
if [ $CAN_USE_DIALOGS -eq 1 ] && [ -z "$INPUT_INSTALLER" ]; then
    INPUT_INSTALLER=$(dialog_installer_select)
    case $? in
        0)
            log_info "Selected \"$INPUT_INSTALLER\"";;
        1)
            fatal_error "No installer chosen.";;
        *)
            fatal_error "An unexpected error occurred when trying to choose an installer.";;
    esac
fi

# Show usage if can't use dialogs and no paths passed
if [ $CAN_USE_DIALOGS -eq 0 ]; then
    if [ -z "$INPUT_INSTALLER" ] || [ -z "$INSTALL_PATH" ]; then
        log_error "Cannot use dialogs, please specify INSTALLER and DEST."
        show_usage
        exit 1
    fi
fi

# Show an error if can't read installer
if ! test_file_perms r "$INPUT_INSTALLER" ; then
    _msg="Installer either does not exist or $([ "$UMU_BIN" = "FLATPAK" ] && printf "umu Flatpak does not have" || printf "no") read permissions."
    fatal_error "$_msg"
fi

# Validate and get some info from installer
if ! resolve_game_guid "$INPUT_INSTALLER"; then
    fatal_error "This doesn't seem to be a ZOOM Platform installer.
If you think this is an error, please submit a bug report:
$REPO_PATH/issues" "Invalid ZOOM Platform Installer"
fi
# Empty only when an old installer has no ZOOM game ID and the list couldn't be fetched; the
# prefix may still know it (see below)
ZOOM_GUID=$GAME_GUID
case $GAME_GUID_FROM in
    list)
        log_info "This installer has no ZOOM Platform game ID inside, using the one listed for it: $ZOOM_GUID";;
    appid)
        log_warning "This installer has no ZOOM Platform game ID inside and isn't in the list of known ones, so its Inno Setup AppId is used instead. The game installs fine, but umu can't tell which game it is. Please report it: $REPO_PATH/issues";;
esac

INSTALLER_INFO=$($INNOEXT_BIN -s --print-headers "$INPUT_INSTALLER")
get_header_val () {
    # Anchored so a key can't match the end of a longer one (file_count vs data_file_count)
    printf '%s' "$INSTALLER_INFO" | sed -n "s/^$1: \"\(.*\)\"/\1/p; s/^$1: \(.*\)/\1/p" # Handles with and without quotes
}

INNO_APPID=$(get_header_val 'app_id' | sed 's/[{}]//g') # Strip {{}

# Check if installer is for DLC
IS_DLC=0
[ "$(get_header_val 'default_dir_name')" = "{code:GetInstallationPath}" ] && IS_DLC=1

# Show installer info
printf "
Title: \033[32;1m%s\033[0m 
Publisher: \033[39;49;1m%s\033[0m
ZOOM Platform Version: \033[39;49;1m%s\033[0m
ZOOM Platform UUID: \033[39;49;1m%s\033[0m
IS DLC: \033[39;49;1m%s\033[0m
\n" \
"$(get_header_val 'app_name')" \
"$(get_header_val 'app_publisher')" \
"$(get_header_val 'app_version')" \
"${ZOOM_GUID:-unknown (no connection)}" \
"$([ "$IS_DLC" -eq 1 ] && printf "yes" || printf "no")"

# Split installers: make sure all the .bin files are there before anything is touched
check_installer_slices

# Open file selector if DEST wasn't given
if [ -z "$INSTALL_PATH" ]; then
    if [ $CAN_USE_DIALOGS -eq 1 ]; then
        # If DLC, ask user to select prefix where base game was installed
        if [ $IS_DLC -eq 1 ]; then
            dialog_msgbox info "DLC Installer Chosen" \
                "$(get_header_val 'app_name')\n\nSelect the same directory you chose when you installed the base game in the next prompt."
        fi

        printf "Select an installation directory\n"
        INSTALL_PATH=$(dialog_install_dir_select)
        case $? in
            0)
                log_info "Selected \"$INSTALL_PATH\"";;
            1)
                fatal_error "No install directory chosen.";;
            *)
                fatal_error "An unexpected error has occurred.";;
        esac
    else
        show_usage
        fatal_error 'No install directory specified'
    fi
fi

# Flatpak only: the destination may not exist yet, so its nearest existing folder is tested
if [ "$UMU_BIN" = "FLATPAK" ] && ! _dest_checked=$(test_dest_writable "$INSTALL_PATH"); then
    _nl='
'
    _msg="The umu Flatpak does not have write permissions to the install directory.$_nl$INSTALL_PATH"
    if [ "$_dest_checked" != "$INSTALL_PATH" ]; then
        _msg="$_msg${_nl}(it doesn't exist yet, so this was checked: $_dest_checked)"
    fi
    # Also prints the message in the terminal, not just in the popup
    fatal_error "$_msg" "No permissions"
fi

export WINEPREFIX="$INSTALL_PATH"
export GAMEID="zoominstall"

# An installer with no ZOOM game ID: the prefix remembers the ID its first install used, so a
# reinstall or DLC keeps it even offline (or if the list changes)
if [ "$GAME_GUID_FROM" != installer ]; then
    _zg_marker="$INSTALL_PATH/drive_c/zoom_guid"
    _zg_saved=''
    [ -f "$_zg_marker" ] && { read -r _zg_saved < "$_zg_marker" || :; }
    if validate_uuid "$_zg_saved"; then
        [ "$_zg_saved" = "$ZOOM_GUID" ] || log_info "Using the game ID saved in this prefix: $_zg_saved"
        ZOOM_GUID=$_zg_saved
    fi
    if [ -z "$ZOOM_GUID" ]; then
        fatal_error "This installer has no ZOOM Platform game ID inside, so it needs an internet connection to find out which game it is. Check the connection and try again." "No connection"
    fi
fi

# Safety checks: the destination must be empty, or an existing wine prefix holding the same
# game (update) or, for DLC, some ZOOM game. A DLC installer checks itself that it's the
# right game.
if is_valid_prefix "$INSTALL_PATH"; then
    # Same game is installed on this prefix, must be updating or reinstalling
    if prefix_has_game "$INSTALL_PATH" "$ZOOM_GUID" "$INNO_APPID"; then
        log_info "Detected the same game installed in this prefix! [$ZOOM_GUID]"
    else
        if prefix_has_any_game "$INSTALL_PATH"; then
            # Don't let user put different games in a prefix
            if [ $IS_DLC -eq 0 ]; then
                fatal_error "Invalid install directory. A different game is already installed here."
            fi
        else
            # Dont allow installing DLC if no other game is here
            if [ $IS_DLC -eq 1 ]; then
                fatal_error "Invalid install directory. When installing DLC, choose the directory you installed the base game in."
            fi
        fi
    fi
# must be empty or not exist
elif [ -d "$INSTALL_PATH" ] && [ -n "$(ls -A "$INSTALL_PATH")" ]; then
    fatal_error "Install directory must either be empty or an existing wine prefix if updating a game."
fi

# A pinned Proton build must be settled before the first umu call, which creates the prefix
load_game_fixes # optional, sets GAME_FIXES and the pinned Proton
ensure_pinned_proton # sets ZOOM_PROTONPATH, and PROTONPATH, only when the game is pinned

# Inno inf: hides the pages the user shouldn't change
mkdir -p "$INSTALL_PATH/drive_c"
[ "$GAME_GUID_FROM" = installer ] || printf '%s\n' "$ZOOM_GUID" > "$INSTALL_PATH/drive_c/zoom_guid"
cat >"$INSTALL_PATH/drive_c/zoom_installer.inf" <<EOL
[Setup]
Lang=english
Tasks=desktopicon
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
EOL

# These reg values must exist before the installer runs, to skip the directory page and the
# Windows shortcuts.

# Not needed for a DLC or an already installed game.
if [ $IS_DLC -eq 0 ] && ! prefix_has_game "$INSTALL_PATH" "$ZOOM_GUID" "$INNO_APPID"; then
    cat >"$INSTALL_PATH/drive_c/zoom_regkeys.bat" <<EOL
@echo off
REM We do a check cause we don't want to overwrite in case of an update that changes the default installation directory.
reg query "HKLM\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{$INNO_APPID}_is1" >nul
if %errorlevel% neq 0 (
    reg add "HKLM\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{$INNO_APPID}_is1" /v "Inno Setup: Icon Group" /t REG_SZ /d "$(get_header_val 'default_group_name')"
    reg add "HKLM\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{$INNO_APPID}_is1" /v "Inno Setup: App Path" /t REG_SZ /d "$(get_header_val 'default_dir_name')"
)
EOL

    log_info "Creating installer reg keys..."
    umu_launch start "C:\\zoom_regkeys.bat"
fi

printf "\n" > "$INSTALL_PATH/drive_c/zoom_installer.log"
# Anything written from here on is newer than this file, which tells this run's shortcuts
# apart from a shared prefix's older ones (see list_lnks_on_disk)
: > "$INSTALL_PATH/drive_c/zoom_install_started"

# Disabled: silent install only works without custom components, and that can't be checked
# reliably yet
VERYSILENT=0
# [ -z "$(get_header_val 'component_count')" ] || [ "$(get_header_val 'component_count')" -eq 0 ] && VERYSILENT=1

# Launch the installer in the background (/ZOOMINSTALLERGUID is only a marker for pkill -f).
# SLICES_NOT_FOUND: warn so Setup's own "next disk" dialog isn't a surprise mid-install
[ -n "$SLICES_NOT_FOUND" ] && log_info "Setup will still ask for these installer data files by name:$SLICES_NOT_FOUND"
log_info "Launching installer..."
umu_launch "$INPUT_INSTALLER" \
    /NORESTART \
    /SP- \
    /LOADINF=C:\\zoom_installer.inf \
    /LOG=C:\\zoom_installer.log \
    /ZOOMINSTALLERGUID="$ZOOM_GUID" \
    "$([ "$VERYSILENT" -eq 1 ] && printf "/VERYSILENT")" &

# Watch the install log
_currentfile=0
# Some installers (DLC) omit icon_count; default to 0 so $(( )) doesn't die
_header_file_count=$(get_header_val 'file_count')
_header_icon_count=$(get_header_val 'icon_count')
_filecount=$(( ${_header_file_count:-0} + ${_header_icon_count:-0} ))
_readlog=1
while [ $_readlog -eq 1 ]; do
    sleep 0.010
    while read -r line || [ -n "$line" ]; do
        case $line in
            *"Dest filename: "*)
                _currentfile=$((_currentfile+1))
                printf "\r\e[K\033[33m[\033[35mzoom-platform-darth.sh\033[33m]\033[0m: Extracting: %d/%d" $_currentfile $_filecount
            ;;
            *"Exception message"* | *"Got EAbort exception"*)
                _readlog=0
                fatal_error "Unknown installation error occured."
                ;;
        esac

        # Handle killing process based on if silent install chosen
        if [ "$VERYSILENT" -eq 1 ]; then
            case $line in
                *"Log closed."*)
                    printf "\n"
                    log_info "Installer finished!"
                    _readlog=0
                    ;;
            esac
        else
            case $line in
                *"Need to restart Windows?"*) # User shouldn't launch the game through the option supplied by Inno, kill installer asap
                    printf "\n\r"
                    log_info "Installer finished! Force closing."
                    printf "\r"
                    pkill -f "/ZOOMINSTALLERGUID=$ZOOM_GUID"
                    printf "\r"
                    _readlog=0
                    ;;
                *"Log closed."*) # Shouldn't be able to get to this point if killed by above
                    _readlog=0
                    printf "\n\r"
                    pkill -f "/ZOOMINSTALLERGUID=$ZOOM_GUID"
                    printf "\r"
                    fatal_error "Installer failed or canceled."
                    ;;
            esac
        fi
    done
done < "$INSTALL_PATH/drive_c/zoom_installer.log"

# Query API for UMU ID
UMU_ID="$(get_umu_id "$ZOOM_GUID")"
UMU_ID_EXIT=$?
[ $UMU_ID_EXIT -gt 0 ] && UMU_ID="0"


CREATE_DESKTOP_ENTRIES=1
if ! command -v desktop-file-install > /dev/null; then
    log_error "desktop-file-install is not available. Skipping desktop entry creation."
    CREATE_DESKTOP_ENTRIES=0
fi

apply_game_fix_registry # after the installer, before the first launch

# Create shortcuts using the shortcuts and icons in C:\proton_shortcuts\
# https://github.com/ValveSoftware/wine/commit/0a02c50a20ddc8f4a4c540c43a8b8a686023d422
# https://github.com/ValveSoftware/wine/commit/d0109f6ce75e13a4972371d7ef5819d2614c6d61
# https://github.com/ValveSoftware/wine/commit/7c040c3c0f837278e2ef3bb55fc9770f61444b36
GAME_NAME_SAFE=$(get_header_val 'default_group_name')
PROTON_SHORTCUTS_PATH="$INSTALL_PATH/drive_c/proton_shortcuts"
APPLICATIONS_PATH="$APPLICATIONS_ROOT/$GAME_NAME_SAFE"
ZOOM_SHORTCUTS_PATH="$INSTALL_PATH/drive_c/zoom_shortcuts"
log_info "Creating desktop entries..."
mkdir -p "$ZOOM_SHORTCUTS_PATH"
ensure_proton_shortcuts # waits for wine to create the shortcuts and fills in any it missed
LAUNCHERS_MADE=0
DUPLICATE_SHORTCUTS=0 # this run's shortcuts that are copies of ones already there, so get no launcher
# "<shortcut name>|<launcher name>" per launcher made, for the Desktop links (they differ for a
# DLC's shortcut named like one of the base game's)
LAUNCHER_MAP=''
_nl='
'
for file in "$PROTON_SHORTCUTS_PATH"/*.desktop; do
    [ ! -f "$file" ] && continue # safety check if .desktop exists

    _filename=$(basename "$file" ".desktop")
    # proton_shortcuts holds every install's shortcuts; only this run's get launchers
    case $INSTALL_SHORTCUTS in
        *"|$_filename|"*) ;;
        *) continue ;;
    esac
    _shortcut_name=$_filename # what the installer called it; _filename may become the launcher's name below

    # Get some values from the .desktop
    _name="$(get_desktop_value "Name" "$file")"
    _lnkpathwin="$(get_desktop_value "Exec" "$file")"
    _wmclass="$(get_desktop_value "StartupWMClass" "$file")"
    _iconname="$(get_desktop_value "Icon" "$file")"

    # Skip certain shortcuts
    is_skipped_shortcut "$_wmclass" "$_name" && continue

    # Unescape the Windows path: Wine 11 (GE-Proton 11) quotes the whole value, older wine
    # escapes spaces as "\ "; either way every backslash is doubled twice.
    case $_lnkpathwin in
        \"*\")
            _lnkpathwin=${_lnkpathwin#\"}
            _lnkpathwin=${_lnkpathwin%\"}
            ;;
    esac
    _lnkpathlinux=$( (PROTON_VERB=getnativepath umu_launch "$(printf '%s' "$_lnkpathwin" | sed 's/\\\\/\\/g; s/\\ / /g; s/\\\([^\\]\)/\1/g')") 2> /dev/null | head -n 1)
    # No .lnk, nothing to make a launcher from (and an empty launcher is worse than none)
    if [ ! -f "$_lnkpathlinux" ]; then
        log_error "Couldn't read the shortcut \"$_shortcut_name\" ($_lnkpathwin), so it won't get a launcher."
        continue
    fi
    # A DLC shortcut may share a name with a base game one (same .desktop, launch script and menu
    # entry). Same launch: nothing to add. Different: kept under the DLC's name so the base game's
    # launcher isn't overwritten.
    if [ $IS_DLC -eq 1 ]; then
        compare_with_existing_lnk "$_lnkpathlinux" "$_shortcut_name"
        case $? in
            0)
                DUPLICATE_SHORTCUTS=$((DUPLICATE_SHORTCUTS+1))
                continue
                ;;
            2)
                _filename=$GAME_NAME_SAFE
                # A second one in the same run can't have the same name too
                case $LAUNCHER_MAP in
                    *"|$_filename$_nl"*) _filename="$GAME_NAME_SAFE ($_shortcut_name)" ;;
                esac
                _name=$_filename
                ;;
        esac
    fi

    # Get values from .lnk
    _lnk="$(parse_lnk "$_lnkpathlinux")"
    _lnk_exe=$(printf '%s' "$_lnk" | sed -n 's/LocalBasePath://p')
    _lnk_workingdir=$(printf '%s' "$_lnk" | sed -n 's/WORKING_DIR://p')
    _lnk_args=$(printf '%s' "$_lnk" | sed -n 's/COMMAND_LINE_ARGUMENTS://p')

    # Absolute path of the largest icon. No Icon= means no icon: searching "*.png" would pick
    # another shortcut's.
    _iconpath=""
    if [ -n "$_iconname" ]; then
        _iconfile=$(find "$PROTON_SHORTCUTS_PATH/icons" -type f -name "*$_iconname.png" -printf '%P\n' 2> /dev/null | sort -n -tx -k1 -r | head -n 1)
        [ -n "$_iconfile" ] && _iconpath="$PROTON_SHORTCUTS_PATH/icons/$_iconfile"
    fi

    # A game fix (game-fixes/) can replace this shortcut with launchers of its own
    make_fixed_launchers "$_shortcut_name" "$_lnk_exe" "$_iconpath" && continue

    make_launcher "$_filename" "$_name" "$_lnk_workingdir" "$_lnk_exe" "$_lnk_args" "$_iconpath" "$_wmclass" "$_shortcut_name"
done

# The install can look successful while having no launcher at all, so say so
if [ $((SHORTCUTS_KEPT-DUPLICATE_SHORTCUTS)) -gt 0 ] && [ "$LAUNCHERS_MADE" -eq 0 ]; then
    log_error "The installer created $SHORTCUTS_KEPT shortcut(s) but no launch scripts could be made from them. The game is installed, but new launchers weren't created (any you already had were left as they are). See \"$INSTALL_PATH/drive_c/zoom_menubuilder.log\""
fi

# The prefix may hold several installs (base game + DLC) that share one $ZOOM_GUID and are
# wiped together, so the uninstaller must clean up every applications dir made in it. Each
# install writes its group as "IconGroup" in system.reg, read back with get_prefix_reg_val,
# plus $GAME_NAME_SAFE itself (wine may not have flushed its key yet). Anything that isn't a
# bare directory name is dropped, since it ends up in rm -rf.
_icon_groups="$(
    {
        get_prefix_reg_val "$INSTALL_PATH" 'IconGroup'
        printf '%s\n' "$GAME_NAME_SAFE"
    } | sort -u | while IFS= read -r _g; do
        case "$_g" in
            "" | . | ..) continue ;;
            */*) continue ;;
        esac
        printf '%s\n' "$_g"
    done
)"

# The Desktop symlinks don't exist yet, so the uninstaller scans the Desktop at uninstall time
# and removes only symlinks pointing into a known applications dir, leaving other files alone.
write_uninstaller "$_icon_groups"

# Symlink to the XDG Desktop the launchers whose shortcut this run's installer put on the
# Desktop (names match the Start Menu ones). An earlier install's Desktop shortcut isn't touched.
if [ $CREATE_DESKTOP_ENTRIES -eq 1 ]; then
    while IFS='|' read -r _shortcut_name _launcher_name; do
        [ -n "$_shortcut_name" ] || continue
        case $INSTALL_DESKTOP_SHORTCUTS in
            *"|$_shortcut_name|"*) ;;
            *) continue ;;
        esac
        _existingdesktoppath="$APPLICATIONS_PATH/$_launcher_name.desktop"
        if [ -f "$_existingdesktoppath" ]; then
            log_info "Creating \"$DESKTOP_DIR/$_launcher_name.desktop\""
            ln -sf "$_existingdesktoppath" "$DESKTOP_DIR/$_launcher_name.desktop"
        fi
    done <<EOL
$LAUNCHER_MAP
EOL
    printf "\n"
    log_info "Installation complete! You can now launch your games from the applications launcher."
    log_info "To add to your Steam library, from within Steam go to \"Games\" -> \"Add a Non-Steam Game to My Library\" then select it from the popup."
else
    printf "\n"
    log_info "Installation complete! Desktop entry creation was skipped, the launch scripts are in \"$ZOOM_SHORTCUTS_PATH\""
fi
