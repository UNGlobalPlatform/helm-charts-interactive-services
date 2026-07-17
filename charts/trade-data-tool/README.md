# trade-data-tool

![Version: 0.3.0](https://img.shields.io/badge/Version-0.3.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 2.1.0](https://img.shields.io/badge/AppVersion-2.1.0-informational?style=flat-square)

Trade Data Tool (UNSD) — eight .NET microservices and a Blazor web UI for processing trade datasets. Provisions its database serverlessly on the platform's shared MariaDB cluster and stores files in bundled MinIO or S3.

**Homepage:** <https://code.officialstatistics.org/trade-data-tools/tdt-source/TradeDataTools>

## Source Code

* <https://code.officialstatistics.org/trade-data-tools/tdt-source/TradeDataTools>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../zeppelin | zeppelin | 1.3.0 |

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
| image.tag | string | `"v2.1.0"` |  |
| ingress.certManagerClusterIssuer | string | `"letsencrypt-prod"` |  |
| ingress.enabled | bool | `true` |  |
| ingress.hostname | string | `"chart-example.local"` |  |
| ingress.ingressClassName | string | `"nginx"` |  |
| ingress.tls | bool | `true` |  |
| ingress.useCertManager | bool | `true` |  |
| objectStorage.buckets.domain | string | `"domainfile"` |  |
| objectStorage.buckets.metadata | string | `"metadatafile"` |  |
| objectStorage.buckets.system | string | `"system"` |  |
| objectStorage.minio.image | string | `"minio/minio:RELEASE.2024-01-16T16-07-38Z"` |  |
| objectStorage.minio.ingress.hostname | string | `""` |  |
| objectStorage.minio.persistence.retainOnDelete | bool | `false` |  |
| objectStorage.minio.persistence.size | string | `"10Gi"` |  |
| objectStorage.minio.persistence.storageClass | string | `""` |  |
| objectStorage.minio.resources.limits.cpu | string | `"500m"` |  |
| objectStorage.minio.resources.limits.memory | string | `"512Mi"` |  |
| objectStorage.minio.resources.requests.cpu | string | `"50m"` |  |
| objectStorage.minio.resources.requests.memory | string | `"256Mi"` |  |
| objectStorage.minio.rootPassword | string | `"changeme-minio"` |  |
| objectStorage.minio.rootUser | string | `"tdt"` |  |
| objectStorage.provider | string | `"minio"` |  |
| objectStorage.s3.accessKeyId | string | `""` |  |
| objectStorage.s3.endpoint | string | `""` |  |
| objectStorage.s3.forcePathStyle | bool | `false` |  |
| objectStorage.s3.region | string | `""` |  |
| objectStorage.s3.secretAccessKey | string | `""` |  |
| objectStorage.s3.sessionToken | string | `""` |  |
| objectStorage.s3.workingDirectoryPath | string | `""` |  |
| readiness.enabled | bool | `true` |  |
| readiness.image | string | `"busybox:1.36"` |  |
| resources.limits.cpu | string | `"1000m"` |  |
| resources.limits.memory | string | `"1024Mi"` |  |
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
| security.admin.username | string | `"SAdmin"` |  |
| security.jwt.key | string | `""` |  |
| services.coreservice.image | string | `"core-service"` |  |
| services.coreservice.port | int | `6912` |  |
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
| zeppelin.enabled | bool | `true` |  |
| zeppelin.ingress.certManagerClusterIssuer | string | `"letsencrypt-prod"` |  |
| zeppelin.ingress.enabled | bool | `true` |  |
| zeppelin.ingress.hostname | string | `"chart-example-zeppelin.local"` |  |
| zeppelin.ingress.ingressClassName | string | `"nginx"` |  |
| zeppelin.ingress.useCertManager | bool | `true` |  |
| zeppelin.jdbc.existingSecret | string | `"{{ .Release.Name }}-jdbc-target"` |  |
| zeppelin.resources.limits.cpu | string | `"2000m"` |  |
| zeppelin.resources.limits.memory | string | `"4Gi"` |  |
| zeppelin.resources.requests.cpu | string | `"250m"` |  |
| zeppelin.resources.requests.memory | string | `"1Gi"` |  |
| zeppelin.route.enabled | bool | `false` |  |
| zeppelin.security.password | string | `"changeme"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.0](https://github.com/norwoodj/helm-docs/releases/v1.11.0)
