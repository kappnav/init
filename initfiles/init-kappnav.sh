#!/bin/sh

#*****************************************************************
#*
#* Copyright 2019 IBM Corporation
#*
#* Licensed under the Apache License, Version 2.0 (the "License");
#* you may not use this file except in compliance with the License.
#* You may obtain a copy of the License at

#* http://www.apache.org/licenses/LICENSE-2.0
#* Unless required by applicable law or agreed to in writing, software
#* distributed under the License is distributed on an "AS IS" BASIS,
#* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#* See the License for the specific language governing permissions and
#* limitations under the License.
#*
#*****************************************************************

  echo "DEBUG: KUBE_ENV="$KUBE_ENV
  echo "DEBUG: HOOK_MODE="$HOOK_MODE

  # skip route.api.yaml because HOSTNAME not yet replaced 
  # to avoid error message in log
  openshift_files='builtin.yaml service.ui.yaml route.ui.yaml'
  
  # add route.api.yaml to delete list, since it's created later by post init hook
  openshift_delete_files=$openshift_files' route.api.yaml'

  # no routes on minikube
  # create dummy secret to satisfy ui deployment 
  minikube_files='builtin.yaml service.ui.minikube.yaml dummy.secret.yaml'

  if [ x$HOOK_MODE = x'preinstall' ]; then

    if [ x$KUBE_ENV = 'xminikube' ]; then
      echo 'use minikube file list'
      filelist=$minikube_files
    else
      echo 'use openshift file list'
      filelist=$openshift_files
    fi

    for f in $filelist; do
	    echo apply /initfiles/$f 
      kubectl apply --validate=false -f /initfiles/$f 
    done

  elif [ x$HOOK_MODE = x'postinstall' ]; then

    if [ x$KUBE_ENV = 'xminishift' -o x$KUBE_ENV = 'xokd' -o x$KUBE_ENV = 'xocp' ]; then

      config=$(kubectl get configmap webconsole-config -n openshift-web-console -o json)
      rc=$?
      if [ $rc -eq 0 ]; then
        console=$(echo $config | node /js/getConsoleURL.js)
        rc=$?
        if [ $rc -eq 0 ]; then
          echo "Update building.yaml ICP_CONSOLE_URL with "$console
          sed -i "s|ICP_CONSOLE_URL|$console|" /initfiles/builtin.yaml
        else
          echo Could not retrieve console URL from webconsole-config
        fi
      else
        echo Could not retrieve webconsole-config
      fi
      # kubectl apply -f /initfiles/route.appnav.yaml --validate=false
      routeHost=$(kubectl get route kappnav-ui-service -o=jsonpath={@.spec.host})

      if [ -z routeHost ]; then 
         echo 'Could not retrieve host from route kappnav-ui-service'
      else 
         echo 'Retrieved host name '$routeHost
      fi 

      sed -i "s|HOSTNAME|$routeHost|" /initfiles/route.api.yaml 
      kubectl apply -f /initfiles/route.api.yaml --validate=false

      # now form kappnav URL and store in kappnav config map 

      routePath=$(kubectl get route kappnav-ui-service -o=jsonpath={@.spec.path})
      kubectl get configmap kappnav-config -o json |  node /js/storeKeyValueToConfigmap.js kappnav-url https://$routeHost$routePath | kubectl apply -f -

      if [ $? -ne 0 ]; then
        echo 'Could not update kappnav-config config map'
      fi 

      /initfiles/OKDConsoleIntegration.sh $routeHost 

    elif [ x$KUBE_ENV = 'xminikube' ]; then
        sed -i "s|ICP_CONSOLE_URL|http://127.0.0.1:8001/api/v1/namespaces/kube-system/services/http:kubernetes-dashboard:/proxy/#!|" /initfiles/builtin.yaml
    else
      echo Unsupported environment:  KUBE_ENV=$KUBE_ENV
    fi

    # TODO: need to decide what to do about these on openshift

    sed -i "s|KIBANA_URL|https://$host:$port/kibana/app/kibana|" /initfiles/builtin.yaml
    sed -i "s|GRAFANA_URL|https://$host:$port/grafana|" /initfiles/builtin.yaml

    # all changes have been made to builtin.yaml at this point except namespace
    # so set that too, and then create the builtin config map

    kubectl apply --validate=false -f /initfiles/builtin.yaml
    
  elif [ x$HOOK_MODE = x'predelete' ]; then

    if [ x$KUBE_ENV = 'xminikube' ]; then
      echo 'use minikube file list'
      filelist=$minikube_files
    else
      echo 'use openshift file list'
      filelist=$openshift_delete_files
    fi

    for f in $filelist; do
	    echo apply $f 
      kubectl delete -f /initfiles/$f 
    done
    
  fi
