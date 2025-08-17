
{{- define "unibox.podTemplate" -}}

  {{- $document := dict -}}
  {{- $_ := include "unibox.metadata" . | fromJson | merge $document -}}

  {{- $spec := dict -}}

  {{- $containers := include "unibox.foreach" (dict
    "singleKey" "container"
    "defaultName" .component
    "callback" "unibox.container"
    "asArray" true
    "validateMap" "container"
    "ctx" .ctx "scope" .scope
  ) | fromJsonArray -}}

  {{- $serviceAccountName := "default" -}}

  {{- if (list .scope "serviceAccount" "map" | include "unibox.validate.type") -}}
    {{- $_ := list .scope "serviceAccount" | include "unibox.getPath" | set .scope.serviceAccount "__path__" -}}
    {{- if (list .scope.serviceAccount "name" "scalar" | include "unibox.validate.type") -}}
      {{- $serviceAccountName = include "unibox.render" (dict "value" .scope.serviceAccount.name "ctx" .ctx "scope" .scope) -}}
      {{- if not $serviceAccountName -}}
        {{- list .scope.serviceAccount "name" "service account name cannot be an empty string" | include "unibox.fail" -}}
      {{- end -}}
    {{- else if and (hasKey .scope.serviceAccount "create") .scope.serviceAccount.create -}}
      {{- $serviceAccountName = .nameFull -}}
    {{- end -}}
  {{- end -}}

  {{- $_ := dict "containers" $containers "serviceAccountName" $serviceAccountName | merge $spec -}}

  {{- $_ := set $document "spec" $spec -}}

  {{- toJson $document -}}

{{- end -}}
