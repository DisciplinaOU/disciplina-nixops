keys/staging/committee-secret:
	cat /dev/urandom | head -c 16 | base64 > $@
