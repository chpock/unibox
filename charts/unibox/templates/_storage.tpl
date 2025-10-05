
{{- define "unibox.storage" -}}

  {{- if not (hasKey .scope "provisioner") -}}
    {{- list .scope "there is no mandatory .provisioner field specified for the storage" | include "unibox.fail" -}}
  {{- end -}}

  {{- $document := include "unibox.document" (dict
    "apiVersion" (include "unibox.capabilities.storage.apiVersion" .ctx)
    "kind" "StorageClass"
  ) | fromJson -}}

  {{- $_ := include "unibox.metadata" (dict
    "name" .nameFull
    "isNamespaced" false
    "ctx" .ctx "scope" .scope
  ) | fromJson | merge $document -}}

  {{- if (hasKey .scope "allowVolumeExpansion") -}}
    {{- $allowVolumeExpansion := dict "scope" .scope "key" "allowVolumeExpansion" "ctx" .ctx | include "unibox.render.bool" | eq "true" -}}
    {{- $_ := set $document "allowVolumeExpansion" $allowVolumeExpansion -}}
  {{- end -}}

  {{/* TODO: add support for "allowedTopologies" */}}

  {{- if (list .scope "mountOptions" "slice" | include "unibox.validate.type") -}}

    {{- $mountOptions := list -}}

    {{- $scope := .scope -}}
    {{- $ctx := .ctx -}}
    {{- range until (len .scope.mountOptions) -}}
      {{- $_ := list $scope "mountOptions" . "scalar" | include "unibox.validate.type" -}}
      {{- $mountOptions = dict "value" (index $scope "mountOptions" .) "ctx" $ctx "scope" $scope | include "unibox.render" | append $mountOptions -}}
    {{- end -}}

    {{- $_ := set $document "mountOptions" $mountOptions -}}

  {{- end -}}
  
  {{- if (list .scope "parameters" "map" | include "unibox.validate.type") -}}

    {{- $parameters := dict -}}

    {{- $_ := list .scope "parameters" | include "unibox.getPath" | set .scope.parameters "__path__" -}}
    {{- $ctx := .ctx -}}
    {{- $scope := .scope -}}
    {{- range $key, $value := omit .scope.parameters "__path__" -}}
      {{- $_ := list $scope.parameters $key "scalar" | include "unibox.validate.type" -}}
      {{- $_ := dict "value" $value "ctx" $ctx "scope" $scope | include "unibox.render" | set $parameters $key -}}
    {{- end -}}

    {{- $_ := set $document "parameters" $parameters -}}

  {{- end -}}

  {{- $provisioner := dict "value" .scope.provisioner "ctx" .ctx "scope" .scope | include "unibox.render" -}}
  {{- $_ := set $document "provisioner" $provisioner -}}

  {{- $reclaimPolicy := list "Delete" "Recycle" "Retain"
      | dict "scope" .scope "key" "reclaimPolicy" "ctx" .ctx "default" "Delete" "list"
      | include "unibox.render.enum" -}}
  {{- $_ := set $document "reclaimPolicy" $reclaimPolicy -}}

  {{- $volumeBindingMode := list "Immediate" "WaitForFirstConsumer"
      | dict "scope" .scope "key" "volumeBindingMode" "ctx" .ctx "default" "Immediate" "list"
      | include "unibox.render.enum" -}}
  {{- $_ := set $document "volumeBindingMode" $volumeBindingMode -}}

  {{- toJson $document -}}

{{- end -}}

