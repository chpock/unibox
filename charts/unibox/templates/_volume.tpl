{{- define "unibox.volume" -}}

  {{- $document := dict "name" .name -}}
  {{- $checksumSecret := "" -}}
  {{- $checksumConfigMap := "" -}}

  {{- if (kindIs "map" .scope) -}}

    {{- $type := pick .scope "secret" "configMap" "hostPath" "pvc" "emptyDir" | keys -}}

    {{- if not (len $type) -}}
      {{- list .scopeParent .name "could not detect volume type, it must be a map and contain one of the following keys: 'secret', 'configMap', 'hostPath', 'pvc' or 'emptyDir'" | include "unibox.fail" -}}
    {{- else if gt (len $type) 1 -}}
      {{- /* use sortAlpha on $type array to make error message predictable */ -}}
      {{- sortAlpha $type | join "', '" | printf "volume entry has a ambiguous type as it contains the following fields: '%s', it must contain only one of the following keys: 'secret', 'configMap', 'hostPath', 'pvc' or 'emptyDir'" | list .scopeParent .name | include "unibox.fail" -}}
    {{- end -}}

    {{- $typeKey := first $type -}}

    {{- template "unibox.validate.map" (list .scope (printf "volume.%s" $typeKey)) -}}

    {{- $_ := list .scope $typeKey "string" | include "unibox.validate.type" -}}
    {{- $typeValue := include "unibox.render" (dict "value" (index .scope $typeKey) "ctx" .ctx "scope" .scopeLocal) -}}

    {{- if eq $typeKey "secret" "configMap" -}}

      {{- $optional := dict "scope" .scope "key" "optional" "ctx" .ctx "scopeLocal" .scopeLocal "default" false | include "unibox.render.bool" | eq "true" -}}

      {{- $entry := dict "optional" $optional -}}

      {{- $items := include "unibox.foreach" (dict
        "singleKey" false
        "pluralKey" "items"
        "callback" "unibox.volume.secretOrConfigMap.item"
        "asArray" true
        "isEntryMap" false
        "ctx" .ctx "scope" .scope "scopeLocal" .scopeLocal
      ) | fromJsonArray -}}

      {{- if (len $items) -}}
        {{- $_ := set $entry "items" $items -}}
      {{- end -}}

      {{- if (hasKey .scope "defaultMode") -}}
        {{- $defaultMode := dict "scope" .scope "key" "defaultMode" "ctx" .ctx | include "unibox.render.integer" | atoi -}}
        {{- $_ := set $entry "defaultMode" $defaultMode -}}
      {{- end -}}

      {{- $keyRefName := $typeValue -}}

      {{- if eq $typeKey "secret" -}}

        {{- $keyRefNameOriginal := $keyRefName -}}

        {{- if (hasKey .secretInfo.shortcuts $keyRefName) -}}
          {{- $keyRefName = index .secretInfo.shortcuts $keyRefName -}}
        {{- end -}}

        {{- if (hasKey .secretInfo.entries $keyRefName) -}}

          {{- $secretInfoEntry := index .secretInfo.entries $keyRefName -}}

          {{- if (len $items) -}}

            {{- $checksumSecretList := list -}}
            {{- $scope := .scope -}}

            {{- range $items -}}
              {{- if (hasKey $secretInfoEntry.data .key) -}}
                {{- $checksumSecretList = index $secretInfoEntry.data .key | append $checksumSecretList -}}
              {{- else if not $optional -}}
                {{- printf "no entry '%s' in the %s '%s' is found. If this is expected and the secret may be missing, please set .optional flag to this environment variable entry" .key $secretInfoEntry.type $keyRefNameOriginal | list $scope.items .key | include "unibox.fail" -}}
              {{- end -}}
            {{- end -}}

            {{- if (len $checksumSecretList) -}}
              {{- $checksumSecret = sortAlpha $checksumSecretList | toString | sha256sum -}}
            {{- end -}}

          {{- else -}}
            {{- $checksumSecret = $secretInfoEntry.data | toString | sha256sum -}}
          {{- end -}}

          {{- if $checksumSecret -}}
            {{- $checksumSecret = cat .name $checksumSecret | sha256sum -}}
          {{- end -}}

        {{- else if not $optional -}}
          {{- printf "no secrets or sealedsecrets named '%s' were found. If this is expected and the secret may be missing, please set .optional flag to this environment variable entry" $keyRefNameOriginal | list .scope $typeKey | include "unibox.fail" -}}
        {{- end -}}

        {{- $_ := set $entry "secretName" $keyRefName -}}

      {{- else -}}

        {{- $_ := set $entry "name" $keyRefName -}}

      {{- end -}}

      {{- $_ := set $document $typeKey $entry -}}

    {{- else if eq $typeKey "hostPath" -}}

      {{- $hostPath := dict "path" $typeValue -}}

      {{- if (hasKey .scope "type") -}}
        {{- $pathType := list "" "BlockDevice" "CharDevice" "Directory" "DirectoryOrCreate" "File" "FileOrCreate" "Socket"
            | dict "scope" .scope "key" "type" "ctx" .ctx "scopeLocal" .scopeLocal "list"
            | include "unibox.render.enum" -}}
        {{- $_ := set $hostPath "type" $pathType -}}
      {{- end -}}

      {{- $_ := set $document "hostPath" $hostPath -}}

    {{- else if eq $typeKey "pvc" -}}

      {{- $readOnly := dict "scope" .scope "key" "readOnly" "ctx" .ctx "scopeLocal" .scopeLocal "default" false | include "unibox.render.bool" | eq "true" -}}
      {{- $_ := dict "claimName" $typeValue "readOnly" $readOnly | set $document "persistentVolumeClaim" -}}

    {{- else if eq $typeKey "emptyDir" -}}

      {{- $medium := list "" "Memory"
          | dict "scope" .scope "key" $typeKey "ctx" .ctx "scopeLocal" .scopeLocal "list"
          | include "unibox.render.enum" -}}

      {{- $emptyDir := dict "medium" $medium -}}

      {{- if (list .scope "sizeLimit" "scalar" | include "unibox.validate.type") -}}
        {{- $sizeLimit := dict "value" .scope.sizeLimit "ctx" .ctx "scope" .scopeLocal | include "unibox.render" -}}
        {{- $_ := set $emptyDir "sizeLimit" $sizeLimit -}}
      {{- end -}}

      {{- $_ := set $document "emptyDir" $emptyDir -}}

    {{- else -}}
      {{- printf "this will never happen, since all possible $typeKey values are covered by 'if'/'else' (typeKey: '%s')" $typeKey | fail -}}
    {{- end -}}

  {{- else -}}

    {{- $_ := list .scopeParent .name "scalar" | include "unibox.validate.type" -}}
    {{- $value := include "unibox.render" (dict "value" .scope "ctx" .ctx "scope" .scopeLocal) -}}

    {{- if ne $value "emptyDir" -}}
      {{- printf "volume value can be 'emptyDir' string or have map type, but got value: '%s'" $value | list .scopeParent .name | include "unibox.fail" -}}
    {{- end -}}

    {{- $_ := dict | set $document "emptyDir" -}}

  {{- end -}}

  {{- dict "entry" $document "name" .name "checksumSecret" $checksumSecret "checksumConfigMap" $checksumConfigMap | toJson -}}

