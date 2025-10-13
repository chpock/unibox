
{{- define "unibox.pvc" -}}

  {{- if and (hasKey .scope "accessMode") (hasKey .scope "accessModes") -}}
    {{- list .scope "both keys .accessMode and .accessModes are specified, only one of these keys can be specified" | include "unibox.fail" -}}
  {{- else if not (hasKey .scope "storage") -}}
    {{- list .scope "there is no mandatory .storage field specified for the pvc" | include "unibox.fail" -}}
  {{- end -}}

  {{- $document := include "unibox.document" (dict
    "apiVersion" (include "unibox.capabilities.pvc.apiVersion" .ctx)
    "kind" "PersistentVolumeClaim"
  ) | fromJson -}}

  {{- $_ := include "unibox.metadata" (dict
    "name" .nameFull
    "isNamespaced" true
    "ctx" .ctx "scope" .scope
  ) | fromJson | merge $document -}}

  {{- $_ := include "unibox.pvc.spec" . | fromJson | set $document "spec" -}}

  {{- toJson $document -}}

{{- end -}}

{{- define "unibox.pvc.spec" -}}

  {{- $spec := dict -}}

  {{- $accessModesKnown := list "ReadWriteOnce" "ReadWriteMany" "ReadOnlyMany" "ReadWriteOncePod" -}}

  {{- with dict "scope" .scope "key" "accessMode" "ctx" .ctx "default" "" "list" $accessModesKnown | include "unibox.render.enum" -}}
    {{- $_ := set $spec "accessModes" (list .) -}}
  {{- else -}}
    {{- if (list .scope "accessModes" "slice" | include "unibox.validate.type") -}}

      {{- $accessModes := list -}}

      {{- $scope := .scope -}}
      {{- $ctx := .ctx -}}
      {{- range until (len .scope.accessModes) -}}
        {{- $_ := list $scope "mountOptions" . "scalar" | include "unibox.validate.type" -}}
        {{- $accessModes = dict "scope" $scope "key" "accessModes" "idx" . "ctx" $ctx "list" $accessModesKnown | include "unibox.render.enum" | append $accessModes -}}
      {{- end -}}

      {{- $_ := set $spec "accessModes" $accessModes -}}

    {{- end -}}
  {{- end -}}
  
  {{- if (list .scope "capacity" "scalar" | include "unibox.validate.type") -}}
    {{- $capacity := dict "value" .scope.capacity "ctx" .ctx "scope" .scope | include "unibox.render" -}}
    {{- $_ := dict "storage" $capacity | dict "requests" | set $spec "resources" -}}
  {{- end -}}

  {{- $storageClass := "" -}}
  {{- $storageClassDefault := false -}}

  {{- if (list .scope "storage" "!slice" | include "unibox.validate.type") -}}
    {{- if (kindIs "map" .scope.storage) -}}
      {{- template "unibox.validate.map" (list .scope "storage" "pvc.storage") -}}
      {{- $_ := list .scope "storage" | include "unibox.getPath" | set .scope.storage "__path__" -}}
      {{- $enabled := dict "scope" .scope.storage "key" "enabled" "ctx" .ctx "scopeLocal" .scope "default" true | include "unibox.render.bool" | eq "true" -}}
      {{- if $enabled -}}
        {{- if (list .scope.storage "class" "scalar" | include "unibox.validate.type") -}}
          {{- $storageClass = dict "value" .scope.storage.class "ctx" .ctx "scope" .scope | include "unibox.render" -}}
        {{- else -}}
          {{- $storageClassDefault = true -}}
        {{- end -}}
      {{- end -}}
    {{- else -}}
      {{- $storageClass = dict "value" .scope.storage "ctx" .ctx "scope" .scope | include "unibox.render" -}}
      {{- if (hasKey .storageInfo.shortcuts $storageClass) -}}
        {{- $storageClass = index .storageInfo.shortcuts $storageClass -}}
      {{- else if not (hasKey .storageInfo.entries $storageClass) -}}
        {{- printf "no storage named '%s' was found" $storageClass | list .scope "storage" | include "unibox.fail" -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- if not $storageClassDefault -}}
    {{- $_ := set $spec "storageClassName" $storageClass -}}
  {{- end -}}

  {{- if (hasKey .scope "pv") -}}
    {{- $_ := set $spec "volumeName" .nameFull -}}
  {{- end -}}

  {{- toJson $spec -}}

{{- end -}}
