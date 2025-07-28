
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
    {{- if contains "{{" (toJson .value) }}
      {{- if .scope -}}
        {{- tpl $value (merge (dict "Scope" .scope) .ctx) }}
      {{- else -}}
        {{- tpl $value .ctx }}
      {{- end -}}
    {{- else -}}
      {{- $value }}
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
    {{- $value = include "unibox.render" (dict "value" $value "ctx" .ctx "scope" .scopeLocal) -}}
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

{{- define "unibox.name" -}}
  {{- if list .scope "nameOverride" "scalar" | include "unibox.validate.type" -}}
    {{- if (hasKey .scope "name") -}}
      {{- (printf "both keys %s (value: '%s') and %s (value: '%s') are specified, only one of these keys is allowed to be specified"
        (list .scope "name" | include "unibox.getPath")
        .scope.name
        (list .scope "nameOverride" | include "unibox.getPath")
        .scope.nameOverride
      ) | fail -}}
    {{- end -}}
    {{- template "unibox.render" (dict "value" .scope.nameOverride "ctx" .ctx "scope" .scope) -}}
  {{- else -}}
    {{- $name := .name -}}
    {{- if list .scope "name" "scalar" | include "unibox.validate.type" -}}
      {{ $name = include "unibox.render" (dict "value" .scope.name "ctx" .ctx "scope" .scope) -}}
    {{- end -}}
    {{- if and .isFull (or .ctx.Values.nameOverride (ne .ctx.Release.Name (include "unibox.appName" .ctx))) -}}
      {{- $name = printf "%s-%s" (include "unibox.releaseName" .ctx) $name -}}
    {{- end -}}
    {{- $name | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.labels.raw" -}}
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
    {{- if (get .ctx.Values.app "version") }}
      {{- $_ := set $labels "app.kubernetes.io/version" (include "unibox.appVersion" .ctx) -}}
    {{- end -}}
  {{- end -}}
  {{- $labelsKey := default "labels" .labelsKey -}}
  {{- if (hasKey .scope $labelsKey) -}}
    {{- $labelsCustom := get .scope $labelsKey -}}
    {{- if not (kindIs "map" $labelsCustom) -}}
      {{- kindOf $labelsCustom | replace "invalid" "null" | printf "Custom labels (field .%s) is expected to be an object, but its type is '%s'" $labelsKey | fail -}}
    {{- end -}}
    {{- $ctx := .ctx -}}
    {{- $scope := .scope -}}
    {{- range $k, $v := $labelsCustom -}}
      {{- if (list "app.kubernetes.io/instance" "app.kubernetes.io/managed-by" "app.kubernetes.io/component" | has $k) -}}
        {{- /* Fail only if standard list of labels contains the key. This will allow
        to define 'app.kubernetes.io/component' if it is not defined yet */ -}}
        {{- if (hasKey $labels $k) -}}
          {{- printf "Custom label with name '%s' is not allowed" $k | fail -}}
        {{- end -}}
      {{- end -}}
      {{- $_ := include "unibox.render" (dict "value" $v "ctx" $ctx "scope" $scope) | set $labels $k -}}
    {{- end -}}
  {{- end -}}
  {{- $labels | toJson -}}
{{- end -}}

{{- define "unibox.labels" -}}
  {{- print "\nlabels:" -}}
  {{- range $k, $v := include "unibox.labels.raw" . | fromJson -}}
    {{- printf "%s: %s" (quote $k) (quote $v) | nindent 2 -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.selector" -}}
  {{- $selectLabels := list "app.kubernetes.io/instance" "app.kubernetes.io/component" "app.kubernetes.io/name" -}}
  {{- /* get labels now using unibox.labels.raw as it will validate labelsKey and make sure
  it is a map. Below we assume that labelsKey is a valid object and don't perform
  any validation. */ -}}
  {{- $labels := include "unibox.labels.raw" . | fromJson -}}
  {{- $labelsKey := default "labels" .labelsKey -}}
  {{- if (hasKey .scope $labelsKey) -}}
    {{- $selectLabels = keys (get .scope $labelsKey) | concat $selectLabels | uniq -}}
  {{- end -}}
  {{- print "\nselector:\n  matchLabels:" -}}
  {{- range $k, $v := $labels -}}
    {{- if (has $k $selectLabels) -}}
      {{- printf "%s: %s" (quote $k) (quote $v) | nindent 4 -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.annotations" -}}
  {{- $annotationsKey := default "annotations" .annotationsKey -}}
  {{- if (hasKey .scope $annotationsKey) -}}
    {{- $annotations := get .scope $annotationsKey -}}
    {{- if not (kindIs "map" $annotations) -}}
      {{- kindOf $annotations | replace "invalid" "null" | printf "Custom annotations (field .%s) is expected to be an object, but its type is '%s'" $annotationsKey | fail -}}
    {{- end -}}
    {{- print "\nannotations:" -}}
    {{- $ctx := .ctx -}}
    {{- $scope := .scope -}}
    {{- range $k, $v := $annotations -}}
      {{- include "unibox.render" (dict "value" $v "ctx" $ctx "scope" $scope) | quote | printf "%s: %s" (quote $k) | nindent 2 -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "unibox.metadata" -}}
    {{- print "metadata:" -}}
    {{- if .name -}}
      {{- quote .name | printf "name: %s" | nindent 2 -}}
    {{- end -}}
    {{- if .isNamespaced -}}
      {{- quote .ctx.Release.Namespace | printf "namespace: %s" | nindent 2 -}}
    {{- end -}}
    {{- include "unibox.labels" . | indent 2 -}}
    {{- include "unibox.annotations" . | indent 2 -}}
{{- end -}}

{{- define "unibox.document" -}}
    {{- printf "\n---\napiVersion: %s\nkind: %s\n" .apiVersion .kind -}}
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
    {{- printf "%s.%s" $parentKey $key -}}
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

{{- define "unibox.validate.scalar" -}}
{{- end -}}

{{- /*
    .singleKey
    .pluralKey
    .defaultName
    .noDefaultNameMessage
    .defaultDisabled
    .asArray
    .isEntryMap
    .callback
*/ -}}
{{- define "unibox.foreach" -}}

  {{- $entities := dict -}}
  {{- $scope := .scope -}}
  {{- $ctx := .ctx -}}
  {{- $defaultDisabled := .defaultDisabled -}}
  {{- $isFullName := .isFullName -}}
  {{- $pluralKey := hasKey . "pluralKey" | ternary .pluralKey (printf "%ss" .singleKey) -}}
  {{- $isEntryMap := hasKey . "isEntryMap" | ternary .isEntryMap true -}}
  {{- $validateMap := default false .validateMap -}}

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
        {{- $name = dict "isFull" false "name" $key "ctx" $ctx "scope" . | include "unibox.name" -}}
        {{- if (hasKey $entities $name) -}}
          {{- $name | printf "duplicated name '%s'" | list $entitiesRaw $key | include "unibox.fail" -}}
        {{- end -}}
      {{- end -}}
      {{- if and $isEntryMap $validateMap -}}
        {{- template "unibox.validate.map" (list $entitiesRaw $key $validateMap) -}}
      {{- end -}}
      {{- $_ = set $entities $name (dict "scopeParent" $entitiesRaw "scope" .) -}}
    {{- end -}}
  {{- end -}}

  {{- if and .singleKey (list $scope .singleKey "map" | include "unibox.validate.type") -}}
    {{- $entity := index $scope .singleKey -}}
    {{- if (hasKey $entity "enabled" | ternary .enabled (not $defaultDisabled)) -}}
      {{- if and $isEntryMap $validateMap -}}
        {{- template "unibox.validate.map" (list $scope .singleKey $validateMap) -}}
      {{- end -}}
      {{- $_ := list $scope .singleKey | include "unibox.getPath" | set $entity "__path__" -}}
      {{- $name := dict "isFull" false "name" .defaultName "ctx" $ctx "scope" $entity | include "unibox.name" -}}
      {{- if not $name -}}
        {{- .noDefaultNameMessage | list $scope .singleKey | include "unibox.fail" -}}
      {{- else if (hasKey $entities $name) -}}
        {{- $name | printf "duplicated name '%s'" | list $scope .singleKey | include "unibox.fail" -}}
      {{- end -}}
      {{- $_ = set $entities $name (dict "scopeParent" $entity "scope" $entity) -}}
    {{- end -}}
  {{- end -}}

  {{- $callback := .callback -}}
  {{- $asArray := default false .asArray -}}
  {{- range $name, $_ := $entities -}}
    {{- $args := dict "name" $name "ctx" $ctx "scope" .scope "scopeLocal" $scope "scopeParent" .scopeParent -}}
    {{- if $asArray -}}
      {{- include $callback $args | indent 2 | trim | printf "\n- %s" -}}
    {{- else -}}
      {{- include $callback $args -}}
    {{- end -}}
  {{- end -}}

{{- end -}}

{{- define "unibox.getAllowedKeys" -}}
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
    "service" (list
      "props" "properties"
      "enabled"
      "name" "nameOverride"
      "annotations"
      "labels"
    )
  ) . | toJson -}}
{{- end -}}

{{- define "unibox.dump" -}}
  {{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
