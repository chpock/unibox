
{{- define "unibox.capabilities.deployment.apiVersion" -}}
  {{- print "apps/v1" -}}
{{- end -}}

{{- define "unibox.capabilities.service.apiVersion" -}}
  {{- print "apps/v1" -}}
{{- end -}}

{{- define "unibox.capabilities.ingress.apiVersion" -}}
  {{- print "networking.k8s.io/v1" -}}
{{- end -}}

{{- define "unibox.capabilities.serviceAccount.apiVersion" -}}
  {{- print "v1" -}}
{{- end -}}

{{- define "unibox.capabilities.sealedSecret.apiVersion" -}}
  {{- print "bitnami.com/v1alpha1" -}}
{{- end -}}
