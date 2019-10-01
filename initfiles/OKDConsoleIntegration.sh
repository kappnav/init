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

echo "kAppNav to OKD Console Integration"
routeHost=$1
echo routehost parm=$routeHost

echo "OKDConsoleIntegration.sh HOOK_MODE = $HOOK_MODE"

# setting default values
shouldProcessKAppNavButton="false"
latestOpenShiftVersion="false"

# check if it is running on OpenShift distribution such as minishift, okd and ocp
if [ x$KUBE_ENV = 'xminishift' -o x$KUBE_ENV = 'xokd' -o x$KUBE_ENV = 'xocp' ]; then 
   shouldProcessKAppNavButton="true"
fi

if [ $shouldProcessKAppNavButton = "true" ]; then 
   KAppNavButtonDone="false"
   count=0
   while [ $KAppNavButtonDone = "false" ]
   do 
      echo "Processing KAppNav buttons"
      count=$((count+1))
      echo $count
      # get which buttons to enable
      featuredAppButton=$(kubectl get configmap kappnav-config -o=jsonpath='{.data.okd-console-featured-app}')
      appLauncherButton=$(kubectl get configmap kappnav-config -o=jsonpath='{.data.okd-console-app-launcher}')

      echo "Featured Application button for kAppNav is $featuredAppButton"
      echo "Application Launcher button for kAppNav is $appLauncherButton"

      # checking to see if it is using latest openshift or not and capture open shift web console config map
      kubectl get OpenShiftWebConsoleConfig
      if [ $? -eq 0 ]; then
         echo "Using openshift 3.11+"
         echo "Capture OpenShiftWebConsoleConfig to oswc.json file"
         latestOpenShiftVersion="true"
         kubectl get OpenShiftWebConsoleConfig instance -o json -n openshift-web-console > oswc.json 
      else
         echo "Using openshift < 3.11"
         echo "Capture configmap openshift webconsole to oswc.yaml file"
         latestOpenShiftVersion="false"
         kubectl get configmap webconsole-config -n openshift-web-console -o yaml > oswc.yaml
      fi   

      #===============================
      # Removing App Nav buttons logic
      #===============================

      # On uninstall of appnav remove all OKD console integrations
      if [ x$HOOK_MODE = x'predelete' ]; then
         echo "KAppNav being deleted - removing kAppNav items from OKD OpenShift Web Console"
         featuredAppButton=disabled
         appLauncherButton=disabled
      fi
      # Removing app nav button from OKD web console
      if [ $featuredAppButton = "disabled" -o $appLauncherButton = "disabled" ]; then
         echo "Removing kAppNav button from OKD OpenShift Web Console if it is set"
         node /js/addRemoveKAppNavButtons.js $latestOpenShiftVersion $featuredAppButton $appLauncherButton $routeHost

         # updating the open shift console config map by calling apply using the updated json script
         kubectl apply --validate=false -f KAppNavButtonDeleted.json 

         if [ $? -eq 0 ]; then
            KAppNavButtonDone="true"
            echo "DONE $KAppNavButtonDone"
         fi
      fi

      #=============================
      # Adding App Nav buttons logic
      #=============================

      # Adding app nav button to OKD web console
      if [ $featuredAppButton = "enabled" -o $appLauncherButton = "enabled" ]; then
         echo "Adding kAppNav button to OKD OpenShift Web Console"
         node /js/addRemoveKAppNavButtons.js $latestOpenShiftVersion $featuredAppButton $appLauncherButton $routeHost

         # updating the open shift console config map by calling apply using the updated json script
         kubectl apply --validate=false -f KAppNavButtonAdded.json 

         if [ $? -eq 0 ]; then
            KAppNavButtonDone="true"
            echo "DONE $appNavButtonDone"
         fi
      fi
   done
else
   echo "Not processing kAppNav Buttons as it is not running on OKD, OCP or minishift"
fi