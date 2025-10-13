
{{- define "unibox.pv" -}}
  {{- if (list .scope "pv" "map" | include "unibox.validate.type") -}}

    {{- template "unibox.validate.map" (list .scope "pv" "pv") -}}
    {{- $_ := list .scope "pv" | include "unibox.getPath" | set .scope.pv "__path__" -}}

    {{- $specPVC := include "unibox.pvc.spec" . | fromJson -}}

    {{- $document := include "unibox.document" (dict
      "apiVersion" (include "unibox.capabilities.pv.apiVersion" .ctx)
      "kind" "PersistentVolume"
    ) | fromJson -}}

    {{- $scope := .scope.pv -}}

    {{- $_ := include "unibox.metadata" (dict
      "name" .nameFull
      "isNamespaced" true
      "ctx" .ctx "scope" $scope
    ) | fromJson | merge $document -}}

    {{- $spec := dict "claimRef" (dict
      "namespace" .ctx.Release.Namespace
      "name" .nameFull
    ) -}}

    {{- if (hasKey $specPVC "accessModes") -}}
      {{- $_ := set $spec "accessModes" $specPVC.accessModes -}}
    {{- end -}}

    {{- if (hasKey $specPVC "storageClassName") -}}
      {{- $_ := set $spec "storageClassName" $specPVC.storageClassName -}}
    {{- end -}}

    {{- if (hasKey $specPVC "resources") -}}
      {{- $_ := set $spec "capacity" $specPVC.resources.requests -}}
    {{- end -}}

    {{- if (list $scope "mountOptions" "slice" | include "unibox.validate.type") -}}

      {{- $mountOptions := list -}}

      {{- $ctx := .ctx -}}
      {{- range until (len $scope.mountOptions) -}}
        {{- $_ := list $scope "mountOptions" . "scalar" | include "unibox.validate.type" -}}
        {{- $mountOptions = dict "value" (index $scope "mountOptions" .) "ctx" $ctx "scope" $scope | include "unibox.render" | append $mountOptions -}}
      {{- end -}}

      {{- $_ := set $spec "mountOptions" $mountOptions -}}

    {{- end -}}

    {{- if (list $scope "csi" "map" | include "unibox.validate.type") -}}

      {{- template "unibox.validate.map" (list $scope "csi" "pv.csi") -}}
      {{- $_ := list $scope "csi" | include "unibox.getPath" | set $scope.csi "__path__" -}}

      {{- $csi := dict -}}

      {{- if (list $scope.csi "driver" "scalar" | include "unibox.validate.type") -}}
        {{- $driver := dict "value" $scope.csi.driver "ctx" .ctx "scope" $scope | include "unibox.render" -}}
        {{- $_ := set $csi "driver" $driver -}}
      {{- else -}}
        {{- list $scope.csi "there is no mandatory .driver field specified for the CSI" | include "unibox.fail" -}}
      {{- end -}}

      {{- if (list $scope.csi "fsType" "scalar" | include "unibox.validate.type") -}}
        {{- $fsType := dict "value" $scope.csi.fsType "ctx" .ctx "scope" $scope | include "unibox.render" -}}
        {{- $_ := set $csi "fsType" $fsType -}}
      {{- end -}}

      {{- if (list $scope.csi "volumeHandle" "scalar" | include "unibox.validate.type") -}}
        {{- $volumeHandle := dict "value" $scope.csi.volumeHandle "ctx" .ctx "scope" $scope | include "unibox.render" -}}
        {{- $_ := set $csi "volumeHandle" $volumeHandle -}}
      {{- else -}}
        {{- list $scope.csi "there is no mandatory .volumeHandle field specified for the CSI" | include "unibox.fail" -}}
      {{- end -}}

      {{- if (list $scope.csi "volumeAttributes" "map" | include "unibox.validate.type") -}}

        {{- $volumeAttributes := dict -}}

        {{- $_ := list $scope.csi "volumeAttributes" | include "unibox.getPath" | set $scope.csi.volumeAttributes "__path__" -}}
        {{- $ctx := .ctx -}}
        {{- range $key, $value := omit $scope.csi.volumeAttributes "__path__" -}}
          {{- $_ := list $scope.csi.volumeAttributes $key "scalar" | include "unibox.validate.type" -}}
          {{- $_ := dict "value" $value "ctx" $ctx "scope" $scope | include "unibox.render" | set $volumeAttributes $key -}}
        {{- end -}}

        {{- $_ := set $csi "volumeAttributes" $volumeAttributes -}}

      {{- end -}}

      {{- if (list $scope.csi "secrets" "map" | include "unibox.validate.type") -}}

        {{- template "unibox.validate.map" (list $scope "csi" "pv.csi.secrets") -}}
        {{- $_ := list $scope.csi "secrets" | include "unibox.getPath" | set $scope.csi.secrets "__path__" -}}

        {{- $ctx := .ctx -}}
        {{- $secretInfo := .secretInfo -}}
        {{- range $key, $value := omit $scope.csi.secrets "__path__" -}}

          {{- $_ := list $scope.csi.secrets $key "scalar" | include "unibox.validate.type" -}}
          {{- $secret := dict "value" $value "ctx" $ctx "scope" $scope | include "unibox.render" -}}

          {{- if (hasKey $secretInfo.shortcuts $secret) -}}
            {{- $secret = index $secretInfo.shortcuts $secret -}}
          {{- else if not (hasKey $secretInfo.entries $secret) -}}
            {{- printf "no secret or sealedsecret named '%s' was found" $secret | list $scope.csi.secrets $key | include "unibox.fail" -}}
          {{- end -}}

          {{- $_ := set $csi (printf "%sSecretRef" $key) (dict
            "name" $secret
            "namespace" $ctx.Release.Namespace
          ) -}}

        {{- end -}}

      {{- end -}}

      {{- $readOnly := dict "scope" $scope.csi "key" "readOnly" "ctx" .ctx "scopeLocal" $scope "default" false | include "unibox.render.bool" | eq "true" -}}
      {{- $_ := set $csi "readOnly" $readOnly -}}

      {{- $_ := set $spec "csi" $csi -}}

    {{- end -}}

    {{- /*
      TODO: add support for the following volumes:
      fc
      hostPath
      iscsi
      local
      nfs
    */ -}}

    {{- /*
      TODO: add support for the following fields:
      nodeAffinity
      persistentVolumeReclaimPolicy
      volumeAttributesClassName
      volumeMode
    */ -}}

    {{- $_ := set $document "spec" $spec -}}

    {{- toJson $document -}}

  {{- else -}}
    {{- dict | toJson -}}
  {{- end -}}
{{- end -}}
