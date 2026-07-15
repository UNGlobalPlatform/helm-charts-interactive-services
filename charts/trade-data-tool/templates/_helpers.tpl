{{/*
Expand the name of the chart.
*/}}
{{- define "tdt.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified name, DNS-capped.
*/}}
{{- define "tdt.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "tdt.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "tdt.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Tenant prefix: release namespace with '-' -> '_'. The platform's Kyverno
tenancy policies REQUIRE database/user names to carry this prefix.
*/}}
{{- define "tdt.tenantPrefix" -}}
{{- .Release.Namespace | replace "-" "_" }}
{{- end }}

{{/*
Release-scoped database/user identifier: <tenantPrefix>_<release>. Deriving it
from the release name (not a fixed "tdt") means two TDT services in the same
namespace get DISTINCT databases and users — so uninstalling one can never drop
the other's data. Still carries the tenant prefix required by the Kyverno
policies, sanitized to the identifier charset and capped at 64 (MariaDB's db
limit; usernames allow 80, so 64 is safe for both).
*/}}
{{- define "tdt.dbIdentifier" -}}
{{- $clean := .Release.Name | lower | replace "-" "_" -}}
{{- $slug := regexReplaceAll "[^a-z0-9_]+" $clean "_" | trimSuffix "_" -}}
{{- printf "%s_%s" (include "tdt.tenantPrefix" .) $slug | trunc 64 | trimSuffix "_" }}
{{- end }}

{{- define "tdt.dbName" -}}
{{- include "tdt.dbIdentifier" . }}
{{- end }}

{{- define "tdt.dbUserName" -}}
{{- include "tdt.dbIdentifier" . }}
{{- end }}

{{/*
FQDN of the shared MariaDB (server lives in another namespace).
*/}}
{{- define "tdt.dbHost" -}}
{{- printf "%s.%s.svc.cluster.local" .Values.database.cluster.name .Values.database.cluster.namespace }}
{{- end }}

{{- define "tdt.dbCleanupPolicy" -}}
{{- if .Values.database.lifecycle.retainOnDelete }}Skip{{- else }}Delete{{- end }}
{{- end }}

{{- define "tdt.dbMaxUserConnections" -}}
{{- $tiers := dict "small" 10 "medium" 50 "large" 200 }}
{{- get $tiers .Values.database.connections.tier | default 50 }}
{{- end }}

{{/*
The single MariaDB connection string every service uses (single-db schema).
*/}}
{{- define "tdt.connectionString" -}}
{{- printf "Server=%s;Port=3306;Database=%s;Uid=%s;Pwd=%s;SslMode=none"
      (include "tdt.dbHost" .) (include "tdt.dbName" .)
      (include "tdt.dbUserName" .) .Values.database.auth.password }}
{{- end }}

{{/*
Kubernetes Service name for a component key (fileservice, web, ...).
*/}}
{{- define "tdt.svcName" -}}
{{- printf "%s-%s" (include "tdt.fullname" .ctx) .key | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
In-cluster API base URL for a component: http://<svc>:<port>/api/<Path>/
*/}}
{{- define "tdt.apiUrl" -}}
{{- printf "http://%s:%d/api/%s/" (include "tdt.svcName" (dict "ctx" .ctx "key" .key)) (int .port) .path }}
{{- end }}

