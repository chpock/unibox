
{{- define "unibox.deployment" -}}

  {{- if not (or (hasKey .scope "container") (hasKey .scope "containers")) -}}
    {{- list .scope "there are no containers defined in the deployment, please define at least one container in this deployment using the .container or .containers fields" | include "unibox.fail" -}}
  {{- end -}}

  {{- $document := include "unibox.document" (dict
    "apiVersion" (include "unibox.capabilities.deployment.apiVersion" .ctx)
    "kind" "Deployment"
  ) | fromJson -}}

  {{- $_ := include "unibox.metadata" (dict
    "name" .nameFull
    "component" .name
    "isNamespaced" true
    "ctx" .ctx "scope" .scope
  ) | fromJson | merge $document -}}

  {{- $spec := dict -}}

  {{- $_ := include "unibox.selector" (dict
    "labelsKey" "podLabels"
    "component" .name
    "ctx" .ctx "scope" .scope
  ) | fromJson | merge $spec -}}

  {{- $replicas := 1 -}}
  {{- if (hasKey .scope "replicas") -}}
    {{- $replicas = dict "scope" .scope "key" "replicas" "ctx" .ctx | include "unibox.render.integer" | atoi -}}
  {{- end -}}
  {{- $_ := set $spec "replicas" $replicas -}}

  {{- if (list .scope "updateStrategy" "map" | include "unibox.validate.type") -}}
    {{- $strategy := include "unibox.render" (dict "value" .scope.updateStrategy "ctx" .ctx "scope" .scope) | fromYaml -}}
    {{- $_ := set $spec "strategy" $strategy -}}
  {{- end -}}

  {{- $_ := include "unibox.podTemplate" (dict
    "labelsKey" "podLabels"
    "annotationsKey" "podAnnotations"
    "component" .name
    "kindParent" "deployment"
    "ctx" .ctx "scope" .scope
  ) | fromJson | dict "template" | merge $spec -}}

  {{- $_ := set $document "spec" $spec -}}

  {{- toJson $document -}}

{{- end -}}