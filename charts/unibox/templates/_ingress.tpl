
{{- define "unibox.deployment.service.ingress" -}}

  {{- include "unibox.foreach" (dict
    "singleKey" "service"
    "prefixName" .name
    "callback" "unibox.service.ingress"
    "callbackArgs" (dict "nameComponent" .name "scopeComponent" .scope)
    "asArray" true
    "ctx" .ctx "scope" .scope
  ) -}}

{{- end -}}

{{- define "unibox.service.ingress" -}}

  {{- include "unibox.foreach" (dict
    "singleKey" "ingress"
    "pluralKey" false
    "validateMap" "ingress"
    "prefixName" .name
    "callback" "unibox.ingress"
    "callbackArgs" (dict "nameComponent" .nameComponent "scopeComponent" .scopeComponent "nameService" .name "scopeService" .scope "nameServiceFull" .nameFull)
    "ctx" .ctx "scope" .scope
  ) -}}

{{- end -}}

{{- define "unibox.ingress" -}}

  {{- $document := include "unibox.document" (dict
    "apiVersion" (include "unibox.capabilities.ingress.apiVersion" .ctx)
    "kind" "Ingress"
  ) | fromJson -}}

  {{- $_ := include "unibox.metadata" (dict
    "name" .nameFull
    "component" .nameComponent
    "isNamespaced" true
    "ctx" .ctx "scope" .scope
  ) | fromJson | merge $document -}}

  {{- $spec := dict -}}

  {{- if (list .scope "class" "scalar" | include "unibox.validate.type") -}}
    {{- $class := dict "value" .scope.class "ctx" .ctx "scope" .scope | include "unibox.render" -}}
    {{- $_ := set $spec "ingressClassName" $class -}}
  {{- end -}}

  {{- $path := "/" -}}
  {{- if (list .scope "path" "scalar" | include "unibox.validate.type") -}}
    {{- if not (hasKey .scope "host") -}}
        {{- "the path is defined, but host for this ingress is not defined by the .host field" | list .scope "path" | include "unibox.fail" -}}
    {{- end -}}
    {{- $path = dict "value" .scope.path "ctx" .ctx "scope" .scope | include "unibox.render" -}}
  {{- end -}}

  {{- if and (hasKey .scope "pathType") (not (hasKey .scope "host")) -}}
    {{- "the pathType is defined, but host for this ingress is not defined by the .host field" | list .scope "pathType" | include "unibox.fail" -}}
  {{- end -}}
  {{- $pathType := list "Prefix" "Exact" "ImplementationSpecific"
      | dict "scope" .scope "key" "pathType" "ctx" .ctx "default" "Prefix" "list"
      | include "unibox.render.enum" -}}

  {{- if and (hasKey .scope "port") (not (hasKey .scope "host")) -}}
    {{- "the port is defined, but host for this ingress is not defined by the .host field" | list .scope "port" | include "unibox.fail" -}}
  {{- end -}}

  {{- $rules := list -}}

  {{- if (list .scope "host" "scalar" | include "unibox.validate.type") -}}

    {{- $servicePorts := include "unibox.service.getPorts" (dict "ctx" .ctx "scope" .scopeService) | fromJsonArray -}}

    {{- $host := dict "value" .scope.host "ctx" .ctx "scope" .scope | include "unibox.render" -}}
    {{- $port := "http" -}}

    {{- if (list .scope "port" "scalar" | include "unibox.validate.type") -}}
      {{- $port = dict "value" .scope.port "ctx" .ctx "scope" .scope | include "unibox.render" -}}
    {{- end -}}

    {{- if not (has $port $servicePorts) -}}
      {{- $msg := "" -}}
      {{- if (len $servicePorts) -}}
        {{- $msg = sortAlpha $servicePorts | join "', '" | printf "but the parent service has only the following %s: '%s'" (len $servicePorts | plural "port" "ports") -}}
      {{- else -}}
        {{- $msg = "but the parent service has no ports defined" -}}
      {{- end -}}
      {{- if (hasKey .scope "port") -}}
        {{- printf "port name '%s' is specified, %s" $port $msg | list .scope "port" | include "unibox.fail" -}}
      {{- else -}}
        {{- printf "port is not defined and the '%s' port name should be used by default, %s" $port $msg | list .scope | include "unibox.fail" -}}
      {{- end }}
    {{- end -}}

    {{- $rules = dict "host" $host "port" $port "path" $path "pathType" $pathType "nameServiceFull" .nameServiceFull | include "unibox.ingress.rules.entry" | fromJson | append $rules -}}

  {{- end -}}

  {{- if $rules -}}
    {{- $_ := set $spec "rules" $rules -}}
  {{- end -}}

  {{- $_ := set $document "spec" $spec -}}

  {{- toJson $document -}}

{{- end -}}

{{- define "unibox.ingress.rules.entry" -}}
  {{- dict
    "host" .host
    "http" (dict
      "paths" (list
        (dict
          "path" .path
          "pathType" .pathType
          "backend" (dict
            "service" (dict
              "name" .nameServiceFull
              "port" (dict
                "name" .port
              )
            )
          )
        )
      )
    ) | toJson -}}
{{- end -}}
