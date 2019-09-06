/*****************************************************************
 *
 * Copyright 2019 IBM Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

 * http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 *****************************************************************/

// This method is used to add or remove KAppNav buttons from OpenShift WebConsole
// On OpenShift 3.11 or later the openshift webconsole is install as an operator and the config is defined as a ResourceDefinition
// while on OpenShift prior to 3.11 is defined as configMap and the webconfig.yaml is the first element of webconsole data and it is defined in a stringified yaml format 
// hence in this method there is a slightly different way how to get to the web console datas.
function addRemoveKAppNavButtons(latestOpenShiftVersion, featuredApp, appLauncher, routeHost) {
    var datas = "";
    var dataJson = "";
    var webJson = "";
    var extensions = "";
    
    if (latestOpenShiftVersion == "true") {
        datas = fs.readFileSync('oswc.json');
        //console.log(typeof datas);   will return object
        dataJson = JSON.parse(datas);
        //console.log(typeof dataJson);   will return object
        console.log(dataJson);
        extensions = dataJson.spec.config.extensions;
        console.log(extensions);
    } else {
        datas = fs.readFileSync('oswc.yaml');
        //console.log(typeof datas);   will return object 
        dataJson = yaml.safeLoad(datas, "JSON-SCHEMA");
        //console.log(typeof dataJson);  will return object
        console.log(dataJson);
        var webYaml = dataJson.data['webconsole-config.yaml'];
        console.log(typeof webYaml);
        console.log(webYaml);
        webJson = yaml.safeLoad(webYaml, "JSON-SCHEMA");
        console.log(typeof webJson);
        console.log(webJson);
        extensions = webJson.extensions;
    }
    
    const KAppNavFeaturedAppScript = "https://"+routeHost+"/kappnav-ui/openshift/featuredApp.js";
    const KAppNavAppLauncherScript = "https://"+routeHost+"/kappnav-ui/openshift/appLauncher.js";
    const KAppNavIconScript = "https://"+routeHost+"/kappnav-ui/openshift/appNavIcon.css";

    // Adding KAppNav button
    if (featuredApp == "enabled" || appLauncher == "enabled") {
        addKAppNavButtons(dataJson, webJson, extensions, KAppNavFeaturedAppScript, KAppNavAppLauncherScript, KAppNavIconScript)
    }

    // Removing KAppNav button
    if (featuredApp == "disabled" || appLauncher == "disabled") {
        removeKAppNavButtons(dataJson, webJson, extensions, KAppNavFeaturedAppScript, KAppNavAppLauncherScript, KAppNavIconScript)
    }
}

function addKAppNavButtons(dataJson, webJson, extensions, KAppNavFeaturedAppScript, KAppNavAppLauncherScript, KAppNavIconScript) {
    //  enabling feature application button for AppNav
    if (featuredApp == "enabled") {
        console.log("Adding KAppNav feature application button");
        //  check if nothing is defined yet, then create new list and added to first element
        if (extensions.scriptURLs == undefined || extensions.scriptURLs.length == 0) {
            console.log("Creating new scriptURLs list");
            extensions.scriptURLs = [KAppNavFeaturedAppScript];
        } else {
            var scriptURLIndex = extensions.scriptURLs.indexOf(KAppNavFeaturedAppScript); // if can't find it got -1
            if (scriptURLIndex == -1) { // only added if to the list if not set
                console.log("Adding to existing scriptURLs list");
                extensions.scriptURLs.push(KAppNavFeaturedAppScript);
            }
        }
        console.log(extensions.scriptURLs);
    }

    //  enabling application launcher button for AppNav
    if (appLauncher == "enabled") {
        console.log("Adding KAppNav application launcher button");
        //  check if nothing is defined yet, then create new list and added to first element
        if (extensions.scriptURLs == undefined || extensions.scriptURLs.length == 0) {
            console.log("Creating new scriptURLs list");
            extensions.scriptURLs = [KAppNavAppLauncherScript];
        } else {
            var scriptURLIndex = extensions.scriptURLs.indexOf(KAppNavAppLauncherScript); // if can't find it got -1
            if (scriptURLIndex == -1) { // only added if to the list if not set
                console.log("Adding to existing scriptURLs list");
                extensions.scriptURLs.push(KAppNavAppLauncherScript);
            }
        }
        console.log(extensions.scriptURLs);
    }

    // enabling app nav icon
    if (extensions.stylesheetURLs == undefined || extensions.stylesheetURLs.length == 0) {
        console.log("Creating new stylesheetURLs list");
        extensions.stylesheetURLs = [KAppNavIconScript];
    } else {
        var stylesheetURLIndex = extensions.stylesheetURLs.indexOf(KAppNavIconScript); 
        if (stylesheetURLIndex == -1) { // only added if not set
            console.log("Adding to existing stylesheetURLs list");
            extensions.stylesheetURLs.push(KAppNavIconScript);
        }
    }
    console.log(extensions.stylesheetURLs);

    // Write it to the file
    // null - represents the replacer function. (in this case we don't want to alter the process)
    // 2 - represents the spaces to indent.
    if (latestOpenShiftVersion == "false") {
        // default line width for safeDump is 80 so if the URL is long it will end up setting it on new line and it will fail
        // the next time user try to retrieve any openshift webconsole configmap field as it will give JSON.parse error
        // example of the setting when the line is longer than 80 is below: ( then ">-" will caused issue for JSON.parse)
        //- >-
        //https://kappnav-ui-service-juniarti.apps.9.42.8.126.nip.io/test/foo/BOOtest.js
        webYaml = yaml.safeDump(webJson, {lineWidth: 200});
        dataJson.data['webconsole-config.yaml'] = webYaml;
    }
    var datasString = JSON.stringify(dataJson, null, 2);
    fs.writeFileSync('KAppNavButtonAdded.json', datasString);
}

