# paperless-ngx-helm

Helm chart to deploy [Paperless-NGX](https://github.com/paperless-ngx/paperless-ngx) on Kubernetes,
always tracking the latest release.

## Components

| Component | Default image | Purpose |
|-----------|--------------|---------|
| Paperless-NGX | `ghcr.io/paperless-ngx/paperless-ngx` | Main application |
| PostgreSQL | `ghcr.io/cloudnative-pg/postgresql:16` | Database (via CloudNativePG operator) |
| Redis | `redis:7-alpine` | Task queue / caching |
| Gotenberg | `gotenberg/gotenberg:8` | Office-document → PDF conversion |
| Tika | `ghcr.io/paperless-ngx/tika:2.9.1-minimal` | Document text extraction |

## Prerequisites

- Kubernetes 1.25+
- Helm 3.10+
- [CloudNativePG operator](https://cloudnative-pg.io/docs/current/installation_upgrade/) installed in the cluster
- A default or named StorageClass available

## Installing the chart

```bash
# Add the repo (or use a local path)
helm install my-paperless ./paperless-ngx \
  --set paperless.secrets.PAPERLESS_SECRET_KEY="$(openssl rand -hex 32)" \
  --set paperless.secrets.PAPERLESS_ADMIN_PASSWORD="strongpassword" \
  --namespace paperless \
  --create-namespace
```

## Quick start with custom values

```yaml
# my-values.yaml
paperless:
  config:
    PAPERLESS_URL: "https://paperless.mycompany.com"
    PAPERLESS_TIME_ZONE: "Europe/Paris"
    PAPERLESS_OCR_LANGUAGE: "fra+eng"
  secrets:
    PAPERLESS_SECRET_KEY: "a-very-long-random-string"
    PAPERLESS_ADMIN_USER: "admin"
    PAPERLESS_ADMIN_PASSWORD: "changeme"
    PAPERLESS_ADMIN_MAIL: "admin@mycompany.com"

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: paperless.mycompany.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: paperless-tls
      hosts:
        - paperless.mycompany.com

postgresql:
  instances: 1
  storage:
    size: 20Gi

persistence:
  data:
    size: 10Gi
  media:
    size: 100Gi
```

```bash
helm install my-paperless ./paperless-ngx -f my-values.yaml -n paperless --create-namespace
```

## Values

See [`paperless-ngx/values.yaml`](paperless-ngx/values.yaml) for the full, annotated list of parameters.

### Key parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `paperless.image.tag` | Paperless-NGX image tag (empty = Chart appVersion) | `""` |
| `paperless.config` | Non-secret env vars passed to the app | see values.yaml |
| `paperless.secrets.*` | Secret credentials (secret key, admin user/password) — **required** unless `existingSecret` is set | see values.yaml |
| `paperless.existingSecret` | Name of a pre-existing K8s Secret to use instead of chart-managed secrets. The secret must contain `PAPERLESS_SECRET_KEY`, `PAPERLESS_ADMIN_USER`, `PAPERLESS_ADMIN_PASSWORD`, `PAPERLESS_ADMIN_MAIL` | `""` |
| `ingress.enabled` | Expose Paperless via an Ingress | `false` |
| `persistence.*.size` | PVC sizes for data / media / export / consume | various |
| `cnpg.instances` | Number of CloudNativePG instances | `1` |
| `cnpg.storage.size` | Storage size for the Postgres cluster | `10Gi` |
| `redis.enabled` | Deploy Redis sidecar | `true` |
| `gotenberg.enabled` | Deploy Gotenberg | `true` |
| `tika.enabled` | Deploy Tika | `true` |

## PostgreSQL (CloudNativePG)

> **Only CloudNativePG is currently supported** as the database backend. If you need MySQL/MariaDB support, contributions are welcome — please open a PR.

The chart creates a `Cluster` custom resource (CRD provided by the [CloudNativePG operator](https://cloudnative-pg.io/)).
The operator automatically:
- creates a secret `<clusterName>-app` containing `username` and `password`
- exposes a read-write service at `<clusterName>-rw`

These are automatically wired into the Paperless deployment.

> **Note:** The CloudNativePG operator **must** be installed before running `helm install`.
> See: https://cloudnative-pg.io/docs/current/installation_upgrade/

### Upgrading PostgreSQL major version

Bumping `cnpg.postgresVersion` (and `cnpg.image.tag`) triggers a major-version upgrade.
CloudNativePG supports this via its built-in `pg_upgrade` method — see the
[CNPG upgrade docs](https://cloudnative-pg.io/docs/current/postgresql_upgrade/) before proceeding.

## Security

All pods run as non-root and drop all Linux capabilities by default. Adjust `securityContext`
in values if your environment requires different settings.

## Upgrading

```bash
helm upgrade my-paperless ./paperless-ngx -n paperless -f my-values.yaml
```
