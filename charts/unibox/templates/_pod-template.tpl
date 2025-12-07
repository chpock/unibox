{{- define "unibox.podTemplate" -}}

  {{- $secretInfo := include "unibox.sealedSecret.getInfo" .ctx | fromJson -}}
  {{- $ctx := .ctx -}}
  {{- $scope := .scope -}}
  {{- $component := .component -}}

  {{- $document := dict -}}

  {{- $spec := dict -}}

  {{- $volumes := list -}}
  {{- $volumeNames := list -}}
  {{- $checksumsVolSecret := list -}}
  {{- $checksumsVolConfigMap := list -}}

  {{- range include "unibox.foreach" (dict
    "singleKey" "volume"
    "defaultName" "default"
    "callback" "unibox.volume"
    "callbackArgs" (dict
      "secretInfo" $secretInfo
    )
    "asArray" true
    "isEntryMap" false
    "ctx" .ctx "scope" .scope
  ) | fromJsonArray -}}
    {{- $volumes = append $volumes .entry -}}
    {{- $volumeNames = append $volumeNames .name -}}
    {{- if .checksumSecret -}}
      {{- $checksumsVolSecret = append $checksumsVolSecret .checksumSecret -}}
    {{- end -}}
    {{- if .checksumConfigMap -}}
      {{- $checksumsVolConfigMap = append $checksumsVolConfigMap .checksumConfigMap -}}
    {{- end -}}
  {{- end -}}

  {{- if (len $volumes) -}}
    {{- $_ := set $spec "volumes" $volumes -}}
  {{- end -}}

  {{- $checksumsEnvSecret := list -}}
  {{- $checksumsEnvConfigMap := list -}}

  {{- $containers := dict "container" list "initContainer" list -}}

  {{- range list "container" "initContainer" -}}
    {{- $key := . -}}
    {{- range include "unibox.foreach" (dict
      "singleKey" $key
      "defaultName" $component
      "callback" "unibox.container"
      "callbackArgs" (dict
        "secretInfo" $secretInfo
        "volumeNames" $volumeNames
      )
      "asArray" true
      "validateMap" "container"
      "ctx" $ctx "scope" $scope
    ) | fromJsonArray -}}
      {{- $_ := append (index $containers $key) .container | set $containers $key -}}
      {{- if .checksumEnvSecret -}}
        {{- $checksumsEnvSecret = append $checksumsEnvSecret .checksumEnvSecret -}}
      {{- end -}}
      {{- if .checksumEnvConfigMap -}}
        {{- $checksumsEnvConfigMap = append $checksumsEnvConfigMap .checksumEnvConfigMap -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- $annotations := dict -}}

  {{- if $checksumsEnvSecret -}}
    {{- /*
      Here we use .nameFull as a salt to improve security. The hash should be different
      for different deployments, even if they have the same set of credentials.
    */ -}}
    {{- $checksum := sortAlpha $checksumsEnvSecret | toString | cat .nameFull | sha256sum -}}
    {{- $_ := set $annotations "unibox/checksum-env-secret" $checksum -}}
  {{- end -}}

  {{- if $checksumsEnvConfigMap -}}
    {{- /*
      Here we use .nameFull as a salt to improve security. The hash should be different
      for different deployments, even if they have the same set of credentials.
    */ -}}
    {{- $checksum := sortAlpha $checksumsEnvConfigMap | toString | cat .nameFull | sha256sum -}}
    {{- $_ := set $annotations "unibox/checksum-env-configmap" $checksum -}}
  {{- end -}}

  {{- if $checksumsVolSecret -}}
    {{- /*
      Here we use .nameFull as a salt to improve security. The hash should be different
      for different deployments, even if they have the same set of credentials.
    */ -}}
    {{- $checksum := sortAlpha $checksumsVolSecret | toString | cat .nameFull | sha256sum -}}
    {{- $_ := set $annotations "unibox/checksum-vol-secret" $checksum -}}
  {{- end -}}

  {{- if $checksumsVolConfigMap -}}
    {{- /*
      Here we use .nameFull as a salt to improve security. The hash should be different
      for different deployments, even if they have the same set of credentials.
    */ -}}
    {{- $checksum := sortAlpha $checksumsVolConfigMap | toString | cat .nameFull | sha256sum -}}
    {{- $_ := set $annotations "unibox/checksum-vol-configmap" $checksum -}}
  {{- end -}}

  {{- $_ := include "unibox.metadata" (merge (dict "annotations" $annotations) .) | fromJson | merge $document -}}

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

  {{- $_ := dict "containers" $containers.container "serviceAccountName" $serviceAccountName | merge $spec -}}

  {{- if (len $containers.initContainer) -}}
    {{- $_ := set $spec "initContainers" $containers.initContainer -}}
  {{- end -}}

  {{- $_ := set $document "spec" $spec -}}

  {{- toJson $document -}}

{{- end -}}