{{- define "tdt.minioSvcName" -}}
{{- printf "%s-minio" (include "tdt.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
JWT signing key: explicit value or a per-release derivation that is stable
across upgrades (release UID would be ideal but isn't available; derive from
namespace+name+db password so it survives helm upgrade).
*/}}
{{- define "tdt.jwtKey" -}}
{{- if .Values.security.jwt.key }}
{{- .Values.security.jwt.key }}
{{- else }}
{{- printf "%s|%s|%s|jwt" .Release.Namespace .Release.Name .Values.database.auth.password | sha256sum }}
{{- end }}
{{- end }}

{{/*
The shared appsettings.Production.json. ASP.NET merges this over each image's
baked-in appsettings.json, so only overrides need to appear here. One file
serves all services: each reads only the keys it cares about, and they all
share the same database and object store anyway.
*/}}
{{- define "tdt.appsettings" -}}
{{- $conn := include "tdt.connectionString" . }}
{{- $svc := dict }}
{{- range $key, $s := .Values.services }}
{{- $_ := set $svc $key (dict "name" (include "tdt.svcName" (dict "ctx" $ "key" $key)) "port" $s.port) }}
{{- end }}
{{- $urls := dict
      "FileService"     (include "tdt.apiUrl" (dict "ctx" . "key" "fileservice"     "port" (get (get $svc "fileservice") "port")     "path" "File"))
      "MetadataService" (include "tdt.apiUrl" (dict "ctx" . "key" "metadataservice" "port" (get (get $svc "metadataservice") "port") "path" "Metadata"))
      "DomainService"   (include "tdt.apiUrl" (dict "ctx" . "key" "domainservice"   "port" (get (get $svc "domainservice") "port")   "path" "domain"))
      "CoreService"     (include "tdt.apiUrl" (dict "ctx" . "key" "coreservice"     "port" (get (get $svc "coreservice") "port")     "path" "DataProcessing"))
      "DataService"     (include "tdt.apiUrl" (dict "ctx" . "key" "dataservice"     "port" (get (get $svc "dataservice") "port")     "path" "Data"))
      "RuleService"     (include "tdt.apiUrl" (dict "ctx" . "key" "ruleengineservice" "port" (get (get $svc "ruleengineservice") "port") "path" "Rule"))
      "UserService"     (include "tdt.apiUrl" (dict "ctx" . "key" "userservice"     "port" (get (get $svc "userservice") "port")     "path" "User"))
}}
{{- $cfg := dict }}
{{- /* Every connection-string key any service reads — all one database now. */}}
{{- $_ := set $cfg "ConnectionStrings" (dict
      "CoreDBConnection" $conn "DomainDBConnection" $conn "MetadataDBConnection" $conn
      "FilesDBConnection" $conn "UserDBConnection" $conn "DBConnection" $conn
      "LogDBConnection" $conn "DatasetDBConnection" $conn) }}
{{- /* Direct service URLs; Dapr bypassed (DaprURL == LocalUrl, EnforceDapr false). */}}
{{- range $name, $url := $urls }}
{{- $_ := set $cfg $name (dict "LocalUrl" $url "DaprURL" $url "DaprPort" "3500" "DaprHealthURL" "http://localhost:{0}/v1.0/healthz") }}
{{- end }}
{{- $_ := set $cfg "Dapr" (dict "EnforceDapr" false) }}
{{- $_ := set (get $cfg "FileService") "ImportDomainBucket" .Values.objectStorage.buckets.domain }}
{{- $_ := set (get $cfg "FileService") "ImportMetadataBucket" .Values.objectStorage.buckets.metadata }}
{{- if eq .Values.objectStorage.provider "minio" }}
{{- $minioHost := printf "%s:9000" (include "tdt.minioSvcName" .) }}
{{- $_ := set $cfg "MinioConfig" (dict
      "EndPoint" $minioHost "ApiUrl" $minioHost "ConsoleUrl" $minioHost
      "AccessKey" .Values.objectStorage.minio.rootUser
      "SecretKey" .Values.objectStorage.minio.rootPassword
      "UseSSL" false "ContentType" "application/octet-stream") }}
{{- $_ := set $cfg "ObjectStorage" (dict "Provider" "minio") }}
{{- else }}
{{- $s3 := dict "Region" .Values.objectStorage.s3.region "ForcePathStyle" .Values.objectStorage.s3.forcePathStyle }}
{{- if .Values.objectStorage.s3.endpoint }}{{- $_ := set $s3 "Endpoint" .Values.objectStorage.s3.endpoint }}{{- end }}
{{- /* Onyxia gives one shared bucket + a per-user prefix as workingDirectoryPath
       (e.g. "datalab-<acct>-user-bucket/user-<handle>/"). Split it: first path
       segment is the real bucket, the rest is the base prefix the logical buckets
       (domainfile/…) live under. FileService folds its logical buckets into this. */}}
{{- $wd := trimAll "/" (.Values.objectStorage.s3.workingDirectoryPath | default "") }}
{{- if $wd }}
{{- $parts := splitList "/" $wd }}
{{- $_ := set $s3 "Bucket" (first $parts) }}
{{- $_ := set $s3 "BasePrefix" (rest $parts | join "/") }}
{{- end }}
{{- $_ := set $cfg "ObjectStorage" (dict "Provider" "s3" "S3" $s3) }}
{{- end }}
{{- $_ := set $cfg "DatasetProcessingSettings" (dict "BucketName" .Values.objectStorage.buckets.system) }}
{{- /* The JWT signing key. UserService SIGNS with Jwt:Key (HelperMethod.cs) but
       the Web VALIDATES with JWTSettings:Key (JwtTokenHelper.cs) — two different
       config paths that happen to hold the same baked value upstream. Overriding
       only one leaves the web validating against a stale key: login succeeds then
       the very next request bounces to /login. Set BOTH to the per-release key. */}}
{{- $jwtKey := include "tdt.jwtKey" . }}
{{- $_ := set $cfg "Jwt" (dict "Key" $jwtKey "Issuer" "unsd.com" "Audience" "Your_Audience") }}
{{- $_ := set $cfg "JWTSettings" (dict "Key" $jwtKey "ValidIssuer" "unsd.com" "Audience" "Your_Audience") }}
{{- $merged := mustMergeOverwrite $cfg (deepCopy .Values.extraAppSettings) }}
{{- mustToPrettyJson $merged }}
{{- end }}
