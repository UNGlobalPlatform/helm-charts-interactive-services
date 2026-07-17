{{/*
Chart-local helpers. The MariaDB discovery templates mirror the library
chart's _secret_postgresql_discovery.tpl; the vendored library-chart release
has no MariaDB variant, so they live here until it grows one.
*/}}

{{/*
Decode a value from a discovery secret's data map. The catalog's mariadb
chart writes mariadb-port UNencoded into data: ("3306" happens to be valid
base64 alphabet, so it slips through — but b64dec turns it into garbage).
Digits-as-is means the raw value; anything else is real base64.
*/}}
{{- define "zeppelin.discoveryDecode" -}}
{{- $raw := . | toString -}}
{{- if regexMatch "^[0-9]+$" $raw }}{{ $raw }}{{ else }}{{ $raw | b64dec }}{{ end -}}
{{- end }}

{{/*
Resolve the JDBC target: explicit .Values.jdbc.* wins (set by a parent chart
bundling this one — the parent knows its own database at render time, and a
release can never `lookup` a secret it is itself creating); otherwise the
first onyxia/discovery "mariadb" secret in the namespace. Returns a JSON map,
or empty when there is no source.
*/}}
{{- define "zeppelin.jdbcSource" -}}
{{- $j := .Values.jdbc | default dict }}
{{- if $j.host }}
{{- dict "host" $j.host
         "port" ($j.port | default 3306 | toString)
         "database" ($j.database | default "")
         "username" ($j.username | default "")
         "password" ($j.password | default "") | toJson }}
{{- else }}
{{- with first (include "library-chart.getOnyxiaDiscoverySecrets" (list .Release.Namespace "mariadb") | fromJsonArray) }}
{{- dict "host" (index . "mariadb-service" | default "" | b64dec)
         "port" (include "zeppelin.discoveryDecode" (index . "mariadb-port" | default "MzMwNg==") )
         "database" (index . "mariadb-database" | default "" | b64dec)
         "username" (index . "mariadb-username" | default "" | b64dec)
         "password" (index . "password" | default "" | b64dec) | toJson }}
{{- end }}
{{- end }}
{{- end }}

{{/* Create the name of the MariaDB secret to use */}}
{{- define "zeppelin.secretNameMariaDB" -}}
{{- if (.Values.discovery).mariadb }}
{{- $name := printf "%s-secretmariadb" (include "library-chart.fullname" .) }}
{{- default $name (.Values.mariadb).secretName }}
{{- else }}
{{- default "default" (.Values.mariadb).secretName }}
{{- end }}
{{- end }}

{{/* Secret for MariaDB */}}
{{- define "zeppelin.secretMariaDB" }}
{{- $context := . }}
{{- if (.Values.discovery).mariadb }}
{{- with $secretData := first (include "library-chart.getOnyxiaDiscoverySecrets" (list .Release.Namespace "mariadb") | fromJsonArray) -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "zeppelin.secretNameMariaDB" $context }}
  labels:
    {{- include "library-chart.labels" $context | nindent 4 }}
stringData:
  MARIADB_HOST: {{ index $secretData "mariadb-service" | default "" | b64dec | quote }}
  MARIADB_PORT: {{ include "zeppelin.discoveryDecode" (index $secretData "mariadb-port" | default "MzMwNg==") | quote }}
  MARIADB_DATABASE: {{ index $secretData "mariadb-database" | default "" | b64dec | quote }}
  MARIADB_USER: {{ index $secretData "mariadb-username" | default "" | b64dec | quote }}
  MARIADB_PASSWORD: {{ index $secretData "password" | default "" | b64dec | quote }}
{{- end }}
{{- end }}
{{- end }}

{{- define "zeppelin.mariadb-discovery-help" -}}
{{- if (.Values.discovery).mariadb }}
{{- if first (include "library-chart.getOnyxiaDiscoverySecrets" (list .Release.Namespace "mariadb") | fromJsonArray) }}
The connection to your MariaDB service is preconfigured through environment variables.
From a `%python` paragraph (`pip install mariadb` or `pymysql` first):
```python
import os
import pymysql
conn = pymysql.connect(
    host=os.environ["MARIADB_HOST"],
    port=int(os.environ["MARIADB_PORT"]),
    user=os.environ["MARIADB_USER"],
    password=os.environ["MARIADB_PASSWORD"],
    database=os.environ["MARIADB_DATABASE"],
)
with conn.cursor() as cur:
    cur.execute("SELECT version();")
    print(cur.fetchone())
conn.close()
```
{{- end }}
{{- end }}
{{- end -}}
