
{{- define "unibox.container" -}}

  {{- $document := dict "name" .name -}}

  {{- $_ := include "unibox.container.image" . | fromJson | merge $document -}}
  {{- $_ := include "unibox.container.command" . | fromJson | merge $document -}}
  {{- $_ := include "unibox.container.args" . | fromJson | merge $document -}}
  {{- $_ := include "unibox.container.ports" . | fromJson | merge $document -}}
  {{- $_ := include "unibox.container.resources" . | fromJson | merge $document -}}

  {{- $volumeMounts := include "unibox.foreach" (dict
    "singleKey" "mount"
    "defaultName" "default"
    "callback" "unibox.container.mount.entry"
    "callbackArgs" (dict
      "volumeNames" .volumeNames
    )
    "asArray" true
    "isEntryMap" false
    "ctx" .ctx "scope" .scope
  ) | fromJsonArray -}}

  {{- if (len $volumeMounts) -}}
    {{- $_ := set $document "volumeMounts" $volumeMounts -}}
  {{- end -}}

  {{- $checksumEnvSecret := "" -}}
  {{- $checksumEnvConfigMap := "" -}}

  {{- with include "unibox.container.env" . | fromJson -}}
    {{- $_ := dict "env" .env | merge $document -}}
    {{- $checksumEnvSecret = .checksumsSecret -}}
    {{- $checksumEnvConfigMap = .checksumsConfigMap -}}
  {{- end -}}

  {{- if (list .scope "probes" "map" | include "unibox.validate.type") -}}
    {{- template "unibox.validate.map" (list .scope "probes" "container.probes") -}}
    {{- $_ := list .scope "probes" | include "unibox.getPath" | set .scope.probes "__path__" -}}
    {{- $ctx := .ctx -}}
    {{- $scope := .scope -}}
    {{- range $key, $scopeProbe := omit .scope.probes "__path__" -}}
      {{- $_ := list $scope.probes $key "map" | include "unibox.validate.type" -}}
      {{- $_ := list $scope.probes $key | include "unibox.getPath" | set $scopeProbe "__path__" -}}
      {{- $_ := dict "ctx" $ctx "scope" $scopeProbe "key" $key "scopeLocal" $scope "scopeParent" $scope.probes | include "unibox.container.probe" | fromJson | merge $document -}}
    {{- end -}}
  {{- end -}}

  {{- dict "container" $document "checksumEnvSecret" $checksumEnvSecret "checksumEnvConfigMap" $checksumEnvConfigMap | toJson -}}

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

    {{- $env := list -}}
    {{- $checksumsSecret := list -}}
    {{- $checksumsConfigMap := list -}}

    {{- range include "unibox.foreach" (dict
      "singleKey" false
      "pluralKey" "env"
      "callback" "unibox.container.env.entry"
      "callbackArgs" (dict "secretInfo" .secretInfo)
      "asArray" true
      "isEntryMap" false
      "ctx" .ctx "scope" .scope
    ) | fromJsonArray -}}
      {{- $env = append $env .entry -}}
      {{- if .checksumSecret -}}
        {{- $checksumsSecret = append $checksumsSecret .checksumSecret -}}
      {{- end -}}
      {{- if .checksumConfigMap -}}
        {{- $checksumsConfigMap = append $checksumsConfigMap .checksumConfigMap -}}
      {{- end -}}
    {{- end -}}

    {{- if $checksumsSecret -}}
      {{- $checksumsSecret = sortAlpha $checksumsSecret | toString | sha256sum -}}
    {{- end -}}
    {{- if $checksumsConfigMap -}}
      {{- $checksumsConfigMap = sortAlpha $checksumsConfigMap | toString | sha256sum -}}
    {{- end -}}

    {{- dict "env" $env "checksumsSecret" $checksumsSecret "checksumsConfigMap" $checksumsConfigMap | toJson -}}

  {{- else -}}
    {{- dict | toJson -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.container.env.entry" -}}

  {{- $entry := dict "name" .name -}}
  {{- $checksumSecret := "" -}}
  {{- $checksumConfigMap := "" -}}

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

    {{- $typeValue := include "unibox.render" (dict "value" (index .scope $typeKey) "ctx" .ctx "scope" .scopeLocal) -}}

    {{- $valueFrom := dict -}}

    {{- if eq $typeKey "secret" "configMap" -}}

      {{- $keyRefKey := .name -}}
      {{- if (list .scope "key" "string" | include "unibox.validate.type") -}}
        {{- $keyRefKey = include "unibox.render" (dict "value" .scope.key "ctx" .ctx "scope" .scopeLocal) -}}
      {{- end -}}

      {{- $optional := dict "scope" .scope "key" "optional" "ctx" .ctx "scopeLocal" .scopeLocal "default" false | include "unibox.render.bool" | eq "true" -}}

      {{- $keyRefName := $typeValue -}}

      {{- if eq $typeKey "secret" -}}

        {{- $keyRefNameOriginal := $keyRefName -}}

        {{- if (hasKey .secretInfo.shortcuts $keyRefName) -}}
          {{- $keyRefName = index .secretInfo.shortcuts $keyRefName -}}
        {{- end -}}

        {{- if (hasKey .secretInfo.entries $keyRefName) -}}
          {{- $secretInfoEntry := index .secretInfo.entries $keyRefName -}}
          {{- if (hasKey $secretInfoEntry.data $keyRefKey) -}}
            {{- $checksumSecret = index $secretInfoEntry.data $keyRefKey | cat .name | sha256sum -}}
          {{- else if not $optional -}}
            {{- printf "no entry '%s' in the %s '%s' is found. If this is expected and the secret may be missing, please set .optional flag to this environment variable entry" $keyRefKey $secretInfoEntry.type $keyRefNameOriginal | list .scope $typeKey | include "unibox.fail" -}}
          {{- end -}}
        {{- else if not $optional -}}
          {{- printf "no secrets or sealedsecrets named '%s' were found. If this is expected and the secret may be missing, please set .optional flag to this environment variable entry" $keyRefNameOriginal | list .scope $typeKey | include "unibox.fail" -}}
        {{- end -}}

      {{- end -}}

      {{- $_ := dict "name" $keyRefName "key" $keyRefKey "optional" $optional | set $valueFrom (eq $typeKey "secret" | ternary "secretKeyRef" "configMapKeyRef") -}}

    {{- else if eq $typeKey "resourceField" -}}

      {{- $resourceFieldRef := dict "resource" $typeValue -}}

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
      {{- $fieldRef := dict "apiVersion" "v1" "fieldPath" $typeValue -}}
      {{- $_ := set $valueFrom "fieldRef" $fieldRef -}}
    {{- else -}}
      {{- printf "this will never happen, since all possible $typeKey values are covered by 'if'/'else' (typeKey: '%s')" $typeKey | fail -}}
    {{- end -}}

    {{- $_ := set $entry "valueFrom" $valueFrom -}}

  {{- else -}}
    {{- $_ := set $entry "value" (include "unibox.render" (dict "value" .scope "ctx" .ctx "scope" .scopeLocal)) -}}
  {{- end -}}

  {{- dict "entry" $entry "checksumSecret" $checksumSecret "checksumConfigMap" $checksumConfigMap | toJson -}}

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

{{- define "unibox.container.getPorts" -}}

  {{- $result := dict -}}

  {{- $ports := include "unibox.foreach" (dict
    "singleKey" false
    "pluralKey" "ports"
    "callback" "unibox.container.getPorts.callback"
    "asArray" true
    "isEntryMap" false
    "ctx" .ctx "scope" .scope
  ) | fromJsonArray -}}

  {{- range $ports -}}
    {{- $_ := merge $result . -}}
  {{- end -}}

  {{- $result | toJson -}}

{{- end -}}

{{- define "unibox.container.ports.entry" -}}
  {{- dict
    "name" .name
    "protocol" "TCP"
    "containerPort" (dict "scope" .scopeParent "key" .name "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi)
  | toJson -}}
{{- end -}}

{{- define "unibox.container.getPorts.callback" -}}
  {{- $number := dict "scope" .scopeParent "key" .name "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi -}}
  {{- dict .name $number | toJson -}}
{{- end -}}

{{- define "unibox.container.probe" -}}

  {{- $probe := dict -}}

  {{- $type := list "http" "grpc" "exec" "tcp"
      | dict "scope" .scope "key" "type" "ctx" .ctx "scopeLocal" .scopeLocal "default" "http" "list"
      | include "unibox.render.enum" -}}

  {{- template "unibox.validate.map" (printf "container.probe.%s.%s" .key $type | list .scopeParent .key) -}}

  {{- /* type-specific parameters */ -}}

  {{- /* port is mandatory parameter for http/grpc/tcp probe types */ -}}
  {{- $port := "" -}}
  {{- if (list "http" "grpc" "tcp" | has $type) -}}

    {{- /* by default, port name for http/tcp probes is "http", and port name for grpc probe is "grpc" */ -}}
    {{- $port = eq $type "grpc" | ternary "grpc" "http" -}}

    {{- if (list .scope "port" "scalar" | include "unibox.validate.type") -}}
      {{- $port = dict "value" .scope.port "ctx" .ctx "scope" .scopeLocal | include "unibox.render" -}}
    {{- end -}}

    {{- /* allow to define port as an integer number */ -}}
    {{- if (regexMatch "^\\d+$" $port) -}}
      {{- $port = atoi $port -}}
    {{- else -}}

      {{- $containerPorts := dict "ctx" .ctx "scope" .scopeLocal | include "unibox.container.getPorts" | fromJson -}}

      {{- if not (hasKey $containerPorts $port) -}}
        {{- $msg := "" -}}
        {{- if (len $containerPorts) -}}
          {{- $msg = keys $containerPorts | sortAlpha | join "', '" | printf "but the parent container has only the following %s: '%s'" (len $containerPorts | plural "port" "ports") -}}
        {{- else -}}
          {{- $msg = "but the parent container has no ports defined" -}}
        {{- end -}}
        {{- if (hasKey .scope "port") -}}
          {{- printf "port '%s' is specified, %s" $port $msg | list .scope "port" | include "unibox.fail" -}}
        {{- else -}}
          {{- printf "port is not defined and the '%s' port name should be used by default, %s" $port $msg | list .scopeParent .key | include "unibox.fail" -}}
        {{- end }}
      {{- end -}}

      {{- /* according to specs, port for grpc probe must be an integer number */ -}}
      {{- if eq $type "grpc" -}}
        {{- $port = index $containerPorts $port -}}
      {{- end -}}

    {{- end -}}

  {{- end -}}

  {{- if eq $type "http" -}}

    {{- $scheme := list "http" "https" "HTTP" "HTTPS"
        | dict "scope" .scope "key" "scheme" "ctx" .ctx "scopeLocal" .scopeLocal "default" "http" "list"
        | include "unibox.render.enum"
        | upper -}}

    {{- $path := "/" -}}
    {{- if (list .scope "path" "scalar" | include "unibox.validate.type") -}}
      {{- $path = include "unibox.render" (dict "value" .scope.path "ctx" .ctx "scope" .scopeLocal) -}}
    {{- end -}}

    {{- $_ := set $probe "httpGet" (dict "port" $port "scheme" $scheme "path" $path) -}}

    {{- if (list .scope "host" "scalar" | include "unibox.validate.type") -}}
      {{- $host := include "unibox.render" (dict "value" .scope.host "ctx" .ctx "scope" .scopeLocal) -}}
      {{- $_ := set $probe.httpGet "host" $host -}}
    {{- end -}}

    {{- if (list .scope "headers" "map" | include "unibox.validate.type") -}}

      {{- $_ := list .scopeParent .key | include "unibox.getPath" | set .scope "__path__" -}}

      {{- $httpHeaders := include "unibox.foreach" (dict
        "singleKey" false
        "pluralKey" "headers"
        "callback" "unibox.container.probe.http.headers"
        "callbackArgs" (deepCopy .scopeLocal | dict "scopeLocal")
        "asArray" true
        "isEntryMap" false
        "ctx" .ctx "scope" .scope
      ) | fromJsonArray -}}

      {{- $_ := set $probe.httpGet "httpHeaders" $httpHeaders -}}

    {{- end -}}

  {{- else if eq $type "grpc" -}}

    {{- $_ := set $probe "grpc" (dict "port" $port) -}}

    {{- if (list .scope "service" "scalar" | include "unibox.validate.type") -}}
      {{- $service := include "unibox.render" (dict "value" .scope.service "ctx" .ctx "scope" .scopeLocal) -}}
      {{- $_ := set $probe.grpc "service" $service -}}
    {{- end -}}

  {{- else if eq $type "tcp" -}}

    {{- $_ := set $probe "tcpSocket" (dict "port" $port) -}}

    {{- if (list .scope "host" "scalar" | include "unibox.validate.type") -}}
      {{- $host := include "unibox.render" (dict "value" .scope.host "ctx" .ctx "scope" .scopeLocal) -}}
      {{- $_ := set $probe.tcpSocket "host" $host -}}
    {{- end -}}

  {{- else if eq $type "exec" -}}

    {{- if (list .scope "command" "!map" | include "unibox.validate.type") -}}

      {{- $command := list -}}

      {{- if not (kindIs "slice" .scope.command) -}}
        {{- $command = include "unibox.render" (dict "value" .scope.command "ctx" .ctx "scope" .scopeLocal) | append $command -}}
      {{- else if not (len .scope.command) -}}
        {{- list .scope "command" "the field must not be an empty array" | include "unibox.fail" -}}
      {{- else -}}
        {{- $scope := .scope -}}
        {{- $ctx := .ctx -}}
        {{- $scopeLocal := .scopeLocal -}}
        {{- range until (len .scope.command) -}}
          {{- $_ := list $scope "command" . "scalar" | include "unibox.validate.type" -}}
          {{- $command = include "unibox.render" (dict "value" (index $scope "command" .) "ctx" $ctx "scope" $scopeLocal) | append $command -}}
        {{- end -}}
      {{- end -}}

      {{- $_ := set $probe "exec" (dict "command" $command) -}}

    {{- else -}}
      {{- list .scopeParent .key "exec probe requires mandatory .command field" | include "unibox.fail" -}}
    {{- end -}}

  {{- else -}}
    {{- printf "unibox.container.probe: unknown type '%s' (this should never happen)" $type | fail -}}
  {{- end -}}

  {{- /* common parameters */ -}}

  {{- $failureThreshold := 3 -}}
  {{- if (list .scope "failureThreshold" "scalar" | include "unibox.validate.type") -}}
    {{- $failureThreshold = dict "scope" .scope "key" "failureThreshold" "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi -}}
  {{- end -}}
  {{- $_ := set $probe "failureThreshold" $failureThreshold -}}

  {{- $periodSeconds := 10 -}}
  {{- if (list .scope "periodSeconds" "scalar" | include "unibox.validate.type") -}}
    {{- $periodSeconds = dict "scope" .scope "key" "periodSeconds" "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi -}}
  {{- end -}}
  {{- $_ := set $probe "periodSeconds" $periodSeconds -}}

  {{- $timeoutSeconds := 10 -}}
  {{- if (list .scope "timeoutSeconds" "scalar" | include "unibox.validate.type") -}}
    {{- $timeoutSeconds = dict "scope" .scope "key" "timeoutSeconds" "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi -}}
  {{- end -}}
  {{- $_ := set $probe "timeoutSeconds" $timeoutSeconds -}}

  {{- $initialDelaySeconds := 0 -}}
  {{- if (list .scope "initialDelaySeconds" "scalar" | include "unibox.validate.type") -}}
    {{- $initialDelaySeconds = dict "scope" .scope "key" "initialDelaySeconds" "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi -}}
  {{- end -}}
  {{- $_ := set $probe "initialDelaySeconds" $initialDelaySeconds -}}

  {{- $successThreshold := 1 -}}
  {{- /* successThreshold can be changed only for readinessProbe. For all other probes it must be 1 according to specs. */ -}}
  {{- if eq .key "readiness" -}}
    {{- if (list .scope "successThreshold" "scalar" | include "unibox.validate.type") -}}
      {{- $successThreshold = dict "scope" .scope "key" "successThreshold" "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set $probe "successThreshold" $successThreshold -}}

  {{- if (list .scope "terminationGracePeriodSeconds" "scalar" | include "unibox.validate.type") -}}
    {{- $terminationGracePeriodSeconds := dict "scope" .scope "key" "terminationGracePeriodSeconds" "ctx" .ctx "scopeLocal" .scopeLocal | include "unibox.render.integer" | atoi -}}
    {{- $_ := set $probe "terminationGracePeriodSeconds" $terminationGracePeriodSeconds -}}
  {{- end -}}

  {{- dict (printf "%sProbe" .key) $probe | toJson -}}

{{- end -}}

{{- define "unibox.container.probe.http.headers" -}}
  {{- $_ := list .scopeParent .name "scalar" | include "unibox.validate.type" -}}
  {{- $value := dict "value" .scope "ctx" .ctx "scope" .scopeLocal | include "unibox.render" -}}
  {{- dict "name" .name "value" $value | toJson -}}
{{- end -}}

{{- define "unibox.container.resources" -}}
  {{- if (list .scope "resources" "!slice" | include "unibox.validate.type") -}}

    {{- $resources := dict -}}

    {{- if not (kindIs "map" .scope.resources) -}}

      {{- $preset := list "nano" "micro" "small" "medium" "large" "xlarge" "2xlarge"
          | dict "scope" .scope "key" "resources" "ctx" .ctx "scopeLocal" .scopeLocal "list"
          | include "unibox.render.enum" -}}

      {{- $resources = index (dict
        "nano" (dict
          "requests" (dict "cpu" "100m" "memory" "128Mi" "ephemeral-storage" "50Mi")
          "limits" (dict "cpu" "150m" "memory" "192Mi" "ephemeral-storage" "2Gi")
        )
        "micro" (dict
          "requests" (dict "cpu" "250m" "memory" "256Mi" "ephemeral-storage" "50Mi")
          "limits" (dict "cpu" "375m" "memory" "384Mi" "ephemeral-storage" "2Gi")
        )
        "small" (dict
          "requests" (dict "cpu" "500m" "memory" "512Mi" "ephemeral-storage" "50Mi")
          "limits" (dict "cpu" "750m" "memory" "768Mi" "ephemeral-storage" "2Gi")
        )
        "medium" (dict
          "requests" (dict "cpu" "500m" "memory" "1024Mi" "ephemeral-storage" "50Mi")
          "limits" (dict "cpu" "750m" "memory" "1536Mi" "ephemeral-storage" "2Gi")
        )
        "large" (dict
          "requests" (dict "cpu" "1.0" "memory" "2048Mi" "ephemeral-storage" "50Mi")
          "limits" (dict "cpu" "1.5" "memory" "3072Mi" "ephemeral-storage" "2Gi")
        )
        "xlarge" (dict
          "requests" (dict "cpu" "1.0" "memory" "3072Mi" "ephemeral-storage" "50Mi")
          "limits" (dict "cpu" "3.0" "memory" "6144Mi" "ephemeral-storage" "2Gi")
        )
        "2xlarge" (dict
          "requests" (dict "cpu" "1.0" "memory" "3072Mi" "ephemeral-storage" "50Mi")
          "limits" (dict "cpu" "6.0" "memory" "12288Mi" "ephemeral-storage" "2Gi")
        )
      ) $preset -}}

    {{- else -}}

      {{- template "unibox.validate.map" (list .scope "resources" "container.resources") -}}

      {{- $isSimple := or (hasKey .scope.resources "cpu") (hasKey .scope.resources "memory") (hasKey .scope.resources "storage") -}}
      {{- $isDetailed := or (hasKey .scope.resources "requests") (hasKey .scope.resources "limits") -}}

      {{- if and (not $isSimple) (not $isDetailed) -}}
        {{- list .scope "resources" "resources must be specified in simple format ('cpu', 'memory', etc.) or in detailed format ('requests', 'limits')" | include "unibox.fail" -}}
      {{- else if and $isSimple $isDetailed -}}
        {{- list .scope "resources" "resources must be specified in only one of the formats: in simple ('cpu', 'memory', etc.) or detailed ('requests', 'limits')" | include "unibox.fail" -}}
      {{- end -}}

      {{- $_ := list .scope "resources" | include "unibox.getPath" | set .scope.resources "__path__" -}}
      {{- $requests := dict -}}
      {{- $limits := dict -}}

      {{- if (list .scope.resources "cpu" "scalar" | include "unibox.validate.type") -}}
        {{- $value := dict "value" .scope.resources.cpu "ctx" .ctx "scope" .scope | include "unibox.render" -}}
        {{- /* TODO: add validation for cpu value */ -}}
        {{- $_ := set $requests "cpu" $value -}}
      {{- end -}}

      {{- if (list .scope.resources "memory" "scalar" | include "unibox.validate.type") -}}
        {{- $value := dict "value" .scope.resources.memory "ctx" .ctx "scope" .scope | include "unibox.render" -}}
        {{- /* TODO: add validation for memory value */ -}}
        {{- $_ := set $requests "memory" $value -}}
        {{- $_ := set $limits "memory" $value -}}
      {{- end -}}

      {{- if (list .scope.resources "storage" "scalar" | include "unibox.validate.type") -}}
        {{- $value := dict "value" .scope.resources.storage "ctx" .ctx "scope" .scope | include "unibox.render" -}}
        {{- /* TODO: add validation for storage value */ -}}
        {{- $_ := set $requests "ephemeral-storage" $value -}}
      {{- end -}}

      {{- if (list .scope.resources "requests" "map" | include "unibox.validate.type") -}}
        {{- $_ := list .scope.resources "requests" | include "unibox.getPath" | set .scope.resources.requests "__path__" -}}
        {{- template "unibox.validate.map" (list .scope.resources "requests" "container.resources.requests") -}}

        {{- if (list .scope.resources.requests "cpu" "scalar" | include "unibox.validate.type") -}}
          {{- $value := dict "value" .scope.resources.requests.cpu "ctx" .ctx "scope" .scope | include "unibox.render" -}}
          {{- /* TODO: add validation for cpu value */ -}}
          {{- $_ := set $requests "cpu" $value -}}
        {{- end -}}

        {{- if (list .scope.resources.requests "memory" "scalar" | include "unibox.validate.type") -}}
          {{- $value := dict "value" .scope.resources.requests.memory "ctx" .ctx "scope" .scope | include "unibox.render" -}}
          {{- /* TODO: add validation for memory value */ -}}
          {{- $_ := set $requests "memory" $value -}}
        {{- end -}}

        {{- if (list .scope.resources.requests "storage" "scalar" | include "unibox.validate.type") -}}
          {{- $value := dict "value" .scope.resources.requests.storage "ctx" .ctx "scope" .scope | include "unibox.render" -}}
          {{- /* TODO: add validation for storage value */ -}}
          {{- $_ := set $requests "ephemeral-storage" $value -}}
        {{- end -}}
      {{- end -}}

      {{- if (list .scope.resources "limits" "map" | include "unibox.validate.type") -}}
        {{- $_ := list .scope.resources "limits" | include "unibox.getPath" | set .scope.resources.limits "__path__" -}}
        {{- template "unibox.validate.map" (list .scope.resources "limits" "container.resources.requests") -}}

        {{- if (list .scope.resources.limits "cpu" "scalar" | include "unibox.validate.type") -}}
          {{- $value := dict "value" .scope.resources.limits.cpu "ctx" .ctx "scope" .scope | include "unibox.render" -}}
          {{- /* TODO: add validation for cpu value */ -}}
          {{- $_ := set $limits "cpu" $value -}}
        {{- end -}}

        {{- if (list .scope.resources.limits "memory" "scalar" | include "unibox.validate.type") -}}
          {{- $value := dict "value" .scope.resources.limits.memory "ctx" .ctx "scope" .scope | include "unibox.render" -}}
          {{- /* TODO: add validation for memory value */ -}}
          {{- $_ := set $limits "memory" $value -}}
        {{- end -}}

        {{- if (list .scope.resources.limits "storage" "scalar" | include "unibox.validate.type") -}}
          {{- $value := dict "value" .scope.resources.limits.storage "ctx" .ctx "scope" .scope | include "unibox.render" -}}
          {{- /* TODO: add validation for storage value */ -}}
          {{- $_ := set $limits "ephemeral-storage" $value -}}
        {{- end -}}
      {{- end -}}

      {{- if $requests -}}
        {{- $_ := set $resources "requests" $requests -}}
      {{- end -}}
      {{- if $limits -}}
        {{- $_ := set $resources "limits" $limits -}}
      {{- end -}}

    {{- end -}}

    {{- dict "resources" $resources | toJson -}}

  {{- else -}}
    {{- dict | toJson -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.container.mount.entry" -}}

  {{- if (not (has .name .volumeNames)) -}}
    {{- $knownVolumeNames := "" -}}
    {{- if (len .volumeNames) -}}
      {{- $knownVolumeNames = sortAlpha .volumeNames | join "', '" | printf "the following volumes are defined in the parent object: '%s'" -}}
    {{- else -}}
      {{- $knownVolumeNames = "there are no volumes specified by the .volume field in the parent object" -}}
    {{- end -}}
    {{- printf "unknown volume name is specified '%s', %s" .name $knownVolumeNames | list .scope | include "unibox.fail" -}}
  {{- end -}}

  {{- $document := dict "name" .name -}}

  {{- if (kindIs "map" .scope) -}}

    {{- template "unibox.validate.map" (list .scope "container.mount") -}}

    {{- if (list .scope "path" "scalar" | include "unibox.validate.type") -}}
      {{- $mountPath := dict "value" .scope.path "ctx" .ctx "scope" .scopeLocal | include "unibox.render" -}}
      {{- $_ := set $document "mountPath" $mountPath -}}
    {{- else -}}
      {{- list .scope "there is no mandatory .path field specified for the mount" | include "unibox.fail" -}}
    {{- end -}}

    {{- if (hasKey .scope "propagation") -}}
      {{- $mountPropagation := list "None" "Bidirectional" "HostToContainer"
          | dict "scope" .scope "key" "type" "ctx" .ctx "scopeLocal" .scopeLocal "list"
          | include "unibox.render.enum" -}}
      {{- $_ := set $document "mountPropagation" $mountPropagation -}}
    {{- end -}}

    {{- $readOnly := list "true" "false" "recursive"
        | dict "scope" .scope "key" "type" "ctx" .ctx "scopeLocal" .scopeLocal "default" "false" "list"
        | include "unibox.render.enum" -}}

    {{- if (eq $readOnly "true") -}}
      {{- $_ := set $document "readOnly" true -}}
    {{- else if (eq $readOnly "recursive") -}}
      {{- $_ := set $document "readOnly" true -}}
      {{- $_ := set $document "recursiveReadOnly" true -}}
    {{- else if (eq $readOnly "false") -}}
      {{- $_ := set $document "readOnly" false -}}
    {{- else -}}
      {{- printf "this will never happen, since all possible $readOnly values are covered by 'if'/'else' (typeKey: '%s')" $readOnly | fail -}}
    {{- end -}}

    {{- if (and (hasKey .scope "subPath") (hasKey .scope "subPathExpr")) -}}
      {{- list .scope "both .subPath and .subPathExpr were specified for the mount, only one of those keys should be specified" | include "unibox.fail" -}}
    {{- else if (hasKey .scope "subPath") -}}
      {{- $subPath := dict "value" .scope.subPath "ctx" .ctx "scope" .scopeLocal | include "unibox.render" -}}
      {{- $_ := set $document "subPath" $subPath -}}
    {{- else if (hasKey .scope "subPathExpr") -}}
      {{- $subPathExpr := dict "value" .scope.subPathExpr "ctx" .ctx "scope" .scopeLocal | include "unibox.render" -}}
      {{- $_ := set $document "subPathExpr" $subPathExpr -}}
    {{- end -}}

  {{- else -}}

    {{- $_ := list .scopeParent .name "scalar" | include "unibox.validate.type" -}}
    {{- $mountPath := include "unibox.render" (dict "value" .scope "ctx" .ctx "scope" .scopeLocal) -}}

    {{- $_ := set $document "mountPath" $mountPath -}}

  {{- end -}}

  {{- toJson $document -}}

{{- end -}}
