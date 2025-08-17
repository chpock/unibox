
{{- define "unibox.deployment.serviceAccount" -}}

  {{- $output := dict | toJson -}}

  {{- if (list .scope "serviceAccount" "map" | include "unibox.validate.type") -}}
    {{- $_ := list .scope "serviceAccount" | include "unibox.getPath" | set .scope.serviceAccount "__path__" -}}
    {{- if (dict "scope" .scope.serviceAccount "key" "create" "ctx" .ctx "scopeLocal" .scope "default" false | include "unibox.render.bool" | eq "true") -}}
      {{- template "unibox.validate.map" (list .scope "serviceAccount" "serviceAccount") -}}
      {{- $output = include "unibox.serviceAccount" (dict
        "nameFull" .nameFull
        "nameComponent" .name
        "ctx" .ctx "scope" .scope.serviceAccount "scopeLocal" .scope
      ) -}}
    {{- end -}}
  {{- end -}}

  {{- $output -}}

{{- end -}}

{{- define "unibox.serviceAccount" -}}

  {{- $document := include "unibox.document" (dict
    "apiVersion" (include "unibox.capabilities.serviceAccount.apiVersion" .ctx)
    "kind" "ServiceAccount"
  ) | fromJson -}}

  {{- $name := .nameFull -}}

  {{- if (list .scope "name" "scalar" | include "unibox.validate.type") -}}
    {{- $name = include "unibox.render" (dict "value" .scope.name "ctx" .ctx "scope" .scopeLocal) -}}
    {{- if not $name -}}
      {{- list .scope "name" "service account name cannot be an empty string" | include "unibox.fail" -}}
    {{- end -}}
  {{- end -}}

  {{- $_ := include "unibox.metadata" (dict
    "name" $name
    "component" .nameComponent
    "isNamespaced" true
    "ctx" .ctx "scope" .scope "scopeLocal" .scopeLocal
  ) | fromJson | merge $document -}}

  {{- $automount := dict "scope" .scope "key" "automount" "ctx" .ctx "scopeLocal" .scopeLocal "default" false | include "unibox.render.bool" | eq "true" -}}
  {{- $_ := set $document "automountServiceAccountToken" $automount -}}

  {{- toJson $document -}}

{{- end -}}

