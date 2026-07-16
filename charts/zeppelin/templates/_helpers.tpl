{{/*
Chart-local helpers. The MariaDB discovery templates mirror the library
chart's _secret_postgresql_discovery.tpl; the vendored library-chart release
has no MariaDB variant, so they live here until it grows one.
*/}}

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
  MARIADB_PORT: {{ index $secretData "mariadb-port" | default "" | b64dec | quote }}
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
