/*
 * Vault configuration. See: https://vaultproject.io/docs/config/
 */
disable_mlock = true
ui = true
backend "file" {
	path = "/etc/vault"
}

listener "tcp" {
	/*
	 * By default Vault listens on localhost only.
	 * Make sure to enable TLS support otherwise.
	 *
	 * Note that VAULT_ADDR=http://127.0.0.1:8200 must
	 * be set in the environment in order for the client
	 * to work because it uses HTTPS by default.
	 */
	address = "0.0.0.0:8200"
	tls_disable = 1
}
