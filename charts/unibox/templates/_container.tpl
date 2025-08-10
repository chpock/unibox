
{{- define "unibox.container" -}}

  {{- $document := dict "name" .name -}}

  {{- $_ := include "unibox.container.image" . | fromJson | merge $document -}}
  {{- $_ := include "unibox.container.command" . | fromJson | merge $document -}}
  {{- $_ := include "unibox.container.args" . | fromJson | merge $document -}}
  {{- $_ := include "unibox.container.env" . | fromJson | merge $document -}}
  {{- $_ := include "unibox.container.ports" . | fromJson | merge $document -}}

  {{- if (list .scope "probes" "map" | include "unibox.validate.type") -}}
    {{- template "unibox.validate.map" (list .scope "probes" "container.probes") -}}
    {{- $_ := list .scope "probes" | include "unibox.getPath" | set .scope.probes "__path__" -}}
    {{- $ctx := .ctx -}}
    {{- $scope := .scope -}}
    {{- range $key, $scopeProbe := omit .scope.probes "__path__" -}}
      {{- $_ := list $scope.probes $key "map" | include "unibox.validate.type" -}}
      {{- $_ := dict "ctx" $ctx "scope" $scopeProbe "key" $key "scopeLocal" $scope "scopeParent" $scope.probes | include "unibox.container.probe" | fromJson | merge $document -}}
    {{- end -}}
  {{- end -}}

  {{- toJson $document -}}
{{- end -}}

{{- define "unibox.container.image" -}}

  {{- $image := "" -}}
  {{- $registry := "" -}}

  {{- if (list .ctx.Values "imageRegistry" "scalar" | include "unibox.validate.global.type") -}}
     {{- $registry = .ctx.Values.global.imageRegistry | toString -}}
  {{- end -}}

  {{- $imagePullPolicy := list "IfNotPresent" "Always" "Never"
      | dict "scope" .scope "key" "imagePullPolicy" "ctx" .ctx "default" "IfNotPresent" "list"
      | include "unibox.render.enum" -}}

  {{- if not (list .scope "image" "!slice" | include "unibox.validate.type") -}}
    {{- list .scope "there is no image defined in the container, please define the image in this container using the .image field" | include "unibox.fail" -}}
  {{- else -}}

    {{- if (kindIs "string" .scope.image) -}}
      {{- $image = include "unibox.render" (dict "value" .scope.image "ctx" .ctx "scope" .scope) -}}
    {{- else -}}

      {{- $_ := list .scope "image" | include "unibox.getPath" | set .scope.image "__path__" -}}
      {{- template "unibox.validate.map" (list .scope "image" "container.image") -}}

      {{- if not (list .scope.image "repository" "scalar" | include "unibox.validate.type") -}}
        {{- list .scope "image" "the image block for the container doesn't contain the mandatory .repository field" | include "unibox.fail" -}}
      {{- end -}}

      {{- $repository := include "unibox.render" (dict "value" .scope.image.repository "ctx" .ctx "scope" .scope) -}}
      {{- $tag := "" -}}
      {{- $tagSeparator := ":" -}}

      {{- if (list .scope.image "digest" "string" | include "unibox.validate.type") -}}
        {{- $tag = include "unibox.render" (dict "value" .scope.image.digest "ctx" .ctx "scope" .scope) -}}
        {{- $tagSeparator = "@" -}}
      {{- else if (list .scope.image "tag" "scalar" | include "unibox.validate.type") -}}
        {{- $tag = include "unibox.render" (dict "value" .scope.image.tag "ctx" .ctx "scope" .scope) -}}
      {{- else -}}
        {{- $tag = include "unibox.appVersion" .ctx -}}
        {{- if not $tag -}}
          {{- list .scope "image" "could not discover the image tag for the container as the image block doesn't contain .digest or .tag field, and .app.version field is not defined" | include "unibox.fail" -}}
        {{- end -}}
      {{- end -}}

      {{- $image = printf "%s%s%s" $repository $tagSeparator $tag -}}

      {{- if (list .scope.image "registry" "scalar" | include "unibox.validate.type") -}}
        {{- $registry = include "unibox.render" (dict "value" .scope.image.registry "ctx" .ctx "scope" .scope) -}}
      {{- end -}}

      {{- if (hasKey .scope.image "pullPolicy") -}}
        {{- if (hasKey .scope "imagePullPolicy") -}}
          {{- list .scope.image "pullPolicy" "the image pull policy for the image in this container is already defined by the .imagePullPolicy field, only one image pull policy can be specified" | include "unibox.fail" -}}
        {{- end -}}
        {{- $imagePullPolicy = list "IfNotPresent" "Always" "Never"
            | dict "scope" .scope.image "key" "pullPolicy" "ctx" .ctx "scopeLocal" .scope "default" "IfNotPresent" "list"
            | include "unibox.render.enum" -}}
      {{- end -}}

    {{- end -}}

  {{- end -}}

  {{- if ne $registry "" -}}
    {{- $image = printf "%s/%s" $registry $image -}}
  {{- end -}}

  {{- dict "image" $image "imagePullPolicy" $imagePullPolicy | toJson -}}

