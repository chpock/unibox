
{{- define "unibox.deployment.service" -}}

  {{- include "unibox.foreach" (dict
    "singleKey" "service"
    "defaultName" .name
    "noDefaultNameMessage" "an empty name was specified in the .name or nameOverride fields for this service"
    "callback" "unibox.service"
    "callbackArgs" (dict "nameOwner" .name "scopeOwner" .scope)
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

  {{- print "\nspec:" -}}

  {{- include "unibox.selector" (dict
    "labelsKey" "podLabels"
    "component" .nameOwner
    "ctx" .ctx "scope" .scopeOwner
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

{{- define "unibox.service.ports.entry" -}}
  {{- /* TODO: here we should validate whether uplevel deployment/statefulset has any container with current port name. */ -}}
  {{- quote .name | printf "name: %s" -}}
  {{- dict "scope" .scopeParent "key" .name "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi | printf "\nport: %d" -}}
  {{- printf "\nprotocol: TCP" -}}
  {{- quote .name | printf "\ntargetPort: %s" -}}
{{- end -}}
