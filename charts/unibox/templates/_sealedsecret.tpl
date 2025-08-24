
{{- define "unibox.sealedSecret" -}}

  {{- $document := include "unibox.document" (dict
    "apiVersion" (include "unibox.capabilities.sealedSecret.apiVersion" .ctx)
    "kind" "SealedSecret"
  ) | fromJson -}}

  {{- $secretScope := list "strict" "namespace" "cluster"
      | dict "scope" .scope "key" "scope" "ctx" .ctx "default" "strict" "list"
      | include "unibox.render.enum" -}}

  {{- $annotations := dict -}}

  {{- if eq $secretScope "namespace" -}}
    {{- $_ := set $annotations "sealedsecrets.bitnami.com/namespace-wide" "true" -}}
  {{- else if eq $secretScope "cluster" -}}
    {{- $_ := set $annotations "sealedsecrets.bitnami.com/cluster-wide" "true" -}}
  {{- else -}}
    {{- $_ := set $annotations "sealedsecrets.bitnami.com/strict" "true" -}}
  {{- end -}}

  {{- $_ := include "unibox.metadata" (dict
    "name" .nameFull
    "isNamespaced" true
    "annotations" $annotations
    "ctx" .ctx "scope" .scope
  ) | fromJson | merge $document -}}

  {{- $spec := dict -}}

  {{- if (list .scope "encryptedData" "map" | include "unibox.validate.type") -}}

    {{- $encryptedData := dict -}}

    {{- $_ := list .scope "encryptedData" | include "unibox.getPath" | set .scope.encryptedData "__path__" -}}
    {{- $ctx := .ctx -}}
    {{- $scope := .scope -}}
    {{- range $key, $value := omit .scope.encryptedData "__path__" -}}
      {{- $_ := list $scope.encryptedData $key "scalar" | include "unibox.validate.type" -}}
      {{- $value = include "unibox.render" (dict "value" $value "ctx" $ctx "scope" $scope) -}}
      {{- $_ := set $encryptedData $key $value -}}
    {{- end -}}

    {{- $_ := set $spec "encryptedData" $encryptedData -}}

  {{- end -}}

  {{- $template := include "unibox.metadata" (dict
    "annotationsKey" "secretAnnotations"
    "labelsKey" "secretLabels"
    "isNamespaced" false
    "ctx" .ctx "scope" .scope
  ) | fromJson -}}

  {{- if (list .scope "type" "scalar" | include "unibox.validate.type") -}}
    {{- $type := include "unibox.render" (dict "value" .scope.type "ctx" .ctx "scope" .scope) -}}
    {{- $_ := set $template "type" $type -}}
  {{- end -}}

  {{- if (hasKey .scope "immutable") -}}
    {{- $immutable := dict "scope" .scope "key" "immutable" "ctx" .ctx | include "unibox.render.bool" | eq "true" -}}
    {{- $_ := set $template "immutable" $immutable -}}
  {{- end -}}

  {{- if (list .scope "data" "map" | include "unibox.validate.type") -}}

    {{- $data := dict -}}

    {{- $_ := list .scope "data" | include "unibox.getPath" | set .scope.data "__path__" -}}
    {{- $ctx := .ctx -}}
    {{- $scope := .scope -}}
    {{- range $key, $value := omit .scope.data "__path__" -}}
      {{- $_ := list $scope.data $key "scalar" | include "unibox.validate.type" -}}
      {{- $value = include "unibox.render" (dict "value" $value "ctx" $ctx "scope" $scope) -}}
      {{- $_ := set $data $key $value -}}
    {{- end -}}

    {{- $_ := set $template "data" $data -}}

  {{- end -}}

  {{- $_ := set $spec "template" $template -}}

  {{- $_ := set $document "spec" $spec -}}

  {{- toJson $document -}}

{{- end -}}
