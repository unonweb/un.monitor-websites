#!/usr/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")

APP_NAME="${SCRIPT_PARENT##*/}"

PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
PATH_DEFAULTS="${SCRIPT_PARENT}/defaults.cfg"

# IMPORTS
source "${SCRIPT_DIR}/lib/sanitize_url.sh"
source "${SCRIPT_DIR}/lib/log.sh"

function main {

	local alert_msg=""

	# CONFIG & DEFAULTS
	if [[ -r ${PATH_CONFIG} ]]; then
		source "${PATH_CONFIG}"
	else
		echo "<4>WARN: No config file found at ${PATH_CONFIG}. Using defaults ..."
		source "${PATH_DEFAULTS}"
	fi

	# MKDIR state
	if [[ ! -d "${STATE_DIR}" ]]; then
		log "<6> Creating state dir at: ${STATE_DIR}"
		mkdir -p "${STATE_DIR}"
	fi
	
	# TOUCH state file
	if [[ ! -f "${STATE_FILE}" ]]; then
		touch "${STATE_FILE}"
	fi

	for url in "${URLS[@]}"; do
		local key=$(sanitize_url "${url}")
		local current_time=$(date +%s)
		
		# CHECK URL
		if curl --location --silent --connect-timeout 10 --max-time 15 "${url}" > /dev/null; then
			# --location follows redirects
			# SITE IS UP
			log "<6> Site is up: ${url}"
			# If it was previously down, remove it from the tracking file so alerts reset
			if grep -q "^${key}:" "${STATE_FILE}"; then
				sed -i "/^${key}:/d" "${STATE_FILE}"
				# -i modify file in-place
				# : The colon that separates the key from the timestamp
				# / ... /d search for a pattern and delete it
			fi
		else
			# SITE IS DOWN
			log "<5> Site is down: ${url}"
			local last_alert=$(grep "^${key}:" "${STATE_FILE}" | cut -d':' -f2)
			
			if [[ -z "${last_alert}" ]]; then
				# First time it's down
				# Alert
				alert_msg+="${url}\n"
				echo "${key}:${current_time}" >> "${STATE_FILE}"
			else
				# It was already down, check if 48 hours have passed
				local seconds_since_last_alert=$((current_time - last_alert))
				if (( seconds_since_last_alert > (COOLDOWN_HOURS * 3600) )); then
					# Alert
					alert_msg+="${url}\n"
					# Update the timestamp in the state file
					sed -i "s/^${key}:.*/${key}:${current_time}/" "${STATE_FILE}"
				else
					log "<6> Skipping alert because we already alerted ~ $((seconds_since_last_alert / 3600)) hours ago."
				fi
			fi
		fi
	done

	if [[ -n "${alert_msg}" ]]; then

		# ALERT
		alert_msg_header+="DATE: $(date "+%Y-%m-%d %H:%M:%S")\n"
		alert_msg_header+="HOSTNAME: ${HOSTNAME}\n\n"
		alert_msg_header+="The following websites are not available:\n\n"
		
		if ((MAIL_ALERT)); then
			echo -e "${alert_msg_header}${alert_msg}" | \
			mail -s "${MAIL_SUBJECT}" "${MAIL_TO}" 2>/dev/null
		fi
	fi
}

main