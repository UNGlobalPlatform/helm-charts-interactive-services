# trade-data-tool

![Version: 0.7.0](https://img.shields.io/badge/Version-0.7.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 3.1.0](https://img.shields.io/badge/AppVersion-3.1.0-informational?style=flat-square)

Trade Data Tool (UNSD) — seven .NET microservices and a Blazor web UI for processing trade datasets. Provisions its database serverlessly on the platform's shared MariaDB cluster and stores files in bundled MinIO or S3.

**Homepage:** <https://code.officialstatistics.org/trade-data-tools/tdt-source/TradeDataTools>

## Before you start

- **This version needs a new service.** Trade Data Tool 2.x services (chart 0.6.x or earlier) keep running and resume as they are, but they can't be upgraded to 3.x. Your datasets, metadata, rules and users don't carry over: set them up again in the new service, then import your files.
- **Keep your data before you delete an old service.** Deleting a service permanently deletes its database (datasets, rules, configuration) and its rule notebooks. With the built-in file storage, your uploaded files are deleted too. With your own S3 storage they stay in your bucket, but a new service won't recognise them as datasets. Keep the old service until you have downloaded what you need, and keep your source files.
- **Dates now default to day-first.** When you import a dataset file, a new *Date/Time Format* option defaults to **Day-month-year (31/12/2025)**. Previously, ambiguous dates such as 03/04/2025 were read month-first. Choose *Month-day-year* or *Year-month-day* if your files use those layouts. The old *Regional Format* option is now called *Decimal Format*.

## What's new in 3.x

Trade Data Tool 3.x is based on upstream TDT 2.5.0. This chart ships 3.1.0.

**Find and download data**
- **Data Search** (formerly *Advance Search*): faster paging with Previous/Next, an estimated total with a *Show exact* button, sorting by indexed columns. Queries stop after 30 seconds and suggest *Download All*.
- **Saved searches**: save a Data Search and reopen it later.
- **Download All, then My Downloads** (new menu item): large downloads run in the background as compressed files you collect from *My Downloads*. Files are kept for 7 days.
- **Quick downloads** (*Download Data*) are still limited to 100,000 rows and 30 columns, and now stop after 30 seconds. Use *Download All* for anything bigger.
- **Tables**: choose and resize columns; your page size is remembered in this browser.
- The *Bronze / Silver / Gold* data links have left the side menu. Open the data from a dataset's *View Data* action or the dashboard links instead.

**Bring data in**
- **JSON files** can be imported.
- **Import mapping presets**: save and reuse column mappings.
- **Move files** between buckets.

**Run and monitor the pipeline**
- **Pipeline Jobs** refreshes every 5 seconds, adds new statuses (Retry, Resetting, Deleting, Cancelled) and a *View Log* action, and asks for confirmation before cancelling.
- **Retry from step**: re-run a failed batch from a chosen step. Zeppelin rule steps run again.
- **Reset** and **Delete batch** now run in the background and survive a restart.
- **Gold upgrade by year** and **Recalculate period summary**.
- **Uninitialize dataset** (new, next to *Delete*) clears a Silver dataset so you can change its structure. It also deletes the Silver's child Bronze datasets. Dependent Gold datasets are kept unless you untick them, and the dialog lists what will be deleted.

**Data quality**
- **Constraint stage**: a new pipeline step checks that values do, or do not, exist in a metadata table, with its own tab in the Error Wizard.
- The **Error Wizard** acts on at most 10,000 records at a time; use *Download All* for the full list.

**Metadata**
- Metadata **categories**, default code/description attributes, adding columns to initialized metadata, an *Include in Search* flag, and faster paged metadata lists.

**Sign-in and screens**
- You're signed out after **60 minutes of inactivity**.
- The app version is shown in the side menu.
- Dataset actions are renamed: *View/Clone/Edit Structure*, plus *Alter Dataset* for initialized Silver datasets.

## Lifecycle and data

- **Suspension.** Onyxia suspends a service 13 hours after it was launched or last resumed, whether or not you are using it. Its pods stop; its database, files and rule notebooks are kept. Resume it from *My Services*.
- **Work in progress.** If a batch is importing or running pipeline steps when the service is suspended, it is recovered up to about 4.5 hours after you resume, and you can then *Retry* it.
- **Automatic deletion.** A service left suspended for **30 days is deleted, with its data**: its database, its rule notebooks and, with the built-in file storage, your uploaded files. Resume it, or download what you need, before then.
- **Deleting a service** deletes the same data straight away. With your own S3 storage, files stay in your bucket but are no longer attached to any Trade Data Tool service.
- **S3 storage.** S3 access uses temporary credentials that expire about 11 hours after launch and are not renewed when the service resumes. Use the built-in file storage (MinIO, the default) for work that lasts longer than a day.
- **First launch** can take several minutes while the database is set up. The service shows as running once the web UI answers.
- **If the first launch fails** partway through setting up the database, the service cannot repair itself. Delete it and launch a new one.
- **Rule-engine settings.** The rule-engine connection settings in *System Configuration* are managed by the platform. Don't edit them: they're overwritten each time the service is launched, resumed or reconfigured, and a wrong value can stop rules from running until then.

## Upgrading

Chart 0.7.0 (app 3.1.0) is a **fresh install only**. App 3.x uses a new database layout and cannot take over a database created by chart 0.6.x or earlier (app 2.x).

- From Onyxia, nothing changes for existing services: resuming re-runs the chart version they were launched with.
- With the helm CLI, `helm upgrade` from 0.6.x to 0.7.0 is refused before anything is changed. Keep the release on 0.6.x, or uninstall it (this deletes its data, as above), install 0.7.0 and import the data again.

## Third-party software

- **MinIO** (the built-in file storage) is licensed under the [GNU AGPL v3.0](https://www.gnu.org/licenses/agpl-3.0.html). By default this chart runs our MinIO image (`tdt/minio`), built from MinIO's source at commit [`7aac2a2c5b7c`](https://github.com/minio/minio/tree/7aac2a2c5b7c882e68c1ce017d8256be2feea27f) with updated Go dependencies and one small security patch. The patch, the dependency files and the build file are published in [`third-party/minio/`](https://github.com/UNGlobalPlatform/helm-charts-interactive-services/tree/main/charts/trade-data-tool/third-party/minio).
  - **Use root credentials only.** Never enable MinIO's OIDC or LDAP login, whether through `MINIO_IDENTITY_OPENID_*` / `MINIO_IDENTITY_LDAP_*` settings or `mc admin config set … identity_openid|identity_ldap`. MinIO's own OIDC and LDAP login code has known critical vulnerabilities with no upstream fix, because MinIO's open-source project is archived. The chart sets only the root credentials, so neither is enabled as shipped.
  - **Credentials are generated per release** and kept in the `<release>-trade-data-tool-minio` Secret; nobody needs them, because TDT reaches MinIO only through its own services. If an administrator ever recreates that Secret, restart the MinIO and FileService deployments together: both read the credentials only at start.

## Source Code

* <https://code.officialstatistics.org/trade-data-tools/tdt-source/TradeDataTools>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../zeppelin | zeppelin | 1.4.2 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| database.auth.password | string | `"changeme"` |  |
| database.cluster.name | string | `"production"` |  |
| database.cluster.namespace | string | `"mariadb"` |  |
| database.connections.tier | string | `"medium"` |  |
| database.discoverable | bool | `true` |  |
| database.lifecycle.retainOnDelete | bool | `false` |  |
| database.schema.bootstrap | bool | `true` |  |
| database.schema.image | string | `"mariadb-service"` |  |
| extraAppSettings | object | `{}` |  |
| global.suspend | bool | `false` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.pullSecretName | string | `""` |  |
| image.registry | string | `"142496269814.dkr.ecr.us-west-2.amazonaws.com/tdt"` |  |
| image.tag | string | `"v3.1.0"` |  |
| ingress.certManagerClusterIssuer | string | `"letsencrypt-prod"` |  |
| ingress.enabled | bool | `true` |  |
| ingress.hostname | string | `"chart-example.local"` |  |
| ingress.ingressClassName | string | `"nginx"` |  |
| ingress.tls | bool | `true` |  |
| ingress.useCertManager | bool | `true` |  |
| networkPolicy.enabled | bool | `true` |  |
| networkPolicy.ingressNamespace | string | `"ingress-apisix"` |  |
| objectStorage.buckets.domain | string | `"domainfile"` |  |
| objectStorage.buckets.metadata | string | `"metadatafile"` |  |
| objectStorage.buckets.system | string | `"system"` |  |
| objectStorage.minio.image | string | `""` |  |
| objectStorage.minio.ingress.hostname | string | `""` |  |
| objectStorage.minio.persistence.retainOnDelete | bool | `false` |  |
| objectStorage.minio.persistence.size | string | `"10Gi"` |  |
| objectStorage.minio.persistence.storageClass | string | `""` |  |
| objectStorage.minio.resources.limits.cpu | string | `"500m"` |  |
| objectStorage.minio.resources.limits.memory | string | `"512Mi"` |  |
| objectStorage.minio.resources.requests.cpu | string | `"50m"` |  |
| objectStorage.minio.resources.requests.memory | string | `"256Mi"` |  |
| objectStorage.provider | string | `"minio"` |  |
| objectStorage.s3.accessKeyId | string | `""` |  |
| objectStorage.s3.endpoint | string | `""` |  |
| objectStorage.s3.forcePathStyle | bool | `false` |  |
| objectStorage.s3.region | string | `""` |  |
| objectStorage.s3.secretAccessKey | string | `""` |  |
| objectStorage.s3.sessionToken | string | `""` |  |
| objectStorage.s3.workingDirectoryPath | string | `""` |  |
| readiness.enabled | bool | `true` |  |
| readiness.image | string | `"public.ecr.aws/docker/library/busybox:1.36"` |  |
| resources.limits.cpu | string | `"500m"` |  |
| resources.limits.memory | string | `"512Mi"` |  |
| resources.requests.cpu | string | `"50m"` |  |
| resources.requests.memory | string | `"256Mi"` |  |
| ruleEngine.defaultInterpreterGroup | string | `"jdbc"` |  |
| ruleEngine.external.apiUrl | string | `""` |  |
| ruleEngine.external.password | string | `""` |  |
| ruleEngine.external.username | string | `""` |  |
| ruleEngine.external.webUrl | string | `""` |  |
| security.admin.deactivateUsernames[0] | string | `"DAdmin"` |  |
| security.admin.password | string | `"changeme"` |  |
| security.admin.seed | bool | `true` |  |
| security.admin.seedImage | string | `"public.ecr.aws/docker/library/python:3.12-slim"` |  |
| security.admin.username | string | `"SAdmin"` |  |
| security.jwt.key | string | `""` |  |
| services.coreservice.image | string | `"core-service"` |  |
| services.coreservice.port | int | `6912` |  |
| services.coreservice.resources.limits.cpu | string | `"2000m"` |  |
| services.coreservice.resources.limits.memory | string | `"1Gi"` |  |
| services.coreservice.resources.requests.cpu | string | `"100m"` |  |
| services.coreservice.resources.requests.memory | string | `"256Mi"` |  |
| services.dataservice.image | string | `"data-service"` |  |
| services.dataservice.port | int | `6901` |  |
| services.domainservice.image | string | `"domain-service"` |  |
| services.domainservice.port | int | `6902` |  |
| services.fileservice.image | string | `"file-service"` |  |
| services.fileservice.port | int | `6702` |  |
| services.metadataservice.image | string | `"metadata-service"` |  |
| services.metadataservice.port | int | `6801` |  |
| services.ruleengineservice.image | string | `"ruleengine-service"` |  |
| services.ruleengineservice.port | int | `8402` |  |
| services.userservice.image | string | `"user-service"` |  |
| services.userservice.port | int | `6904` |  |
| uploads.allowedExtensions | string | `"tsv,txt,csv"` |  |
| uploads.importAllowedExtensions | string | `"xlsx,csv,txt"` |  |
| uploads.maxFileSizeBytes | int | `314572900` |  |
| userPreferences.language | string | `"en"` |  |
| web.image | string | `"web-app"` |  |
| web.port | int | `7108` |  |
| web.resources.limits.cpu | string | `"500m"` |  |
| web.resources.limits.memory | string | `"1Gi"` |  |
| web.resources.requests.cpu | string | `"50m"` |  |
| web.resources.requests.memory | string | `"256Mi"` |  |
| zeppelin.defaultInterpreterGroup | string | `"jdbc"` |  |
| zeppelin.enabled | bool | `true` |  |
| zeppelin.ingress.certManagerClusterIssuer | string | `"letsencrypt-prod"` |  |
| zeppelin.ingress.enabled | bool | `true` |  |
| zeppelin.ingress.hostname | string | `"chart-example-zeppelin.local"` |  |
| zeppelin.ingress.ingressClassName | string | `"nginx"` |  |
| zeppelin.ingress.useCertManager | bool | `true` |  |
| zeppelin.jdbc.configImage | string | `"public.ecr.aws/docker/library/python:3.12-slim"` |  |
| zeppelin.jdbc.existingSecret | string | `"{{ .Release.Name }}-jdbc-target"` |  |
| zeppelin.persistence.enabled | bool | `true` |  |
| zeppelin.persistence.retainOnDelete | bool | `false` |  |
| zeppelin.persistence.size | string | `"10Gi"` |  |
| zeppelin.resources.limits.cpu | string | `"2000m"` |  |
| zeppelin.resources.limits.memory | string | `"4Gi"` |  |
| zeppelin.resources.requests.cpu | string | `"250m"` |  |
| zeppelin.resources.requests.memory | string | `"1Gi"` |  |
| zeppelin.route.enabled | bool | `false` |  |
| zeppelin.security.password | string | `"changeme"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.0](https://github.com/norwoodj/helm-docs/releases/v1.11.0)
