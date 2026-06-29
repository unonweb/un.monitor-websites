# Clean up domains to create safe keys for the state file
function sanitize_url {
	local url=${1}
    echo "${url}" | sed 's/[^a-zA-Z0-9]/_/g'
	# sed 's/.../.../g' searches for a pattern and replaces it globally
	# [^a-zA-Z0-9] matches any char that is not alphanumeric
	# /_/ replaces them with an underscore
}