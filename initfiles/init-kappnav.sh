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

  echo `pwd`
  echo `ls -al`
  
  echo "DEBUG: KUBE_ENV="$KUBE_ENV
  echo "DEBUG: HOOK_MODE="$HOOK_MODE

  all_platform_files='app_v1beta1_application.yaml builtin.yaml'

  # to avoid error message in log
  openshift_files=$all_platform_files' service.ui.yaml route.ui.yaml'

  # Do not delete Application CRD as this causes any
  # Application resources to be deleted
  openshift_delete_files='builtin.yaml service.ui.yaml route.ui.yaml'

  # no routes on minikube
  # create dummy secret to satisfy ui deployment
  minikube_files=$all_platform_files' service.ui.minikube.yaml dummy.secret.yaml'
  # Do not delete Application CRD as this causes any
  # Application resources to be deleted
  minikube_delete_files='builtin.yaml service.ui.minikube.yaml dummy.secret.yaml'

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

    for f in $(ls /initfiles/ext-*.yaml 2>/dev/null); do
      # apply any extension files
      echo apply $f
      kubectl apply --validate=false -f $f
    done


  elif [ x$HOOK_MODE = x'postinstall' ]; then

    if [ x$KUBE_ENV = 'xminikube' ]; then
        sed -i "s|OPENSHIFT_CONSOLE_URL|http://127.0.0.1:8001/api/v1/namespaces/kube-system/services/http:kubernetes-dashboard:/proxy/#!|" /initfiles/builtin.yaml
    
    elif [ x$KUBE_ENV = 'xocp' ]; then
      config=$(kubectl get configmap console-config -n openshift-console -o json)
      rc=$?
      if [ $rc -eq 0 ]; then
        # get openshift console URL
        console=$(echo $config | node /js/getOCPConsoleURL.js)
        rc=$?
        if [ $rc -eq 0 ]; then
          echo "Update builtin.yaml OPENSHIFT_CONSOLE_URL with "$console
          sed -i "s|OPENSHIFT_CONSOLE_URL|$console|" /initfiles/builtin.yaml
          echo "Update builtin.yaml OPENSHIFT_ADMIN_CONSOLE_URL with "$console
          sed -i "s|OPENSHIFT_ADMIN_CONSOLE_URL|$console|" /initfiles/builtin.yaml
        else
          echo Could not retrieve console URL from console-config
        fi
      else
          echo Could not retrieve console-config
      fi

    elif [ x$KUBE_ENV = 'xminishift' -o x$KUBE_ENV = 'xokd' ]; then
      config=$(kubectl get configmap webconsole-config -n openshift-web-console -o json)
      rc=$?
      if [ $rc -eq 0 ]; then
        # get openshift console URL
        console=$(echo $config | node /js/getConsoleURL.js)
        rc=$?
        if [ $rc -eq 0 ]; then
          echo "Update builtin.yaml OPENSHIFT_CONSOLE_URL with "$console
          sed -i "s|OPENSHIFT_CONSOLE_URL|$console|" /initfiles/builtin.yaml
        else
          echo Could not retrieve console URL from webconsole-config
        fi

        # get openshift admin console URL
        adminconsole=$(echo $config | node /js/getAdminConsoleURL.js)
        rc=$?
        if [ $rc -eq 0 ]; then
          echo "Update builtin.yaml OPENSHIFT_ADMIN_CONSOLE_URL with "$adminconsole
          sed -i "s|OPENSHIFT_ADMIN_CONSOLE_URL|$adminconsole|" /initfiles/builtin.yaml
        else
          echo Could not retrieve admin console URL from webconsole-config
        fi
      else
        echo Could not retrieve webconsole-config
      fi
  
    else
      echo Unsupported environment:  KUBE_ENV=$KUBE_ENV
    fi

    if [ x$KUBE_ENV = 'xminishift' -o x$KUBE_ENV = 'xokd' -o x$KUBE_ENV = 'xocp' ]; then
      routeHost=$(kubectl get route kappnav-ui-service -o=jsonpath={@.spec.host})

      if [ -z routeHost ]; then
         echo 'Could not retrieve host from route kappnav-ui-service'
      else
         echo 'Retrieved host name '$routeHost
      fi

      # now form kappnav URL and store in kappnav config map
      routePath=$(kubectl get route kappnav-ui-service -o=jsonpath={@.spec.path})
      kubectl get configmap kappnav-config -o json |  node /js/storeKeyValueToConfigmap.js kappnav-url https://$routeHost$routePath | kubectl apply -f -

      if [ $? -ne 0 ]; then
        echo 'Could not update kappnav-config config map'
      fi

      # Only minishift uses the scripts to setup OKD console 
      # integrations for the time being
      if [ x$KUBE_ENV == 'xminishift' ]; then
        /initfiles/OKDConsoleIntegration.sh $routeHost
      fi
    fi

    # all changes have been made to builtin.yaml at this point except namespace
    # so set that too, and then create the builtin config map

    kubectl apply --validate=false -f /initfiles/builtin.yaml

    if [ -f /initfiles/plugin-post-init.sh ]; then
      /initfiles/plugin-post-init.sh
    fi

  elif [ x$HOOK_MODE = x'predelete' ]; then

    # Delete any OKD console integrations.
    # Using scripts for now but the controller should do this once 
    # we get the go install operator
    if [ x$KUBE_ENV = 'xminishift' -o x$KUBE_ENV = 'xokd']; then
      routeHost=$(kubectl get route kappnav-ui-service -o=jsonpath={@.spec.host})
      /initfiles/OKDConsoleIntegration.sh $routeHost
    fi

    if [ x$KUBE_ENV = 'xminikube' ]; then
      echo 'use minikube file list'
      filelist=$minikube_delete_files
    else
      echo 'use openshift file list'
      filelist=$openshift_delete_files
    fi

    for f in $filelist; do
	    echo apply $f
      kubectl delete -f /initfiles/$f
    done

  fi
