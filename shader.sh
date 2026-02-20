#!/usr/bin/env bash
set -euo pipefail

# Resolve the directory where this script (and the shaders) live
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ghostty config path — override with GHOSTTY_CONFIG env var if needed
GHOSTTY_CONFIG="${GHOSTTY_CONFIG:-$HOME/.config/ghostty/config}"

# ---------- Shader discovery ----------

discover_shaders() {
    local shaders=()
    # .glsl files
    for f in "$SCRIPT_DIR"/*.glsl; do
        [[ -f "$f" ]] && shaders+=("$(basename "$f")")
    done
    # Extensionless files containing mainImage (e.g. auto-tracking-spotlight)
    for f in "$SCRIPT_DIR"/*; do
        [[ -f "$f" ]] || continue
        local name
        name="$(basename "$f")"
        # Skip .glsl (already found), skip dotfiles, skip known non-shaders
        [[ "$name" == *.* ]] && continue
        if grep -q 'mainImage' "$f" 2>/dev/null; then
            shaders+=("$name")
        fi
    done
    printf '%s\n' "${shaders[@]}" | sort
}

# ---------- Config helpers ----------

ensure_config() {
    local dir
    dir="$(dirname "$GHOSTTY_CONFIG")"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
    if [[ ! -f "$GHOSTTY_CONFIG" ]]; then
        touch "$GHOSTTY_CONFIG"
    fi
}

# Return ALL custom-shader paths from config, one per line, in order.
get_current_shaders() {
    if [[ ! -f "$GHOSTTY_CONFIG" ]]; then
        return
    fi
    grep '^custom-shader' "$GHOSTTY_CONFIG" | sed 's/^custom-shader[[:space:]]*=[[:space:]]*//' || true
}

# Return only the last custom-shader path (backward compat wrapper).
get_current_shader() {
    get_current_shaders | tail -1
}

# Atomically update the config: remove all custom-shader lines, append new ones.
# Pass zero or more absolute paths as arguments. Zero args = remove all.
update_config() {
    ensure_config

    local tmpfile
    tmpfile="$(dirname "$GHOSTTY_CONFIG")/.config.tmp.$$"

    # Remove existing custom-shader lines
    grep -v '^custom-shader' "$GHOSTTY_CONFIG" > "$tmpfile" || true

    # Remove trailing blank lines from temp file, then ensure single trailing newline
    sed -i '' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$tmpfile" 2>/dev/null || true
    # Ensure file ends with newline
    if [[ -s "$tmpfile" ]] && [[ "$(tail -c 1 "$tmpfile" | wc -l)" -eq 0 ]]; then
        echo "" >> "$tmpfile"
    fi

    # Append new shader lines
    for path in "$@"; do
        if [[ -n "$path" ]]; then
            echo "custom-shader = $path" >> "$tmpfile"
        fi
    done

    mv "$tmpfile" "$GHOSTTY_CONFIG"
}

# ---------- Name resolution ----------

resolve_shader() {
    local input="$1"
    local shaders
    shaders="$(discover_shaders)"

    # 1. Exact filename match
    if echo "$shaders" | grep -qx "$input"; then
        echo "$input"
        return
    fi

    # 2. Append .glsl
    if echo "$shaders" | grep -qx "${input}.glsl"; then
        echo "${input}.glsl"
        return
    fi

    # 3. Case-insensitive exact match
    local ci_match
    ci_match="$(echo "$shaders" | grep -ix "$input" || true)"
    if [[ -n "$ci_match" ]]; then
        local count
        count="$(echo "$ci_match" | wc -l | tr -d ' ')"
        if [[ "$count" -eq 1 ]]; then
            echo "$ci_match"
            return
        fi
    fi

    # 3b. Case-insensitive with .glsl appended
    ci_match="$(echo "$shaders" | grep -ix "${input}.glsl" || true)"
    if [[ -n "$ci_match" ]]; then
        local count
        count="$(echo "$ci_match" | wc -l | tr -d ' ')"
        if [[ "$count" -eq 1 ]]; then
            echo "$ci_match"
            return
        fi
    fi

    # 4. Prefix match (case-insensitive)
    local prefix_matches
    prefix_matches="$(echo "$shaders" | grep -i "^${input}" || true)"
    if [[ -n "$prefix_matches" ]]; then
        local count
        count="$(echo "$prefix_matches" | wc -l | tr -d ' ')"
        if [[ "$count" -eq 1 ]]; then
            echo "$prefix_matches"
            return
        fi
        echo "error:Ambiguous prefix match for '$input'. Matches:" >&2
        echo "$prefix_matches" | sed 's/^/  /' >&2
        return 1
    fi

    # 5. Substring match (case-insensitive)
    local sub_matches
    sub_matches="$(echo "$shaders" | grep -i "${input}" || true)"
    if [[ -n "$sub_matches" ]]; then
        local count
        count="$(echo "$sub_matches" | wc -l | tr -d ' ')"
        if [[ "$count" -eq 1 ]]; then
            echo "$sub_matches"
            return
        fi
        echo "error:Ambiguous substring match for '$input'. Matches:" >&2
        echo "$sub_matches" | sed 's/^/  /' >&2
        return 1
    fi

    echo "error:No shader found matching '$input'" >&2
    return 1
}

