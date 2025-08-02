
{{- define "unibox.deployment.service" -}}

  {{- include "unibox.foreach" (dict
    "singleKey" "service"
    "defaultName" .name
    "noDefaultNameMessage" "an empty name was specified in the .name or nameOverride fields for this service"
    "callback" "unibox.service"
    "callbackArgs" (dict "nameParent" .name)
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

  {{- print "\nspec:" -}}

  {{- include "unibox.selector" (dict
    "labelsKey" "podLabels"
    "component" .nameParent
    "ctx" .ctx "scope" .scopeParent
  ) | indent 2 -}}

{{- end -}}

