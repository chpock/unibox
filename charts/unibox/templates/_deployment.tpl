
{{- define "unibox.deployment" -}}

  {{- if not (or (hasKey .scope "container") (hasKey .scope "containers")) -}}
    {{- list .scope "there are no containers defined in the deployment, please define at least one container in this deployment using the .container or .containers fields" | include "unibox.fail" -}}
  {{- end -}}

  {{- template "unibox.document" (dict
    "apiVersion" (include "unibox.capabilities.deployment.apiVersion" $)
    "kind" "Deployment"
  ) -}}

  {{- $nameFull := include "unibox.name" (dict "isFull" true "name" .name "ctx" .ctx "scope" .scope) -}}

  {{- template "unibox.metadata" (dict
    "name" $nameFull
    "component" .name
    "isNamespaced" true
    "ctx" .ctx "scope" .scope
  ) -}}

  {{- print "\nspec:" -}}

  {{- if (list .scope "updateStrategy" "map" | include "unibox.validate.type") -}}
    {{- print "strategy:" | nindent 2 -}}
    {{- include "unibox.render" (dict "value" .scope.updateStrategy "ctx" .ctx "scope" .scope) | nindent 4 -}}
  {{- end -}}

  {{- include "unibox.selector" (dict
    "labelsKey" "podLabels"
    "component" .name
    "ctx" .ctx "scope" .scope
  ) | indent 2 -}}

  {{- include "unibox.podTemplate" (dict
    "labelsKey" "podLabels"
    "annotationsKey" "podAnnotations"
    "component" .name
    "kindParent" "deployment"
    "ctx" .ctx "scope" .scope
  ) | indent 2 -}}

{{- end -}}