
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

  {{- $_ := set $spec "containers" $containers -}}
  {{- $_ := set $document "spec" $spec -}}

  {{- toJson $document -}}

{{- end -}}
