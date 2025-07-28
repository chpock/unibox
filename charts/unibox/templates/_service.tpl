
{{- define "unibox.deployment.service" -}}

  {{- include "unibox.foreach" (dict
    "singleKey" "service"
    "defaultName" .name
    "callback" "unibox.service"
    "validateMap" "service"
    "ctx" .ctx "scope" .scope
  ) -}}

{{- end -}}


{{- define "unibox.service" -}}

  {{- template "unibox.document" (dict
    "apiVersion" (include "unibox.capabilities.service.apiVersion" $)
    "kind" "Service"
  ) -}}

  {{- $nameFull := include "unibox.name" (dict "isFull" true "name" .name "ctx" .ctx "scope" .scope) -}}

  {{- template "unibox.metadata" (dict
    "name" $nameFull
    "component" .name
    "isNamespaced" true
    "ctx" .ctx "scope" .scope
  ) -}}

{{- end -}}

