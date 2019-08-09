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

  if [ x$HOOK_MODE = x'postinstall' ]; then

    host=''
    port=''

    for f in $(ls /initfiles/*.yaml); do
      # skip route.api.yaml because HOSTNAME not yet replaced 
      # to avoid error message in log
      echo examine $f 
      if [ $f != '/initfiles/route.api.yaml' ]; then
	echo apply $f 
        kubectl apply --validate=false -f $f 
      fi
    done

    if [ x$KUBE_ENV = 'xicp' ]; then

      host=$(kubectl get configmap ibmcloud-cluster-info --namespace=kube-public -o=jsonpath='{.data.cluster_address}')
      port=$(kubectl get configmap ibmcloud-cluster-info --namespace=kube-public -o=jsonpath='{.data.cluster_router_https_port}')

      if [ -z "$host" ]; then
        echo "Didn't find cluster addess in a configmap named ibmcloud-cluster-info in the kube-public namespace. Attempting to get it from the master node."
        host=$(kubectl get nodes -o=jsonpath='{.items[?(@.metadata.labels.role=="master")].metadata.name}')
      fi

      if [ -z "$port" ]; then
        echo "Didn't find cluster router https port in a configmap named ibmcloud-cluster-info in the kube-public namespace. Attempting to get it from the management ingress target port."
        port=$(kubectl get service icp-management-ingress -n kube-system -o=jsonpath='{.spec.ports[?(@.targetPort)].port}')
      fi
      sed -i "s|ICP_CONSOLE_URL|https://$host:$port/console|" /initfiles/builtin.yaml

    elif [ x$KUBE_ENV = 'xminishift' -o x$KUBE_ENV = 'xokd' -o x$KUBE_ENV = 'xocp' ]; then

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
      kubectl apply -f /initfiles/route.appnav.yaml --validate=false
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

    elif [ x$KUBE_ENV = 'xminikube' ]; then
        sed -i "s|ICP_CONSOLE_URL|http://127.0.0.1:8001/api/v1/namespaces/kube-system/services/http:kubernetes-dashboard:/proxy/#!|" /initfiles/builtin.yaml
    else
      echo host and port values could not be found for KUBE_ENV=$KUBE_ENV
    fi

    # TODO: need to decide what to do about these on OKD

    sed -i "s|KIBANA_URL|https://$host:$port/kibana/app/kibana|" /initfiles/builtin.yaml
    sed -i "s|GRAFANA_URL|https://$host:$port/grafana|" /initfiles/builtin.yaml

    # all changes have been made to builtin.yaml at this point except namespace
    # so set that too, and then create the builtin config map

    kubectl apply --validate=false -f /initfiles/builtin.yaml

  fi
/initfiles/OKDConsoleIntegration.sh $routeHost $