# ---------- Preview helper ----------

preview_path() {
    local shader_name="$1"
    local base="${shader_name%.glsl}"
    for ext in png jpg gif; do
        if [[ -f "$SCRIPT_DIR/theme/${base}.${ext}" ]]; then
            echo "$SCRIPT_DIR/theme/${base}.${ext}"
            return
        fi
    done
    echo ""
}

# ---------- Interactive pickers ----------

# fzf-based multi-select shader picker.
# Active shaders are placed first and pre-selected via start binding.
# Outputs selected shader names, one per line.
fzf_pick_shaders() {
    local shaders
    shaders="$(discover_shaders)"

    # Build active shader lookup
    declare -A active_map
    local active_lines
    active_lines="$(get_current_shaders)"
    if [[ -n "$active_lines" ]]; then
        while IFS= read -r apath; do
            local aname
            aname="$(basename "$apath")"
            active_map["$aname"]=1
        done <<< "$active_lines"
    fi

    # Build ordered input: active shaders first, then inactive (each group sorted)
    local active_items=()
    local inactive_items=()
    while IFS= read -r shader; do
        if [[ -n "${active_map[$shader]+x}" ]]; then
            active_items+=("$shader")
        else
            inactive_items+=("$shader")
        fi
    done <<< "$shaders"

    local num_active=${#active_items[@]}
    local fzf_input=""
    for s in "${active_items[@]}"; do
        fzf_input+="$s"$'\n'
    done
    for s in "${inactive_items[@]}"; do
        fzf_input+="$s"$'\n'
    done
    fzf_input="${fzf_input%$'\n'}"

    # Build load action: toggle first N items to pre-select active shaders.
    # Uses 'load' event (fires after input is fully loaded) so toggle has items to act on.
    local load_action="first"
    if [[ $num_active -gt 0 ]]; then
        load_action=""
        for ((i=0; i<num_active; i++)); do
            load_action+="toggle+down+"
        done
        load_action+="first"
    fi

    local selections
    selections="$(echo "$fzf_input" | fzf \
        --multi \
        --no-sort \
        --preview "head -30 '$SCRIPT_DIR/{1}' 2>/dev/null || echo 'No preview available'" \
        --header 'Tab: select/deselect  Ctrl-A: all  Ctrl-D: deselect all  Enter: confirm  Esc: cancel' \
        --layout=reverse \
        --border \
        --border-label=' Ghostty Shaders ' \
        --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
        --bind "load:${load_action}" \
    )" || {
        echo "Selection cancelled." >&2
        return 1
    }

    if [[ -z "$selections" ]]; then
        echo "Selection cancelled." >&2
        return 1
    fi

    echo "$selections"
}