{{- end -}}

{{- define "unibox.volume.secretOrConfigMap.item" -}}

  {{- $item := dict "key" .name -}}

  {{- if (kindIs "map" .scope) -}}

    {{- template "unibox.validate.map" (list .scope "volume.secretOrConfigMap.item") -}}

    {{- if (list .scope "path" "scalar" | include "unibox.validate.type") -}}
      {{- $path := dict "value" .scope.path "ctx" .ctx "scope" .scopeLocal | include "unibox.render" -}}
      {{- $_ := set $item "path" $path -}}
    {{- else -}}
      {{- list .scope "there is no mandatory .path field specified for the item" | include "unibox.fail" -}}
    {{- end -}}

    {{- if (list .scope "mode" "scalar" | include "unibox.validate.type") -}}
      {{- $mode := dict "scope" .scope "key" "mode" "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi -}}
      {{- $_ := set $item "mode" $mode -}}
    {{- end -}}

  {{- else -}}

    {{- $_ := list .scopeParent .name "scalar" | include "unibox.validate.type" -}}
    {{- $path := include "unibox.render" (dict "value" .scope "ctx" .ctx "scope" .scopeLocal) -}}

    {{- $_ := set $item "path" $path -}}

  {{- end -}}

  {{- toJson $item -}}

{{- end -}}