{{- end -}}

{{- define "unibox.container.command" -}}
  {{- if (list .scope "command" "!map" | include "unibox.validate.type") -}}

    {{- $command := list -}}

    {{- if not (kindIs "slice" .scope.command) -}}
      {{- $command = include "unibox.render" (dict "value" .scope.command "ctx" .ctx "scope" .scope) | append $command -}}
    {{- else -}}
      {{- $scope := .scope -}}
      {{- $ctx := .ctx -}}
      {{- range until (len .scope.command) -}}
        {{- $_ := list $scope "command" . "scalar" | include "unibox.validate.type" -}}
        {{- $command = include "unibox.render" (dict "value" (index $scope "command" .) "ctx" $ctx "scope" $scope) | append $command -}}
      {{- end -}}
    {{- end -}}

    {{- dict "command" $command | toJson -}}

  {{- else -}}
    {{- dict | toJson -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.container.args" -}}
  {{- if (list .scope "args" "!map" | include "unibox.validate.type") -}}

    {{- $args := list -}}

    {{- if (kindIs "slice" .scope.args) -}}
      {{- $scope := .scope -}}
      {{- $ctx := .ctx -}}
      {{- range until (len .scope.args) -}}
        {{- $_ := list $scope "args" . "scalar" | include "unibox.validate.type" -}}
        {{- $args = include "unibox.render" (dict "value" (index $scope "args" .) "ctx" $ctx "scope" $scope) | append $args -}}
      {{- end -}}
    {{- else -}}
      {{- $args = include "unibox.render" (dict "value" .scope.args "ctx" .ctx "scope" .scope) | append $args -}}
    {{- end -}}

    {{- dict "args" $args | toJson -}}

  {{- else -}}
    {{- dict | toJson -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.container.env" -}}
  {{- if (list .scope "env" "map" | include "unibox.validate.type") -}}

    {{- $env := include "unibox.foreach" (dict
      "singleKey" false
      "pluralKey" "env"
      "callback" "unibox.container.env.entry"
      "asArray" true
      "isEntryMap" false
      "ctx" .ctx "scope" .scope
    ) | fromJsonArray -}}

    {{- dict "env" $env | toJson -}}

  {{- else -}}
    {{- dict | toJson -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.container.env.entry" -}}

  {{- $entry := dict "name" .name -}}

  {{- $_ := list .scopeParent .name "!slice" | include "unibox.validate.type" -}}

  {{- if (kindIs "map" .scope) -}}

    {{- $type := pick .scope "secret" "configMap" "field" "resourceField" | keys -}}

    {{- if not (len $type) -}}
      {{- list .scopeParent .name "could not detect container environment entry type, it must be a map and contain one of the following keys: 'secret', 'configMap', 'field' or 'resourceField'" | include "unibox.fail" -}}
    {{- else if gt (len $type) 1 -}}
      {{- /* use sortAlpha on $type array to make error message predictable */ -}}
      {{- sortAlpha $type | join "', '" | printf "container environment entry has a ambiguous type as it contains the following fields: '%s', it must contain only one of the following keys: 'secret', 'configMap', 'field' or 'resourceField'" | list .scopeParent .name | include "unibox.fail" -}}
    {{- end -}}

    {{- $typeKey := first $type -}}

    {{- $_ := list .scopeParent .name | include "unibox.getPath" | set .scope "__path__" -}}
    {{- $_ := list .scope $typeKey "string" | include "unibox.validate.type" -}}

    {{- template "unibox.validate.map" (list .scope (printf "container.env.%s" $typeKey)) -}}

    {{- $typeValue := index .scope $typeKey -}}

    {{- $valueFrom := dict -}}

    {{- if eq $typeKey "secret" "configMap" -}}

      {{- $keyRef := dict "name" (include "unibox.render" (dict "value" $typeValue "ctx" .ctx "scope" .scopeLocal)) -}}

      {{- $key := .name -}}
      {{- if (list .scope "key" "string" | include "unibox.validate.type") -}}
        {{- $key = include "unibox.render" (dict "value" .scope.key "ctx" .ctx "scope" .scopeLocal) -}}
      {{- end -}}
      {{- $_ := set $keyRef "key" $key -}}

      {{- /*
        TODO: as for now, we allow only boolean .optional field. However, it might be templated.
        We must allow string type for this field also. But we should process template in this case
        and compare result with boolean constants 'true' and 'false'. We should give clear error
        message if we got something else. As for now, we don't have such helper function.
        We should add it in the future and allow templated .optional field
      */ -}}
      {{- if (list .scope "optional" "bool" | include "unibox.validate.type") -}}
        {{- $_ := set $keyRef "optional" .scope.optional -}}
      {{- end -}}

      {{- $_ := set $valueFrom (eq $typeKey "secret" | ternary "secretKeyRef" "configMapKeyRef") $keyRef -}}

    {{- else if eq $typeKey "resourceField" -}}

      {{- $resourceFieldRef := dict "resource" (include "unibox.render" (dict "value" $typeValue "ctx" .ctx "scope" .scopeLocal)) -}}

      {{- if (list .scope "container" "string" | include "unibox.validate.type") -}}
        {{- /* TODO: add validation for container name. We should not allow any container name that is not defined
        in current list of containers. */ -}}
        {{- $container := include "unibox.render" (dict "value" .scope.container "ctx" .ctx "scope" .scopeLocal) -}}
        {{- $_ := set $resourceFieldRef "containerName" $container -}}
      {{- end -}}

      {{- if (list .scope "divisor" "string" | include "unibox.validate.type") -}}
        {{- $divisor := include "unibox.render" (dict "value" .scope.divisor "ctx" .ctx "scope" .scopeLocal) -}}
        {{- $_ := set $resourceFieldRef "divisor" $divisor -}}
      {{- end -}}

      {{- $_ := set $valueFrom "resourceFieldRef" $resourceFieldRef -}}

    {{- else if eq $typeKey "field" -}}
      {{- $fieldRef := dict "apiVersion" "v1" "fieldPath" (include "unibox.render" (dict "value" $typeValue "ctx" .ctx "scope" .scopeLocal)) -}}
      {{- $_ := set $valueFrom "fieldRef" $fieldRef -}}
    {{- else -}}
      {{- printf "this will never happen, since all possible $typeKey values are covered by 'if'/'else' (typeKey: '%s')" $typeKey | fail -}}
    {{- end -}}

    {{- $_ := set $entry "valueFrom" $valueFrom -}}

  {{- else -}}
    {{- $_ := set $entry "value" (include "unibox.render" (dict "value" .scope "ctx" .ctx "scope" .scopeLocal)) -}}
  {{- end -}}

  {{- toJson $entry -}}

{{- end -}}

{{- define "unibox.container.ports" -}}
  {{- if (list .scope "ports" "map" | include "unibox.validate.type") -}}

    {{- $ports := include "unibox.foreach" (dict
      "singleKey" false
      "pluralKey" "ports"
      "callback" "unibox.container.ports.entry"
      "asArray" true
      "isEntryMap" false
      "ctx" .ctx "scope" .scope
    ) | fromJsonArray -}}

    {{- dict "ports" $ports | toJson -}}

  {{- else -}}
    {{- dict | toJson -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.container.ports.entry" -}}
  {{- dict
    "name" .name
    "protocol" "TCP"
    "containerPort" (dict "scope" .scopeParent "key" .name "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi)
  | toJson -}}
{{- end -}}

{{- define "unibox.container.probe" -}}

  {{- $probe := dict -}}

  {{- $type := list "http" "grpc" "exec" "tcp"
      | dict "scope" .scope "key" "type" "ctx" .ctx "default" "http" "list"
      | include "unibox.render.enum" -}}

  {{- template "unibox.validate.map" (printf "container.probe.%s.%s" .key $type | list .scopeParent .key) -}}

  {{- dict (printf "%sProbe" .key) $probe | toJson -}}

{{- end -}}