# Numbered-list fallback picker when fzf is not available.
# Outputs selected shader names, one per line.
fallback_pick_shaders() {
    local shaders
    shaders="$(discover_shaders)"

    # Build active shader lookup
    declare -A active_map
    local active_lines
    active_lines="$(get_current_shaders)"
    if [[ -n "$active_lines" ]]; then
        while IFS= read -r apath; do
            local aname
            aname="$(basename "$apath")"
            active_map["$aname"]=1
        done <<< "$active_lines"
    fi

    # Store shaders in array for index lookup
    local shader_arr=()
    mapfile -t shader_arr <<< "$shaders"

    echo "Available shaders:" >&2
    echo "" >&2
    local i=1
    for shader in "${shader_arr[@]}"; do
        local marker=" "
        if [[ -n "${active_map[$shader]+x}" ]]; then
            marker="*"
        fi
        printf "  %s%2d) %s\n" "$marker" "$i" "$shader" >&2
        ((i++))
    done
    echo "" >&2
    echo "  * = currently active" >&2
    echo "" >&2
    echo -n "Enter shader numbers (comma-separated, e.g. 1,3,5): " >&2
    local input
    read -r input

    if [[ -z "$input" ]]; then
        echo "Selection cancelled." >&2
        return 1
    fi

    # Parse comma-separated numbers, preserving selection order
    local IFS=','
    read -ra nums <<< "$input"
    local has_output=false
    for num in "${nums[@]}"; do
        # Trim whitespace
        num="$(echo "$num" | tr -d ' ')"
        if [[ ! "$num" =~ ^[0-9]+$ ]]; then
            echo "Invalid number: $num" >&2
            continue
        fi
        local idx=$((num - 1))
        if [[ $idx -lt 0 || $idx -ge ${#shader_arr[@]} ]]; then
            echo "Out of range: $num" >&2
            continue
        fi
        echo "${shader_arr[$idx]}"
        has_output=true
    done

    if [[ "$has_output" != true ]]; then
        echo "No valid selections." >&2
        return 1
    fi
}

# ---------- Subcommands ----------

cmd_list() {
    # Build active shader lookup with position numbers
    declare -A active_positions
    local active_lines
    active_lines="$(get_current_shaders)"
    local pos=1
    if [[ -n "$active_lines" ]]; then
        while IFS= read -r apath; do
            local aname
            aname="$(basename "$apath")"
            active_positions["$aname"]=$pos
            ((pos++))
        done <<< "$active_lines"
    fi
    local active_count=$((pos - 1))

    local shaders
    shaders="$(discover_shaders)"
    local count
    count="$(echo "$shaders" | wc -l | tr -d ' ')"

    echo "Available shaders ($count):"
    echo ""
    while IFS= read -r shader; do
        local line
        if [[ -n "${active_positions[$shader]+x}" ]]; then
            local p="${active_positions[$shader]}"
            line="  *${p}) $shader"
        else
            line="     $shader"
        fi
        local preview
        preview="$(preview_path "$shader")"
        if [[ -n "$preview" ]]; then
            line="$line  (preview: theme/$(basename "$preview"))"
        fi
        echo "$line"
    done <<< "$shaders"
    echo ""
    if [[ $active_count -gt 0 ]]; then
        echo "Active shaders marked with *N) showing pipeline order"
    else
        echo "No shader currently active"
    fi
}

cmd_set() {
    if [[ $# -eq 0 ]]; then
        # Interactive picker mode
        local selections
        if command -v fzf &>/dev/null; then
            selections="$(fzf_pick_shaders)" || return 1
        else
            selections="$(fallback_pick_shaders)" || return 1
        fi

        # Resolve and collect paths
        local paths=()
        local names=()
        while IFS= read -r name; do
            [[ -z "$name" ]] && continue
            local abs_path="$SCRIPT_DIR/$name"
            if [[ ! -f "$abs_path" ]]; then
                echo "Warning: Shader file not found: $abs_path — skipping" >&2
                continue
            fi
            paths+=("$abs_path")
            names+=("$name")
        done <<< "$selections"

        if [[ ${#paths[@]} -eq 0 ]]; then
            echo "No valid shaders selected."
            return 1
        fi

        update_config "${paths[@]}"

        if [[ ${#names[@]} -eq 1 ]]; then
            echo "Shader set to: ${names[0]}"
            echo "  Path: ${paths[0]}"
        else
            echo "Shaders set (${#names[@]} in pipeline):"
            local i=1
            for name in "${names[@]}"; do
                echo "  $i) $name"
                ((i++))
            done
        fi
        echo ""
        echo "Press Cmd+Shift+, in Ghostty to reload config."
        return
    fi

    # Resolve all arguments
    local paths=()
    local names=()
    for arg in "$@"; do
        local resolved
        resolved="$(resolve_shader "$arg")" || return 1
        local abs_path="$SCRIPT_DIR/$resolved"
        if [[ ! -f "$abs_path" ]]; then
            echo "Error: Shader file not found: $abs_path" >&2
            return 1
        fi
        paths+=("$abs_path")
        names+=("$resolved")
    done

    update_config "${paths[@]}"

    if [[ ${#names[@]} -eq 1 ]]; then
        echo "Shader set to: ${names[0]}"
        echo "  Path: ${paths[0]}"
        local preview
        preview="$(preview_path "${names[0]}")"
        if [[ -n "$preview" ]]; then
            echo "  Preview: $preview"
        fi
    else
        echo "Shaders set (${#names[@]} in pipeline):"
        local i=1
        for name in "${names[@]}"; do
            echo "  $i) $name"
            ((i++))
        done
    fi
    echo ""
    echo "Press Cmd+Shift+, in Ghostty to reload config."
}

cmd_add() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: shader.sh add <name> [name2 ...]" >&2
        return 1
    fi

    # Get existing shader paths
    local existing_paths=()
    local existing_names=()
    local active_lines
    active_lines="$(get_current_shaders)"
    if [[ -n "$active_lines" ]]; then
        while IFS= read -r apath; do
            existing_paths+=("$apath")
            existing_names+=("$(basename "$apath")")
        done <<< "$active_lines"
    fi

    # Build lookup set for duplicate detection
    declare -A existing_set
    for name in "${existing_names[@]}"; do
        existing_set["$name"]=1
    done

    # Resolve and append new shaders
    local added=()
    for arg in "$@"; do
        local resolved
        resolved="$(resolve_shader "$arg")" || return 1
        if [[ -n "${existing_set[$resolved]+x}" ]]; then
            echo "$resolved is already active — skipping"
            continue
        fi
        local abs_path="$SCRIPT_DIR/$resolved"
        if [[ ! -f "$abs_path" ]]; then
            echo "Error: Shader file not found: $abs_path" >&2
            return 1
        fi
        existing_paths+=("$abs_path")
        existing_set["$resolved"]=1
        added+=("$resolved")
    done

    if [[ ${#added[@]} -eq 0 ]]; then
        echo "No new shaders to add."
        return
    fi

    update_config "${existing_paths[@]}"

    if [[ ${#added[@]} -eq 1 ]]; then
        echo "Added shader: ${added[0]}"
    else
        echo "Added ${#added[@]} shaders:"
        for name in "${added[@]}"; do
            echo "  + $name"
        done
    fi
    echo ""
    echo "Active pipeline (${#existing_paths[@]} shaders):"
    local i=1
    for p in "${existing_paths[@]}"; do
        echo "  $i) $(basename "$p")"
        ((i++))
    done
    echo ""
    echo "Press Cmd+Shift+, in Ghostty to reload config."
}

cmd_off() {
    update_config
    echo "Shader disabled (all custom-shader lines removed)."
    echo ""
    echo "Press Cmd+Shift+, in Ghostty to reload config."
}

cmd_current() {
    local active_lines
    active_lines="$(get_current_shaders)"
    if [[ -z "$active_lines" ]]; then
        echo "No shader currently active."
        return
    fi

    local count
    count="$(echo "$active_lines" | wc -l | tr -d ' ')"

    if [[ "$count" -eq 1 ]]; then
        local name
        name="$(basename "$active_lines")"
        echo "Current shader: $name"
        echo "  Path: $active_lines"
        if [[ ! -f "$active_lines" ]]; then
            echo "  Warning: shader file not found at this path"
        fi
    else
        echo "Active shaders ($count in pipeline):"
        local i=1
        while IFS= read -r shader_path; do
            local name
            name="$(basename "$shader_path")"
            echo "  $i) $name"
            echo "     Path: $shader_path"
            if [[ ! -f "$shader_path" ]]; then
                echo "     Warning: shader file not found at this path"
            fi
            ((i++))
        done <<< "$active_lines"
    fi
}

cmd_help() {
    cat <<'EOF'
shader.sh — Ghostty shader switcher (multi-shader support)

Usage:
  shader.sh <command> [args]

Commands:
  list, ls                 List available shaders (active marked with *N)
  set                      Interactive shader picker (fzf multi-select)
  set <name> [name2 ...]   Set one or more shaders (replaces all existing)
  add <name> [name2 ...]   Append shader(s) to existing pipeline
  off, disable, none       Remove all shaders from config
  current, status          Show all active shaders in pipeline order
  help, --help, -h         Show this help

Examples:
  shader.sh set                      # interactive picker (fzf or fallback)
  shader.sh set crt                  # single shader (matches crt.glsl)
  shader.sh set crt bloom            # multi-shader pipeline
  shader.sh add drunkard             # append to existing pipeline
  shader.sh list                     # show all, active marked *1) *2)
  shader.sh current                  # show active pipeline
  shader.sh off                      # remove all shaders

Interactive picker (fzf):
  Tab          Select/deselect shader
  Ctrl-A       Select all
  Ctrl-D       Deselect all
  Enter        Confirm selection
  Esc          Cancel

  Note: fzf outputs selections in alphabetical order, not selection order.
  Use CLI args for precise ordering: shader.sh set bloom crt drunkard

Environment:
  GHOSTTY_CONFIG    Override config path (default: ~/.config/ghostty/config)

After any change, press Cmd+Shift+, in Ghostty to reload config.
EOF
}

# ---------- Main ----------

main() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        list|ls)          cmd_list "$@" ;;
        set|use)          cmd_set "$@" ;;
        add)              cmd_add "$@" ;;
        off|disable|none) cmd_off "$@" ;;
        current|status)   cmd_current "$@" ;;
        help|--help|-h)   cmd_help ;;
        *)
            echo "Unknown command: $cmd" >&2
            echo "Run 'shader.sh help' for usage." >&2
            return 1
            ;;
    esac
}

main "$@"
