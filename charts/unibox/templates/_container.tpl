
{{- define "unibox.container" -}}
  {{- quote .name | printf "name: %s" -}}
  {{- template "unibox.container.image" . -}}
  {{- template "unibox.container.command" . -}}
  {{- template "unibox.container.args" . -}}
  {{- template "unibox.container.env" . -}}
  {{- /* template "unibox.container.ports" . */ -}}
{{- end -}}

{{- define "unibox.container.image" -}}

  {{- $image := "" -}}
  {{- $registry := "" -}}
  {{- $imagePullPolicy := "" -}}

  {{- if (list .ctx.Values "imageRegistry" "scalar" | include "unibox.validate.global.type") -}}
     {{- $registry = .ctx.Values.global.imageRegistry | toString -}}
  {{- end -}}

  {{- if (list .scope "imagePullPolicy" "string" | include "unibox.validate.type") -}}
    {{- /* TODO: add validation here for imagePullPolicy, since it can only be a value from a specific value set of values */ -}}
    {{- $imagePullPolicy = include "unibox.render" (dict "value" .scope.imagePullPolicy "ctx" .ctx "scope" .scope) -}}
  {{- end -}}

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

      {{- if (list .scope.image "pullPolicy" "string" | include "unibox.validate.type") -}}
        {{- /* TODO: add validation here for imagePullPolicy, since it can only be a value from a specific value set of values */ -}}
        {{- if $imagePullPolicy -}}
          {{- list .scope.image "pullPolicy" "the image pull policy for the image in this container is already defined by the .imagePullPolicy field, only one image pull policy can be specified" | include "unibox.fail" -}}
        {{- end -}}
        {{- $imagePullPolicy = include "unibox.render" (dict "value" .scope.image.pullPolicy "ctx" .ctx "scope" .scope) -}}
      {{- end -}}

    {{- end -}}

  {{- end -}}

  {{- if ne $registry "" -}}
    {{- $image = printf "%s/%s" $registry $image -}}
  {{- end -}}

  {{- quote $image | printf "\nimage: %s" -}}
  {{- if $imagePullPolicy -}}
    {{- quote $imagePullPolicy | printf "\nimagePullPolicy: %s" -}}
  {{- end -}}

{{- end -}}

{{- define "unibox.container.command" -}}
  {{- if (list .scope "command" "!map" | include "unibox.validate.type") -}}

    {{- print "\ncommand:" -}}

    {{- if not (kindIs "slice" .scope.command) -}}
      {{- include "unibox.render" (dict "value" .scope.command "ctx" .ctx "scope" .scope) | quote | printf "\n- %s" -}}
    {{- else -}}
      {{- $scope := .scope -}}
      {{- $ctx := .ctx -}}
      {{- range until (len .scope.command) -}}
        {{- $_ := list $scope "command" . "scalar" | include "unibox.validate.type" -}}
        {{- include "unibox.render" (dict "value" (index $scope "command" .) "ctx" $ctx "scope" $scope) | quote | printf "\n- %s" -}}
      {{- end -}}
    {{- end -}}

  {{- end -}}
{{- end -}}

{{- define "unibox.container.args" -}}
  {{- if (list .scope "args" "!map" | include "unibox.validate.type") -}}

    {{- print "\nargs:" -}}

    {{- if (kindIs "slice" .scope.args) -}}
      {{- $scope := .scope -}}
      {{- $ctx := .ctx -}}
      {{- range until (len .scope.args) -}}
        {{- $_ := list $scope "args" . "scalar" | include "unibox.validate.type" -}}
        {{- include "unibox.render" (dict "value" (index $scope "args" .) "ctx" $ctx "scope" $scope) | quote | printf "\n- %s" -}}
      {{- end -}}
    {{- else -}}
      {{- include "unibox.render" (dict "value" .scope.args "ctx" .ctx "scope" .scope) | quote | printf "\n- %s" -}}
    {{- end -}}

  {{- end -}}
{{- end -}}

{{- define "unibox.container.env" -}}
  {{- if (list .scope "env" "map" | include "unibox.validate.type") -}}

    {{- print "\nenv:" -}}

    {{- include "unibox.foreach" (dict
      "singleKey" false
      "pluralKey" "env"
      "callback" "unibox.container.env.entry"
      "asArray" true
      "isEntryMap" false
      "ctx" .ctx "scope" .scope
    ) -}}

  {{- end -}}
{{- end -}}

{{- define "unibox.container.env.entry" -}}

  {{- quote .name | printf "name: %s" -}}

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

    {{- print "\nvalueFrom:" -}}

    {{- if eq $typeKey "secret" "configMap" -}}

      {{- eq $typeKey "secret" | ternary "secretKeyRef" "configMapKeyRef" | printf "%s:" | nindent 2 -}}
      {{- include "unibox.render" (dict "value" $typeValue "ctx" .ctx "scope" .scopeLocal) | quote | printf "name: %s" | nindent 4 -}}

      {{- $key := .name -}}
      {{- if (list .scope "key" "string" | include "unibox.validate.type") -}}
        {{- $key = include "unibox.render" (dict "value" .scope.key "ctx" .ctx "scope" .scopeLocal) -}}
      {{- end -}}
      {{- quote $key | printf "key: %s" | nindent 4 -}}

      {{- /*
        TODO: as for now, we allow only boolean .optional field. However, it might be templated.
        We must allow string type for this field also. But we should process template in this case
        and compare result with boolean constants 'true' and 'false'. We should give clear error
        message if we got something else. As for now, we don't have such helper function.
        We should add it in the future and allow templated .optional field
      */ -}}
      {{- if (list .scope "optional" "bool" | include "unibox.validate.type") -}}
        {{- printf "optional: %t" .scope.optional | nindent 4 -}}
      {{- end -}}

    {{- else if eq $typeKey "resourceField" -}}

      {{- printf "resourceFieldRef:" | nindent 2 -}}
      {{- include "unibox.render" (dict "value" $typeValue "ctx" .ctx "scope" .scopeLocal) | quote | printf "resource: %s" | nindent 4 -}}

      {{- if (list .scope "container" "string" | include "unibox.validate.type") -}}
        {{- /* TODO: add validation for container name. We should not allow any container name that is not defined
        in current list of containers. */ -}}
        {{- $container := include "unibox.render" (dict "value" .scope.container "ctx" .ctx "scope" .scopeLocal) -}}
        {{- quote $container | printf "containerName: %s" | nindent 4 -}}
      {{- end -}}

      {{- if (list .scope "divisor" "string" | include "unibox.validate.type") -}}
        {{- $divisor := include "unibox.render" (dict "value" .scope.divisor "ctx" .ctx "scope" .scopeLocal) -}}
        {{- quote $divisor | printf "divisor: %s" | nindent 4 -}}
      {{- end -}}

    {{- else if eq $typeKey "field" -}}
      {{- printf "fieldRef:" | nindent 2 -}}
      {{- include "unibox.render" (dict "value" $typeValue "ctx" .ctx "scope" .scopeLocal) | quote | printf "fieldPath: %s" | nindent 4 -}}
      {{- quote "v1" | printf "apiVersion: %s" | nindent 4 -}}
    {{- else -}}
      {{- printf "this will never happen, since all possible $typeKey values are covered by 'if'/'else' (typeKey: '%s')" $typeKey | fail -}}
    {{- end -}}

  {{- else -}}
    {{- include "unibox.render" (dict "value" .scope "ctx" .ctx "scope" .scopeLocal) | quote | printf "\nvalue: %s" -}}
  {{- end -}}

{{- end -}}
