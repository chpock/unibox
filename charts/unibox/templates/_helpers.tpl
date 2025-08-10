
{{- define "unibox.releaseName" -}}
  {{- $value := default .Release.Name .Values.nameOverride -}}
  {{- include "unibox.render" (dict "value" $value "ctx" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "unibox.chartName" -}}
  {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "unibox.appName" -}}
  {{- if (get (get .Values "app" | default dict) "name" | default "") -}}
    {{- include "unibox.render" (dict "value" .Values.app.name "ctx" .) -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.appVersion" -}}
  {{- if (get (get .Values "app" | default dict) "version" | default "") -}}
    {{- include "unibox.render" (dict "value" .Values.app.version "ctx" .) -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.render" -}}
  {{- if (kindIs "int" .value) -}}
    {{- .value -}}
  {{- else if (kindIs "float64" .value) -}}
    {{- printf "%v" .value -}}
  {{- else -}}
    {{- $value := typeIs "string" .value | ternary .value (.value | toYaml) -}}
    {{- if contains "{{" (toJson .value) -}}
      {{- if .scope -}}
        {{- tpl $value (merge (dict "Scope" .scope) .ctx) -}}
      {{- else -}}
        {{- tpl $value .ctx -}}
      {{- end -}}
    {{- else -}}
      {{- $value -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.render.integer" -}}
  {{- $value := index .scope .key -}}
  {{- $result := "" -}}
  {{- if (kindIs "int" $value) -}}
    {{- $result = $value -}}
  {{- else if (kindIs "float64" $value) -}}
    {{- $rounded := round $value 0 -}}
    {{- if eq (printf "%v" $rounded) (printf "%v" $value) -}}
      {{- $result = int64 $rounded -}}
    {{- end -}}
  {{- else if (kindIs "string" $value) -}}
    {{- $value = default .scope .scopeLocal | dict "value" $value "ctx" .ctx "scope" | include "unibox.render" -}}
    {{- if (regexMatch "^\\d+$" $value) -}}
      {{- $result = $value -}}
    {{- end -}}
  {{- end -}}
  {{- $result = toString $result -}}
  {{- if eq $result "" -}}
    {{- "the key is expected to have an integer type or a string that can be rendered as an integer number" | list .scope .key "" | include "unibox.validate.type.fail" -}}
  {{- end -}}
  {{- $result -}}
{{- end -}}

{{- define "unibox.render.enum" -}}
  {{- $value := "" -}}
  {{- if (list .scope .key "string" | include "unibox.validate.type") -}}
    {{- $value = default .scope .scopeLocal | dict "value" (index .scope .key) "ctx" .ctx "scope" | include "unibox.render" -}}
    {{- if not (has $value .list) -}}
      {{- last .list | printf "'%s' or '%s'" (initial .list | join "', '") | printf "the key value is specified as '%s', but one of the following values is expected: %s" $value | list .scope .key "" | include "unibox.fail" -}}
    {{- end -}}
  {{- else -}}
    {{- $value = .default -}}
  {{- end -}}
  {{- $value -}}
{{- end -}}

{{- define "unibox.name" -}}
  {{- $name := .defaultName -}}
  {{- if list .scope "nameOverride" "scalar" | include "unibox.validate.type" -}}
    {{- if (hasKey .scope "name") -}}
      {{- (printf "both keys %s (value: '%s') and %s (value: '%s') are specified, only one of these keys is allowed to be specified"
        (list .scope "name" | include "unibox.getPath")
        .scope.name
        (list .scope "nameOverride" | include "unibox.getPath")
        .scope.nameOverride
      ) | fail -}}
    {{- end -}}
    {{- $name = include "unibox.render" (dict "value" .scope.nameOverride "ctx" .ctx "scope" .scope) -}}
    {{- if not $name -}}
      {{- list .scope "nameOverride" "an empty name is not allowed" | include "unibox.fail" -}}
    {{- end -}}
    {{- if .prefixName -}}
      {{- $name = printf "%s-%s" .prefixName $name -}}
    {{- end -}}
  {{- else -}}
    {{- if list .scope "name" "scalar" | include "unibox.validate.type" -}}
      {{ $name = include "unibox.render" (dict "value" .scope.name "ctx" .ctx "scope" .scope) -}}
      {{- if not $name -}}
        {{- list .scope "name" "an empty name is not allowed" | include "unibox.fail" -}}
      {{- end -}}
    {{- end -}}
    {{- if .prefixName -}}
      {{- if $name -}}
        {{- $name = printf "%s-%s" .prefixName $name -}}
      {{- else -}}
        {{- $name = .prefixName -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- /* TODO: do not use 'trunc 63' here, but check and thow an error if $name has more than 63 characters. */ -}}
  {{- $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "unibox.labels" -}}
  {{- $labels := dict
    "helm.sh/chart" (include "unibox.chartName" .ctx)
    "app.kubernetes.io/instance" .ctx.Release.Name
    "app.kubernetes.io/managed-by" .ctx.Release.Service
  -}}
  {{- if (hasKey . "component") -}}
    {{- $_ := set $labels "app.kubernetes.io/component" .component -}}
  {{- end -}}
  {{- if (hasKey .ctx.Values "app") -}}
    {{- if (get .ctx.Values.app "name") -}}
      {{- $_ := set $labels "app.kubernetes.io/name" (include "unibox.appName" .ctx) -}}
    {{- end -}}
    {{- if (get .ctx.Values.app "version") -}}
      {{- $_ := set $labels "app.kubernetes.io/version" (include "unibox.appVersion" .ctx) -}}
    {{- end -}}
  {{- end -}}
  {{- $labelsKey := default "labels" .labelsKey -}}
  {{- if (list .scope $labelsKey "map" | include "unibox.validate.type") -}}
    {{- $ctx := .ctx -}}
    {{- $scope := .scope -}}
    {{- $labelsCustom := index .scope $labelsKey -}}
    {{- $_ := list .scope $labelsKey | include "unibox.getPath" | set $labelsCustom "__path__" -}}
    {{- range $k, $v := omit $labelsCustom "__path__" -}}
      {{- if (list "app.kubernetes.io/instance" "app.kubernetes.io/managed-by" "app.kubernetes.io/component" | has $k) -}}
        {{- /* Fail only if standard list of labels contains the key. This will allow
        to define 'app.kubernetes.io/component' if it is not defined yet */ -}}
        {{- if (hasKey $labels $k) -}}
          {{- list $labelsCustom $k "this custom label name is not allowed" | include "unibox.fail" -}}
        {{- end -}}
      {{- end -}}
      {{- $_ := include "unibox.render" (dict "value" $v "ctx" $ctx "scope" $scope) | set $labels $k -}}
    {{- end -}}
  {{- end -}}
  {{- $labels | toJson -}}
{{- end -}}

{{- define "unibox.annotations" -}}
  {{- $annotations := dict -}}
  {{- $annotationsKey := default "annotations" .annotationsKey -}}
  {{- if (list .scope $annotationsKey "map" | include "unibox.validate.type") -}}
    {{- $ctx := .ctx -}}
    {{- $scope := .scope -}}
    {{- range $k, $v :=  index .scope $annotationsKey -}}
      {{- $_ := dict "value" $v "ctx" $ctx "scope" $scope | include "unibox.render" | set $annotations $k -}}
    {{- end -}}
  {{- end -}}
  {{- $annotations | toJson -}}
{{- end -}}

{{- define "unibox.metadata" -}}
    {{- $metadata := dict -}}
    {{- if .name -}}
      {{- $_ := set $metadata "name" .name -}}
    {{- end -}}
    {{- if .isNamespaced -}}
      {{- $_ := set $metadata "namespace" .ctx.Release.Namespace -}}
    {{- end -}}
    {{- with include "unibox.labels" . | fromJson -}}
      {{- $_ := set $metadata "labels" . -}}
    {{- end -}}
    {{- with include "unibox.annotations" . | fromJson -}}
      {{- $_ := set $metadata "annotations" . -}}
    {{- end -}}
    {{- dict "metadata" $metadata | toJson -}}
{{- end -}}

{{- define "unibox.selector" -}}
  {{- $selectLabels := list "app.kubernetes.io/instance" "app.kubernetes.io/component" "app.kubernetes.io/name" -}}
  {{- /* get labels now using unibox.labels as it will validate labelsKey and make sure
  it is a map. Below we assume that labelsKey is a valid object and don't perform
  any validation. */ -}}
  {{- $labels := include "unibox.labels" . | fromJson -}}
  {{- $labelsKey := default "labels" .labelsKey -}}
  {{- if (hasKey .scope $labelsKey) -}}
    {{- $selectLabels = keys (get .scope $labelsKey) | concat $selectLabels | uniq -}}
  {{- end -}}
  {{- $matchLabels := dict -}}
  {{- range $k, $v := $labels -}}
    {{- if (has $k $selectLabels) -}}
      {{- $_ := set $matchLabels $k $v -}}
    {{- end -}}
  {{- end -}}
  {{- dict "selector" (dict "matchLabels" $matchLabels) | toJson -}}
{{- end -}}

{{- define "unibox.document" -}}
    {{- dict "apiVersion" .apiVersion "kind" .kind | toJson -}}
{{- end -}}

{{- define "unibox.isScalar" -}}
  {{- $kind := kindOf . -}}
  {{- if or (eq $kind "string") (eq $kind "int") (eq $kind "float64") (eq $kind "bool") -}}
    true
  {{- end -}}
{{- end -}}

{{- define "unibox.validateAll" -}}
  {{- if (hasKey . "app") -}}
    {{- if not (kindIs "map" .app) -}}
      {{- kindOf .app | replace "invalid" "null" | printf "Root field .app is expected to be an object, but its type is '%s'" | fail -}}
    {{- end -}}
    {{- if and (hasKey .app "name") (not (include "unibox.isScalar" .app.name)) -}}
      {{- kindOf .app.name | replace "invalid" "null" | printf "Root field .app.name is expected to be a scalar, but its type is '%s'" | fail -}}
    {{- end -}}
    {{- if and (hasKey .app "version") (not (include "unibox.isScalar" .app.version)) -}}
      {{- kindOf .app.version | replace "invalid" "null" | printf "Root field .app.version is expected to be a scalar, but its type is '%s'" | fail -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set . "__path__" "." -}}
  {{- template "unibox.validate.map" (list . "root") -}}
{{- end -}}

{{- define "unibox.getPath" -}}
  {{- $scope := index . 0 -}}
  {{- $key := index . 1 -}}
  {{- $parentKey := get $scope "__path__" -}}
  {{- if and $parentKey (not (eq $parentKey ".")) -}}
    {{- if contains "." $key -}}
      {{- printf "%s[\"%s\"]" $parentKey $key -}}
    {{- else -}}
      {{- printf "%s.%s" $parentKey $key -}}
    {{- end -}}
  {{- else -}}
    {{- printf ".%s" $key -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.getType" -}}
  {{- kindOf . | replace "invalid" "null" -}}
{{- end -}}

{{- define "unibox.fail" -}}
  {{- $msg := index . (sub (len .) 1) -}}
  {{- $path := "" -}}
  {{- if eq (len .) 2 -}}
    {{- $path = index . 0 "__path__" -}}
  {{- else -}}
    {{- $path = include "unibox.getPath" . -}}
    {{- if and (eq (len .) 4) (kindIs "int" (index . 2)) -}}
      {{- $path = printf "%s[%d]" $path (index . 2) -}}
    {{- end -}}
  {{- end -}}
  {{- printf "[%s] %s" $path $msg | fail -}}
{{- end -}}

{{- define "unibox.validate.type.fail" -}}
  {{- $scope := index . 0 -}}
  {{- $key := index . 1 -}}
  {{- $msg := index . (sub (len .) 1) -}}
  {{- $val := get $scope $key -}}
  {{- $idx := "" -}}
  {{- if and (eq (len .) 4) (kindIs "int" (index . 2)) -}}
    {{- $idx = index . 2 -}}
    {{- $val = index $val $idx -}}
  {{- end -}}
  {{- $msgAdd := include "unibox.getType" $val | printf "but its type is '%s'" -}}
  {{- printf "%s, %s" $msg $msgAdd | list $scope $key $idx | include "unibox.fail" -}}
{{- end -}}

{{- /* TODO: refactor these ugly validation function and don't use hacks with variable number of arguments */ -}}

{{- define "unibox.validate.type" -}}
  {{- $scope := index . 0 -}}
  {{- $key := index . 1 -}}
  {{- $type := index . (sub (len .) 1) -}}
  {{- if (hasKey $scope $key) -}}
    {{- $val := index $scope $key -}}
    {{- $idx := "" -}}
    {{- $fieldType := "key" -}}
    {{- if eq (len .) 4 -}}
      {{- $idx = index . 2 -}}
      {{- $val = index $val $idx -}}
      {{- $fieldType = "value" -}}
    {{- end -}}
    {{- if eq $type "!map" -}}
      {{- if or (kindIs "invalid" $val) (kindIs "map" $val) -}}
        {{- printf "the %s is expected to have a scalar or 'slice' type" $fieldType | list $scope $key $idx | include "unibox.validate.type.fail" -}}
      {{- end -}}
    {{- else if eq $type "!slice" -}}
      {{- if or (kindIs "invalid" $val) (kindIs "slice" $val) -}}
        {{- printf "the %s is expected to have a scalar or 'map' type" $fieldType | list $scope $key $idx | include "unibox.validate.type.fail" -}}
      {{- end -}}
    {{- else if eq $type "scalar" -}}
      {{- if not (include "unibox.isScalar" $val) -}}
        {{- printf "the %s is expected to have a scalar type" $fieldType | list $scope $key $idx | include "unibox.validate.type.fail" -}}
      {{- end -}}
    {{- else if not (kindIs $type $val) -}}
      {{- printf "the %s is expected to have '%s' type" $fieldType $type | list $scope $key $idx | include "unibox.validate.type.fail" -}}
    {{- end -}}
    true
  {{- end -}}
{{- end -}}

{{- define "unibox.validate.map" -}}
  {{- $scope := index . 0 -}}
  {{- $allowedKeys := index . (sub (len .) 1) | include "unibox.getAllowedKeys" | fromJsonArray -}}
  {{- $unknownKeys := list -}}
  {{- $value := $scope -}}
  {{- $key := "" -}}
  {{- if (eq (len .) 3) -}}
    {{- $key = index . 1 -}}
    {{- $value = index $scope $key -}}
  {{- end -}}
  {{- range keys $value -}}
    {{- if and (not (eq . "__path__")) (not (has . $allowedKeys)) -}}
      {{- $unknownKeys = append $unknownKeys . -}}
    {{- end -}}
  {{- end -}}
  {{- if $unknownKeys -}}
      {{- $msg := "" -}}
      {{- $msgAdd := "" -}}
      {{- if eq (len $unknownKeys) 1 -}}
        {{- $msg = first $unknownKeys | printf "the following unknown key was found in this map: '%s'" -}}
      {{- else -}}
        {{- $msg = sortAlpha $unknownKeys | join "', '" | printf "the following unknown keys were found in this map: '%s'" -}}
      {{- end -}}
      {{- if eq (len $allowedKeys) 1 -}}
        {{- $msgAdd = first $allowedKeys | printf "This map can contain only the following key:\n  - %s" -}}
      {{- else -}}
        {{- $msgAdd = sortAlpha $allowedKeys | join "\n  - " | printf "This map can contain only the following keys:\n  - %s" -}}
      {{- end -}}
      {{- $msg = printf "%s\n\n%s" $msg $msgAdd -}}
      {{- if (eq (len .) 3) -}}
        {{- list $scope $key $msg | include "unibox.fail" -}}
      {{- else -}}
        {{- list $scope $msg | include "unibox.fail" -}}
      {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.validate.global.type" -}}
  {{- $scope := index . 0 -}}
  {{- $key := index . 1 -}}
  {{- $type := index . 2 -}}
  {{- if and (hasKey $scope "global") (kindIs "map" $scope.global) (hasKey $scope.global $key) -}}
    {{- $_ := set $scope.global "__path__" ".global" -}}
    {{- list $scope.global $key $type | include "unibox.validate.type" -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.foreach" -}}

  {{- $entities := dict -}}
  {{- $scope := .scope -}}
  {{- $ctx := .ctx -}}
  {{- $defaultDisabled := .defaultDisabled -}}
  {{- $singleKey := .singleKey -}}
  {{- $pluralKey := hasKey . "pluralKey" | ternary .pluralKey (printf "%ss" .singleKey) -}}
  {{- $isEntryMap := hasKey . "isEntryMap" | ternary .isEntryMap true -}}
  {{- $validateMap := default false .validateMap -}}
  {{- $noDefaultNameMessage := .noDefaultNameMessage -}}
  {{- $prefixName := .prefixName -}}
  {{- $releaseName := include "unibox.releaseName" .ctx -}}
  {{- $appName := include "unibox.appName" .ctx -}}
  {{- $nameFullRequired := and $isEntryMap $releaseName (or (not (hasKey .ctx.Values "nameOverride")) (ne .ctx.Values.nameOverride "")) (or .ctx.Values.nameOverride (ne .ctx.Release.Name $appName)) | not | not -}}

  {{- if and $pluralKey (list $scope $pluralKey "map" | include "unibox.validate.type") -}}
    {{- $entitiesRaw := index $scope $pluralKey -}}
    {{- $_ := list $scope $pluralKey | include "unibox.getPath" | set $entitiesRaw "__path__" -}}
    {{- range $key, $_ := omit $entitiesRaw "__path__" -}}
      {{- $name := $key -}}
      {{- if $isEntryMap -}}
        {{- $_ := list $entitiesRaw $key "map" | include "unibox.validate.type" -}}
        {{- if not (hasKey . "enabled" | ternary .enabled (not $defaultDisabled)) -}}
          {{- continue -}}
        {{- end -}}
        {{- $_ = list $entitiesRaw $key | include "unibox.getPath" | set . "__path__" -}}
        {{- $name = dict "defaultName" $key "ctx" $ctx "scope" . "prefixName" $prefixName | include "unibox.name" -}}
        {{- if not $name -}}
          {{- list $entitiesRaw $key $noDefaultNameMessage | include "unibox.fail" -}}
        {{- else if (hasKey $entities $name) -}}
          {{- $name | printf "duplicated name '%s'" | list $entitiesRaw $key | include "unibox.fail" -}}
        {{- end -}}
      {{- end -}}
      {{- if and $isEntryMap $validateMap -}}
        {{- template "unibox.validate.map" (list $entitiesRaw $key $validateMap) -}}
      {{- end -}}
      {{- $nameFull := $name -}}
      {{- if and $nameFullRequired (not (hasKey . "nameOverride")) -}}
        {{- $nameFull = printf "%s-%s" $releaseName $nameFull -}}
      {{- end -}}
      {{- $_ = dict "scopeParent" $entitiesRaw "scope" . "nameFull" $nameFull | set $entities $name -}}
    {{- end -}}
  {{- end -}}

  {{- if and .singleKey (list $scope .singleKey "map" | include "unibox.validate.type") -}}
    {{- $entity := index $scope .singleKey -}}
    {{- if (hasKey $entity "enabled" | ternary .enabled (not $defaultDisabled)) -}}
      {{- if and $isEntryMap $validateMap -}}
        {{- template "unibox.validate.map" (list $scope .singleKey $validateMap) -}}
      {{- end -}}
      {{- $_ := list $scope .singleKey | include "unibox.getPath" | set $entity "__path__" -}}
      {{- $name := dict "defaultName" .defaultName "ctx" $ctx "scope" $entity "prefixName" $prefixName | include "unibox.name" -}}
      {{- if not $name -}}
        {{- list $scope .singleKey $noDefaultNameMessage | include "unibox.fail" -}}
      {{- else if (hasKey $entities $name) -}}
        {{- $name | printf "duplicated name '%s'" | list $scope .singleKey | include "unibox.fail" -}}
      {{- end -}}
      {{- $nameFull := $name -}}
      {{- if and $nameFullRequired (not (hasKey $entity "nameOverride")) -}}
        {{- $nameFull = printf "%s-%s" $releaseName $nameFull -}}
      {{- end -}}
      {{- $_ = dict "scopeParent" $entity "scope" $entity "nameFull" $nameFull | set $entities $name -}}
    {{- end -}}
  {{- end -}}

  {{- $callback := .callback -}}
  {{- $callbackArgs := default dict .callbackArgs -}}
  {{- $asDocumentArray := .asDocumentArray -}}
  {{- $asArray := .asArray -}}
  {{- $asText := .asText -}}
  {{- $asJson := and (or $asArray (not .asDocument)) (not $asDocumentArray) (not $asText) -}}
  {{- $result := list -}}
  {{- $resultFirst := true -}}
  {{- range $name, $_ := $entities -}}

    {{- $args := merge (dict "name" $name "ctx" $ctx "scope" .scope "scopeLocal" $scope "scopeParent" .scopeParent "nameFull" .nameFull) $callbackArgs -}}
    {{- $out := include $callback $args -}}

    {{- if or (not $out) (eq $out "[]") -}}
      {{- continue -}}
    {{- end -}}

    {{- if not $asText -}}
      {{- if $asDocumentArray -}}
        {{- $out = fromJsonArray $out -}}
      {{- else -}}
        {{- $out = fromJson $out -}}
      {{- end -}}
    {{- end -}}

    {{- if $asArray -}}
      {{- $result = append $result $out -}}
    {{- else if $asDocumentArray -}}
      {{- range $out -}}
        {{- if not $resultFirst -}}
          {{- print "\n---\n" -}}
        {{- else -}}
          {{- $resultFirst = false -}}
        {{- end -}}
        {{- . | toYaml -}}
      {{- end -}}
    {{- else if not $asJson -}}
      {{- if not $resultFirst -}}
        {{- print "\n---\n" -}}
      {{- end -}}
      {{- $out | toYaml -}}
    {{- else if not $resultFirst -}}
      {{- printf "unibox.foreach: Error: multiple not-JsonArray entries for key '%s/%s' previous '%s' scope: %s" $singleKey $pluralKey $result $scope | fail -}}
    {{- else -}}
      {{- $result = $out -}}
    {{- end -}}

    {{- $resultFirst = false -}}

  {{- end -}}

  {{- if or $asJson $asText -}}
    {{- $result | toJson -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.getAllowedKeys" -}}
  {{- $serviceCommonKeys := list
    "props" "properties"
    "enabled"
    "name" "nameOverride"
    "annotations"
    "labels"
    "type"
    "ports"
    "ingress"
  -}}
  {{- $containerCommonProbe := list
    "type"
    "failureThreshold"
    "periodSeconds"
    "timeoutSeconds"
    "initialDelaySeconds"
    "terminationGracePeriodSeconds"
  -}}
  {{- $containerProbeByProbe := dict
    "liveness" (list)
    "startup" (list)
    "readiness" (list "successThreshold")
  -}}
  {{- $containerProbeByType := dict
    "http" (list "host" "port" "path" "scheme" "headers")
    "exec" (list "command")
    "grpc" (list "port" "service")
    "tcp"  (list "host" "port")
  -}}
  {{- index (dict
    "root" (list
      "app" "global"
      "props" "properties"
      "nameOverride"
      "deployment" "deployments"
    )
    "deployment" (list
      "props" "properties"
      "enabled"
      "name" "nameOverride"
      "container" "containers"
      "service" "services"
      "updateStrategy"
      "annotations" "podAnnotations"
      "labels" "podLabels"
      "replicas"
    )
    "container" (list
      "props" "properties"
      "enabled"
      "name"
      "imagePullPolicy"
      "image"
      "env"
      "command"
      "args"
      "ports"
      "probes"
    )
    "container.image" (list
      "repository"
      "registry"
      "digest"
      "tag"
      "pullPolicy"
    )
    "container.env.secret" (list
      "secret" "configMap" "resourceField" "field"
      "key"
      "optional"
    )
    "container.env.configMap" (list
      "secret" "configMap" "resourceField" "field"
      "key"
      "optional"
    )
    "container.env.resourceField" (list
      "secret" "configMap" "resourceField" "field"
      "divisor"
      "container"
    )
    "container.env.field" (list
      "secret" "configMap" "resourceField" "field"
    )
    "service.ClusterIP" $serviceCommonKeys
    "service.ExternalName" $serviceCommonKeys
    "service.LoadBalancer" $serviceCommonKeys
    "service.NodePort" $serviceCommonKeys
    "ingress" (list
      "props" "properties"
      "enabled"
      "name" "nameOverride"
      "annotations"
      "labels"
      "class"
      "host"
      "path"
      "pathType"
      "port"
    )
    "container.probes" (list
      "readiness"
      "startup"
      "liveness"
    )
    "container.probe.liveness.http" (concat $containerCommonProbe (index $containerProbeByProbe "liveness") (index $containerProbeByType "http"))
    "container.probe.liveness.grpc" (concat $containerCommonProbe (index $containerProbeByProbe "liveness") (index $containerProbeByType "grpc"))
    "container.probe.liveness.exec" (concat $containerCommonProbe (index $containerProbeByProbe "liveness") (index $containerProbeByType "exec"))
    "container.probe.liveness.tcp"  (concat $containerCommonProbe (index $containerProbeByProbe "liveness") (index $containerProbeByType "tcp"))
    "container.probe.startup.http" (concat $containerCommonProbe (index $containerProbeByProbe "startup") (index $containerProbeByType "http"))
    "container.probe.startup.grpc" (concat $containerCommonProbe (index $containerProbeByProbe "startup") (index $containerProbeByType "grpc"))
    "container.probe.startup.exec" (concat $containerCommonProbe (index $containerProbeByProbe "startup") (index $containerProbeByType "exec"))
    "container.probe.startup.tcp"  (concat $containerCommonProbe (index $containerProbeByProbe "startup") (index $containerProbeByType "tcp"))
    "container.probe.readiness.http" (concat $containerCommonProbe (index $containerProbeByProbe "readiness") (index $containerProbeByType "http"))
    "container.probe.readiness.grpc" (concat $containerCommonProbe (index $containerProbeByProbe "readiness") (index $containerProbeByType "grpc"))
    "container.probe.readiness.exec" (concat $containerCommonProbe (index $containerProbeByProbe "readiness") (index $containerProbeByType "exec"))
    "container.probe.readiness.tcp"  (concat $containerCommonProbe (index $containerProbeByProbe "readiness") (index $containerProbeByType "tcp"))
  ) . | toJson -}}
{{- end -}}

{{- define "unibox.out" -}}
  {{- $out := "" -}}
  {{- $indent := 0 -}}
  {{- if (kindIs "slice" .) -}}
    {{- $out = index . (sub (len .) 1) -}}
    {{- $indent = eq (len .) 1 | ternary $indent (index . 0) -}}
  {{- else -}}
    {{- $out = . -}}
  {{- end -}}
  {{- if $out -}}
    {{- if or (kindIs "map" $out) (kindIs "slice" $out) -}}
      {{- $out = toYaml $out -}}
    {{- else if not (kindIs "string" $out) -}}
      {{- printf "unibox.out: unexpected output type '%s' for value '%s'" (kindOf $out) $out | fail -}}
    {{- end -}}
    {{- nindent $indent $out -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.dump" -}}
  {{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail -}}
{{- end -}}