function removeKAppNavButtons(dataJson, webJson, extensions, KAppNavFeaturedAppScript, KAppNavAppLauncherScript, KAppNavIconScript) {
    if (featuredApp == "disabled") {
        if (!(extensions.scriptURLs == undefined || extensions.scriptURLs.length == 0)) {
            var featuredAppScriptURLIndex = extensions.scriptURLs.indexOf(KAppNavFeaturedAppScript); 
            console.log(featuredAppScriptURLIndex);
            if (featuredAppScriptURLIndex != -1) { 
                console.log("Deleting Featured Application script");
                extensions.scriptURLs.splice(featuredAppScriptURLIndex, 1);
            }
        }
    }
    
    if (appLauncher == "disabled") {
        if (!(extensions.scriptURLs == undefined || extensions.scriptURLs.length == 0)) {
            var appLauncherScriptURLIndex = extensions.scriptURLs.indexOf(KAppNavAppLauncherScript); 
            console.log(appLauncherScriptURLIndex);
            if (appLauncherScriptURLIndex != -1) { 
                console.log("Deleting App Launcher script");
                extensions.scriptURLs.splice(appLauncherScriptURLIndex, 1);
            }
        }
    }

    // The appNavIcon.css file is an icon file that is used by both featuredApp and appLauncher buttons
    // so only removing the stylesheetURL if both buttons are disabled
    if (appLauncher == "disabled" && featuredApp == "disabled") {
        if (!(extensions.stylesheetURLs == undefined || extensions.stylesheetURLs.length == 0)) {
            var appLauncherStyleSheetIndex = extensions.stylesheetURLs.indexOf(KAppNavIconScript); 
            console.log(appLauncherStyleSheetIndex);
            if (appLauncherStyleSheetIndex != -1) { 
                console.log("Deleting App Launcher script");
                extensions.stylesheetURLs.splice(appLauncherStyleSheetIndex, 1);
            }
        }
    }
    
    // Write it to the file
    // null - represents the replacer function. (in this case we don't want to alter the process)
    // 2 - represents the spaces to indent.
    if (latestOpenShiftVersion == "false") {
        // default line width for safeDump is 80 so if the URL is long it will end up setting it on new line and it will fail
        // the next time user try to retrieve any openshift webconsole configmap field as it will give JSON.parse error
        // example of the setting when the line is longer than 80 is below: ( then ">-" will caused issue for JSON.parse)
        //- >-
        //https://kappnav-ui-service-juniarti.apps.9.42.8.126.nip.io/test/foo/BOOtest.js
        webYaml = yaml.safeDump(webJson, {lineWidth: 200});
        dataJson.data['webconsole-config.yaml'] = webYaml;
    }
    var dataString = JSON.stringify(dataJson, null, 2);
    fs.writeFileSync('KAppNavButtonDeleted.json', dataString);
}

// The argv[0] is node and argv[1] is the script name
const myArgs = process.argv.slice(2);
const latestOpenShiftVersion = myArgs[0]; // flag to tell if openshift v3.11 or later
const featuredApp = myArgs[1]; // getting featuredApp value
const appLauncher = myArgs[2]; // getting appLauncher value
const routeHost = myArgs[3]  // getting the kappnav ui server host
console.log(latestOpenShiftVersion);
console.log(featuredApp);
console.log(appLauncher);
console.log(routeHost);

const fs = require('fs');
const yaml = require('js-yaml');

addRemoveKAppNavButtons(latestOpenShiftVersion, featuredApp, appLauncher, routeHost);
