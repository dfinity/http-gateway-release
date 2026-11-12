# Converts the CSV output of chronyc (-c) to Prometheus metrics, see etc/sv/chrony-metrics/run.
# Field layouts are those of chrony 4.6 (print_report() calls in client.c).

BEGIN { FS = "," }

# Label values are host names or addresses, drop the characters that would need escaping
function clean(s) {
    gsub(/["\\\n]/, "", s)
    return s
}

# Collects a sample, the samples are printed grouped by metric at the end
function add(name, help, labels, value) {
    if (!(name in helps)) {
        helps[name] = help
        order[++n] = name
    }
    samples[name] = samples[name] name labels " " value "\n"
}

# Number of set bits in an octal number (the reachability register)
function bits(octal,    i, c) {
    c = 0
    for (i = 1; i <= length(octal); i++)
        c += substr("01121223", substr(octal, i, 1) + 1, 1)
    return c
}

# Reference ID, name, stratum, ref time, system time, last offset, RMS offset, frequency,
# residual frequency, skew, root delay, root dispersion, update interval, leap status
FILENAME ~ /\/tracking$/ && NF == 14 {
    up = 1
    leap = 3
    if ($14 == "Normal") leap = 0
    else if ($14 == "Insert second") leap = 1
    else if ($14 == "Delete second") leap = 2

    add("chrony_tracking_leap_status", "Leap status: 0 normal, 1 insert second, 2 delete second, 3 not synchronised", "", leap)
    add("chrony_tracking_stratum", "Stratum of the system clock", "", $3)
    add("chrony_tracking_reference_timestamp_seconds", "Time of the last update from the reference source (Unix time)", "", $4)
    add("chrony_tracking_system_time_seconds", "Offset of the system clock from NTP time, positive when the system clock is behind", "", $5)
    add("chrony_tracking_last_offset_seconds", "Offset measured at the last clock update", "", $6)
    add("chrony_tracking_rms_offset_seconds", "Long-term average of the measured offset", "", $7)
    add("chrony_tracking_frequency_ppm", "Frequency error of the system clock if uncorrected, positive when it runs fast", "", $8)
    add("chrony_tracking_residual_frequency_ppm", "Residual frequency of the reference source", "", $9)
    add("chrony_tracking_skew_ppm", "Estimated error bound of the frequency", "", $10)
    add("chrony_tracking_root_delay_seconds", "Total network delay to the stratum-1 source", "", $11)
    add("chrony_tracking_root_dispersion_seconds", "Total dispersion accumulated up to the stratum-1 source", "", $12)
    add("chrony_tracking_update_interval_seconds", "Interval between the last two clock updates", "", $13)
    next
}

FILENAME ~ /\/sources\.names$/ { source_name[FNR] = $3; next }

# Mode, state, address, stratum, poll (log2), reachability (octal), last sample age,
# adjusted offset, measured offset, error bound
FILENAME ~ /\/sources\.addrs$/ && NF == 10 {
    name = (FNR in source_name) ? source_name[FNR] : $3
    l = "source=\"" clean(name) "\",address=\"" clean($3) "\""

    mode = "unknown"
    if ($1 == "^") mode = "server"
    else if ($1 == "=") mode = "peer"
    else if ($1 == "#") mode = "refclock"

    state = "unusable"
    if ($2 == "*") state = "selected"
    else if ($2 == "+") state = "combined"
    else if ($2 == "-") state = "not_combined"
    else if ($2 == "x") state = "falseticker"
    else if ($2 == "~") state = "jittery"

    add("chrony_source_info", "Mode and selection state of the source", "{" l ",mode=\"" mode "\",state=\"" state "\"}", 1)
    add("chrony_source_stratum", "Stratum of the source", "{" l "}", $4)
    add("chrony_source_poll_interval_seconds", "Polling interval of the source", "{" l "}", 2 ^ $5)
    add("chrony_source_reachability_ratio", "Share of the last 8 polls that got a valid reply", "{" l "}", bits($6) / 8)
    # 4294967295 means no sample yet
    if ($7 != 4294967295)
        add("chrony_source_last_sample_age_seconds", "Time since the last sample from the source", "{" l "}", $7)
    add("chrony_source_offset_seconds", "Offset of the last sample, adjusted for clock updates since", "{" l "}", $8)
    add("chrony_source_offset_error_seconds", "Error bound of the last sample", "{" l "}", $10)
    next
}

FILENAME ~ /\/authdata\.names$/ { auth_name[FNR] = $1; next }

# Address, mode, key ID, key type, key length, last NTS-KE age, NTS-KE attempts, NAK,
# cookies, cookie length
FILENAME ~ /\/authdata\.addrs$/ && NF == 10 {
    name = (FNR in auth_name) ? auth_name[FNR] : $1
    l = "source=\"" clean(name) "\",address=\"" clean($1) "\""

    mode = "none"
    if ($2 == "NTS") mode = "nts"
    else if ($2 == "SK") mode = "sk"

    add("chrony_source_auth_info", "Authentication mechanism of the source", "{" l ",mode=\"" mode "\"}", 1)
    add("chrony_source_auth_key_length_bits", "Length of the authentication key, 0 until an NTS key exchange succeeds", "{" l "}", $5)
    if (mode == "nts") {
        add("chrony_source_nts_cookies", "Number of NTS cookies held for the source", "{" l "}", $9)
        add("chrony_source_nts_ke_attempts", "NTS key exchange attempts since the last successful one", "{" l "}", $7)
        # 4294967295 means no successful key exchange yet
        if ($6 != 4294967295)
            add("chrony_source_nts_last_ke_age_seconds", "Time since the last successful NTS key exchange", "{" l "}", $6)
    }
    next
}

END {
    add("chrony_up", "Whether chronyd answered the tracking query", "", up + 0)
    for (i = 1; i <= n; i++) {
        m = order[i]
        printf "# HELP %s %s\n# TYPE %s gauge\n%s", m, helps[m], m, samples[m]
    }
}
