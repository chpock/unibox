
{{- define "unibox.podTemplate" -}}

  {{- print "\ntemplate:" -}}
  {{- include "unibox.metadata" . | nindent 2 -}}

  {{- print "spec:" | nindent 2 -}}

  {{- print "containers:" | nindent 4 -}}
  {{- include "unibox.foreach" (dict
    "singleKey" "container"
    "defaultName" .component
    "noDefaultNameMessage" "an empty name was specified in the .name field for this container"
    "callback" "unibox.container"
    "asArray" true
    "validateMap" "container"
    "ctx" .ctx "scope" .scope
  ) | indent 4 -}}

{{- end -}}
