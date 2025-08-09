
{{- define "unibox.deployment.service" -}}

  {{- include "unibox.foreach" (dict
    "singleKey" "service"
    "prefixName" .name
    "callback" "unibox.service"
    "callbackArgs" (dict "nameComponent" .name "scopeComponent" .scope)
    "ctx" .ctx "scope" .scope
  ) -}}

{{- end -}}


{{- define "unibox.service" -}}

  {{- template "unibox.document" (dict
    "apiVersion" (include "unibox.capabilities.service.apiVersion" .ctx)
    "kind" "Service"
  ) -}}

  {{- template "unibox.metadata" (dict
    "name" .nameFull
    "component" .nameComponent
    "isNamespaced" true
    "ctx" .ctx "scope" .scope
  ) -}}

  {{- print "\nspec:" -}}

  {{- include "unibox.selector" (dict
    "labelsKey" "podLabels"
    "component" .nameComponent
    "ctx" .ctx "scope" .scopeComponent
  ) | indent 2 -}}

  {{- $type := list "ClusterIP" "ExternalName" "LoadBalancer" "NodePort"
      | dict "scope" .scope "key" "type" "ctx" .ctx "default" "ClusterIP" "list"
      | include "unibox.render.enum" -}}

  {{- template "unibox.validate.map" (list .scope (printf "service.%s" $type)) -}}

  {{- quote $type | printf "type: %s" | nindent 2 -}}

  {{- include "unibox.service.ports" . | indent 2 -}}

{{- end -}}

{{- define "unibox.service.ports" -}}
  {{- if (list .scope "ports" "map" | include "unibox.validate.type") -}}

    {{- print "\nports:" -}}

    {{- include "unibox.foreach" (dict
      "singleKey" false
      "pluralKey" "ports"
      "callback" "unibox.service.ports.entry"
      "asArray" true
      "isEntryMap" false
      "ctx" .ctx "scope" .scope
    ) -}}

  {{- end -}}
{{- end -}}

{{- define "unibox.service.getPorts" -}}
    {{- include "unibox.foreach" (dict
      "singleKey" false
      "pluralKey" "ports"
      "callback" "unibox.service.getPorts.callback"
      "asArray" true
      "isEntryMap" false
      "ctx" .ctx "scope" .scope
    ) -}}
{{- end -}}

{{- define "unibox.service.ports.entry" -}}
  {{- /* TODO: here we should validate whether uplevel deployment/statefulset has any container with current port name. */ -}}
  {{- quote .name | printf "name: %s" -}}
  {{- dict "scope" .scopeParent "key" .name "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi | printf "\nport: %d" -}}
  {{- printf "\nprotocol: TCP" -}}
  {{- quote .name | printf "\ntargetPort: %s" -}}
{{- end -}}

{{- define "unibox.service.getPorts.callback" -}}
  {{- quote .name -}}
{{- end -}}
