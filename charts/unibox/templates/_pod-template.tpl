
{{- define "unibox.podTemplate" -}}

  {{- $document := dict -}}

  {{- $spec := dict -}}

  {{- $containers := list -}}
  {{- $checksumsEnvSecret := list -}}
  {{- $checksumsEnvConfigMap := list -}}

  {{- range include "unibox.foreach" (dict
    "singleKey" "container"
    "defaultName" .component
    "callback" "unibox.container"
    "callbackArgs" (dict
      "secretInfo" (include "unibox.sealedSecret.getInfo" .ctx | fromJson)
    )
    "asArray" true
    "validateMap" "container"
    "ctx" .ctx "scope" .scope
  ) | fromJsonArray -}}
    {{- $containers = append $containers .container -}}
    {{- if .checksumEnvSecret -}}
      {{- $checksumsEnvSecret = append $checksumsEnvSecret .checksumEnvSecret -}}
    {{- end -}}
    {{- if .checksumEnvConfigMap -}}
      {{- $checksumsEnvConfigMap = append $checksumsEnvConfigMap .checksumEnvConfigMap -}}
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

  {{- $_ := dict "containers" $containers "serviceAccountName" $serviceAccountName | merge $spec -}}

  {{- $_ := set $document "spec" $spec -}}

  {{- toJson $document -}}

{{- end -}}
