# Quay Vault Variables

Schema Version: 1.0.0

These variables are used by `rhis-builder-quay` to deploy and configure a self-hosted Red Hat Quay container registry. All cryptographic values should be generated fresh for each deployment.

**Generation commands:**

```bash
# PostgreSQL password (random hex)
python3 -c "import secrets; print(secrets.token_hex(16))"

# Database secret key and session secret key (random UUIDs)
python3 -c "import uuid; print(uuid.uuid4())"

# Security scanner pre-shared key (random hex, longer)
python3 -c "import secrets; print(secrets.token_hex(32))"
```

---

## Quay database and cryptographic secrets

| Variable | Classification | Description | How to obtain | Used by |
|---|---|---|---|---|
| `quay_pg_password_vault` | secret | Password for the PostgreSQL database used by Quay. | Generate with `python3 -c "import secrets; print(secrets.token_hex(16))"` | rhis-builder-quay |
| `quay_database_secret_key_vault` | secret | A UUID used as the Quay database encryption secret key. Must be unique per deployment. | Generate with `python3 -c "import uuid; print(uuid.uuid4())"` | rhis-builder-quay |
| `quay_session_secret_key_vault` | secret | A UUID used as the Quay session secret key for user session signing. Must differ from `quay_database_secret_key_vault`. | Generate with `python3 -c "import uuid; print(uuid.uuid4())"` | rhis-builder-quay |
| `quay_security_scanner_psk_vault` | secret | A pre-shared key (PSK) used to authenticate the Clair security scanner to the Quay API. | Generate with `python3 -c "import secrets; print(secrets.token_hex(32))"` | rhis-builder-quay |
