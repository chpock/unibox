
{{- define "unibox.deployment.service" -}}

  {{- include "unibox.foreach" (dict
    "singleKey" "service"
    "prefixName" .name
    "callback" "unibox.service"
    "callbackArgs" (dict "nameComponent" .name "scopeComponent" .scope)
    "asArray" true
    "ctx" .ctx "scope" .scope
  ) -}}

{{- end -}}


{{- define "unibox.service" -}}

  {{- $document := include "unibox.document" (dict
    "apiVersion" (include "unibox.capabilities.service.apiVersion" .ctx)
    "kind" "Service"
  ) | fromJson -}}

  {{- $_ := include "unibox.metadata" (dict
    "name" .nameFull
    "component" .nameComponent
    "isNamespaced" true
    "ctx" .ctx "scope" .scope
  ) | fromJson | merge $document -}}

  {{- $spec := dict -}}

  {{- $_ := include "unibox.selector" (dict
    "labelsKey" "podLabels"
    "component" .nameComponent
    "ctx" .ctx "scope" .scopeComponent
  ) | fromJson | merge $spec -}}

  {{- $type := list "ClusterIP" "ExternalName" "LoadBalancer" "NodePort"
      | dict "scope" .scope "key" "type" "ctx" .ctx "default" "ClusterIP" "list"
      | include "unibox.render.enum" -}}

  {{- template "unibox.validate.map" (list .scope (printf "service.%s" $type)) -}}

  {{- $_ := set $spec "type" $type -}}

  {{- $_ := include "unibox.service.ports" . | fromJson | merge $spec -}}

  {{- $_ := set $document "spec" $spec -}}

  {{- toJson $document -}}

{{- end -}}

{{- define "unibox.service.ports" -}}
  {{- if (list .scope "ports" "map" | include "unibox.validate.type") -}}

    {{- $ports := include "unibox.foreach" (dict
      "singleKey" false
      "pluralKey" "ports"
      "callback" "unibox.service.ports.entry"
      "asArray" true
      "isEntryMap" false
      "ctx" .ctx "scope" .scope
    ) | fromJsonArray -}}

    {{- dict "ports" $ports | toJson -}}

  {{- else -}}
    {{- dict | toJson -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.service.getPorts" -}}
  {{- include "unibox.foreach" (dict
    "singleKey" false
    "pluralKey" "ports"
    "callback" "unibox.service.getPorts.callback"
    "asArray" true
    "asText" true
    "isEntryMap" false
    "ctx" .ctx "scope" .scope
  ) -}}
{{- end -}}

{{- define "unibox.service.ports.entry" -}}
  {{- /* TODO: here we should validation whether uplevel deployment/statefulset has any container with current port name. */ -}}
  {{- dict
    "name" .name
    "port" (dict "scope" .scopeParent "key" .name "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi)
    "protocol" "TCP"
    "targetPort" .name
  | toJson -}}
{{- end -}}

{{- define "unibox.service.getPorts.callback" -}}
  {{- .name -}}
{{- end -}}
